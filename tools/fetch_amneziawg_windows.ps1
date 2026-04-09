# Bundle AmneziaWG for Windows: amneziawg-go.exe (build) + awg.exe (build from source) + wintun.dll.
#
# Upstream UAPI uses \\.\pipe\ProtectedPrefix\Administrators\AmneziaWG\<iface> — often fails even when elevated.
# We patch to a single pipe segment: \\.\pipe\AsteriaRayAWG_<iface> (matches awg.exe; avoids flaky multi-level pipes).
# We also drop the UAPI SD mandatory-label SACL where present; if listen still fails, we force ListenConfig{} (default RtlDefaultNpAcl)
# and strip awg.exe's LocalSystem owner check — default pipe owner is the elevated user, not SYSTEM.
#
# Requires: Git, Go 1.21+, Windows with curl/tar (10+), and ~10–20 min first time (llvm-mingw download via build.cmd).
#
# Run from repo root:
#   .\tools\fetch_amneziawg_windows.bat
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fetch_amneziawg_windows.ps1
# Args: [amneziawg-go tag] [amneziawg-tools tag]  e.g. v0.2.16 v1.0.20260223

$ErrorActionPreference = "Stop"
$GoTag = if ($args.Count -ge 1) { $args[0] } else { "v0.2.16" }
$AwgToolsTag = if ($args.Count -ge 2) { $args[1] } else { "v1.0.20260223" }

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutDir = Join-Path $Root "windows\amneziawg"
$XrayDir = Join-Path $Root "windows\xray"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Tmp = New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())

