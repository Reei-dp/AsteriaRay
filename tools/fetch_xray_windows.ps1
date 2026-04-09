# Download Xray-core for Windows amd64 into windows/xray (xray.exe + wintun.dll) for CMake bundling.
# Run from repo root (PowerShell): .\tools\fetch_xray_windows.ps1
# Optional: .\tools\fetch_xray_windows.ps1 26.3.27

$ErrorActionPreference = "Stop"
$Version = if ($args.Count -ge 1) { $args[0] } else { "26.3.27" }
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutDir = Join-Path $Root "windows\xray"
$Url = "https://github.com/XTLS/Xray-core/releases/download/v$Version/Xray-windows-64.zip"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Tmp = New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())

try {
    Write-Host "Downloading $Url"
    $Zip = Join-Path $Tmp "xray.zip"
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
    Expand-Archive -Path $Zip -DestinationPath $Tmp -Force

    $Xray = Get-ChildItem -Path $Tmp -Filter "xray.exe" -Recurse -File | Select-Object -First 1
    if (-not $Xray) { throw "xray.exe not found in zip" }
    Copy-Item -Force $Xray.FullName (Join-Path $OutDir "xray.exe")

    $Wintun = Get-ChildItem -Path $Tmp -Filter "wintun.dll" -Recurse -File | Select-Object -First 1
    if (-not $Wintun) { throw "wintun.dll not found in zip (required next to xray.exe on Windows)" }
    Copy-Item -Force $Wintun.FullName (Join-Path $OutDir "wintun.dll")

    Write-Host "Installed:"
    Write-Host "  $(Join-Path $OutDir 'xray.exe')"
    Write-Host "  $(Join-Path $OutDir 'wintun.dll')"
    & (Join-Path $OutDir "xray.exe") version
}
finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