function Resolve-GoExe {
    $cmd = Get-Command go -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pf = ${env:ProgramFiles}
    $pf86 = ${env:ProgramFiles(x86)}
    $candidates = @(
        (Join-Path $pf 'Go\bin\go.exe'),
        (Join-Path $pf86 'Go\bin\go.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Go\bin\go.exe')
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Write-AsteriaUapiWindowsGo {
    param([string]$RepoRoot)
    # Full replace: incremental regex missed some clones (tabs/spaces) leaving UAPISecurityDescriptor in Listen → NtCreateNamedPipe still fails.
    # No custom SD; fmt wraps errors so logs show Windows errno text.
    $p = Join-Path $RepoRoot "ipc\uapi_windows.go"
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $body = @'
/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2025 WireGuard LLC. All Rights Reserved.
 */

package ipc

import (
	"errors"
	"fmt"
	"net"
	"os"
	"syscall"

	"github.com/amnezia-vpn/amneziawg-go/ipc/namedpipe"
)

// TODO: replace these with actual standard windows error numbers from the win package
const (
	IpcErrorIO        = -int64(5)
	IpcErrorProtocol  = -int64(71)
	IpcErrorInvalid   = -int64(22)
	IpcErrorPortInUse = -int64(98)
	IpcErrorUnknown   = -int64(55)
)

type UAPIListener struct {
	listener net.Listener // unix socket listener
	connNew  chan net.Conn
	connErr  chan error
	kqueueFd int
	keventFd int
}

func (l *UAPIListener) Accept() (net.Conn, error) {
	for {
		select {
		case conn := <-l.connNew:
			return conn, nil
		case err := <-l.connErr:
			return nil, err
		}
	}
}

func (l *UAPIListener) Close() error {
	return l.listener.Close()
}

func (l *UAPIListener) Addr() net.Addr {
	return l.listener.Addr()
}

func UAPIListen(name string) (net.Listener, error) {
	path := `\\.\pipe\AsteriaRayAWG_` + name
	listener, err := (&namedpipe.ListenConfig{}).Listen(path)
	if err != nil {
		var pe *os.PathError
		if errors.As(err, &pe) {
			var w syscall.Errno
			if errors.As(pe.Err, &w) {
				return nil, fmt.Errorf("uapi listen %q: %w (WinErr=%d %s)", path, err, w, w.Error())
			}
			return nil, fmt.Errorf("uapi listen %q: %w (inner=%T %v)", path, err, pe.Err, pe.Err)
		}
		return nil, fmt.Errorf("uapi listen %q: %w", path, err)
	}

	uapi := &UAPIListener{
		listener: listener,
		connNew:  make(chan net.Conn, 1),
		connErr:  make(chan error, 1),
	}

	go func(l *UAPIListener) {
		for {
			conn, err := l.listener.Accept()
			if err != nil {
				l.connErr <- err
				break
			}
			l.connNew <- conn
		}
	}(uapi)

	return uapi, nil
}

'@
    [IO.File]::WriteAllText($p, $body, $utf8)
}

function Apply-AsteriaUapiPatchToGo {
    param([string]$RepoRoot)
    Write-AsteriaUapiWindowsGo $RepoRoot
}

function Apply-AsteriaUserspaceInterfaceFileBypass {
    param([string]$RepoRoot)
    $p = Join-Path $RepoRoot "src\ipc-uapi-windows.h"
    if (-not (Test-Path $p)) { throw "Not found: $p" }
    $c = [IO.File]::ReadAllText($p)
    if (-not $c.Contains('EqualSid(&expected_sid, pipe_sid)')) { return }
    $start = $c.IndexOf('static FILE *userspace_interface_file(const char *iface)')
    $end = $c.IndexOf('static bool have_cached_interfaces')
    if ($start -lt 0 -or $end -le $start) {
        throw "ipc-uapi-windows.h: could not locate userspace_interface_file / have_cached_interfaces"
    }
    $replacement = @'
static FILE *userspace_interface_file(const char *iface)
{
	char fname[MAX_PATH];
	HANDLE pipe_handle;
	int fd;

	snprintf(fname, sizeof(fname), "\\\\.\\pipe\\AsteriaRayAWG_%s", iface);
	pipe_handle = CreateFileA(fname, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
	if (pipe_handle == INVALID_HANDLE_VALUE)
		goto err;
	fd = _open_osfhandle((intptr_t)pipe_handle, _O_RDWR);
	if (fd == -1) {
		CloseHandle(pipe_handle);
		return NULL;
	}
	return _fdopen(fd, "r+");
err:
	errno = EACCES;
	return NULL;
}


'@
    $c = $c.Remove($start, $end - $start).Insert($start, $replacement)
    [IO.File]::WriteAllText($p, $c)
}

function Apply-AsteriaUapiPatchToToolsHeader {
    param([string]$RepoRoot)
    $p = Join-Path $RepoRoot "src\ipc-uapi-windows.h"
    if (-not (Test-Path $p)) { throw "Not found: $p" }
    $c = [IO.File]::ReadAllText($p)
    $alreadyPiped = $c.Contains('"\\\\.\\pipe\\AsteriaRayAWG_%s"')
    if (-not $alreadyPiped) {
        # Legacy two-level (older fetch): ...\pipe\AsteriaRayAWG\<iface>
        $c = $c.Replace('"\\\\.\\pipe\\AsteriaRayAWG\\%s"', '"\\\\.\\pipe\\AsteriaRayAWG_%s"')
        $c = $c.Replace('"AsteriaRayAWG\\%s"', '"AsteriaRayAWG_%s"')
        $c = $c.Replace('"AsteriaRayAWG\\";', '"AsteriaRayAWG_";')
        # Fresh upstream
        $c = $c.Replace('"\\\\.\\pipe\\ProtectedPrefix\\Administrators\\AmneziaWG\\%s"', '"\\\\.\\pipe\\AsteriaRayAWG_%s"')
        $c = $c.Replace('"ProtectedPrefix\\Administrators\\AmneziaWG\\%s"', '"AsteriaRayAWG_%s"')
        $c = $c.Replace('"ProtectedPrefix\\Administrators\\AmneziaWG\\";', '"AsteriaRayAWG_";')
    }
    if (-not $c.Contains('"\\\\.\\pipe\\AsteriaRayAWG_%s"')) {
        throw "ipc-uapi-windows.h: could not patch UAPI paths (upstream changed?)"
    }
    [IO.File]::WriteAllText($p, $c)
    Apply-AsteriaUserspaceInterfaceFileBypass $RepoRoot
}

try {
    $GoExe = Resolve-GoExe
    if (-not $GoExe) {
        throw "Go is required. Install from https://go.dev/dl/ (default: $env:ProgramFiles\Go\bin) then reopen the terminal."
    }
    $env:PATH = "$(Split-Path $GoExe -Parent);$env:PATH"
    Write-Host "Using Go: $GoExe"

    # --- amneziawg-go ---
    Write-Host "Cloning amnezia-vpn/amneziawg-go@$GoTag"
    $SrcGo = Join-Path $Tmp "amneziawg-go"
    git clone --depth 1 --branch $GoTag "https://github.com/amnezia-vpn/amneziawg-go.git" $SrcGo
    Apply-AsteriaUapiPatchToGo $SrcGo
    $gofmt = Join-Path (Split-Path $GoExe -Parent) "gofmt.exe"
    if (Test-Path $gofmt) {
        & $gofmt -w (Join-Path $SrcGo "ipc\uapi_windows.go")
    }

    Write-Host "Building amneziawg-go.exe -> $(Join-Path $OutDir 'amneziawg-go.exe')"
    Push-Location $SrcGo
    try {
        $env:CGO_ENABLED = "0"
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        & $GoExe build -trimpath -ldflags="-s -w" -o (Join-Path $OutDir "amneziawg-go.exe") .
    }
    finally {
        Pop-Location
    }

    # --- amneziawg-tools (awg.exe) — must match UAPI pipe path in amneziawg-go ---
    Write-Host "Cloning amnezia-vpn/amneziawg-tools@$AwgToolsTag (for awg.exe)"
    $SrcTools = Join-Path $Tmp "amneziawg-tools"
    git clone --depth 1 --branch $AwgToolsTag "https://github.com/amnezia-vpn/amneziawg-tools.git" $SrcTools
    Apply-AsteriaUapiPatchToToolsHeader $SrcTools

    Write-Host "Running amneziawg-tools build.cmd (downloads llvm-mingw on first run; may take several minutes)..."
    Push-Location $SrcTools
    try {
        cmd /c build.cmd
        if ($LASTEXITCODE -ne 0) { throw "build.cmd failed with exit $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }

    $BuiltAwg = Join-Path $SrcTools "x64\awg.exe"
    if (-not (Test-Path $BuiltAwg)) { throw "Expected $BuiltAwg after build.cmd" }
    Copy-Item -Force $BuiltAwg (Join-Path $OutDir "awg.exe")

    $Wintun = Join-Path $XrayDir "wintun.dll"
    if (Test-Path $Wintun) {
        Copy-Item -Force $Wintun (Join-Path $OutDir "wintun.dll")
        Write-Host "Copied wintun.dll from windows\xray"
    }
    else {
        Write-Warning "windows\xray\wintun.dll not found - run .\tools\fetch_xray_windows.ps1 first."
    }

    Write-Host "Installed (UAPI pipe: \\.\pipe\AsteriaRayAWG_<iface>):"
    Write-Host "  $(Join-Path $OutDir 'amneziawg-go.exe')"
    Write-Host "  $(Join-Path $OutDir 'awg.exe')"
}
finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
