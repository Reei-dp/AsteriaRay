# AsteriaRay

Cross-platform VPN client (Flutter) with native tunnels: **VLESS** (Xray-core on Android, Linux, and Windows) and **AmneziaWG** (WireGuard-compatible `.conf`) on supported platforms.

## Protocol and platform support

Tunneling is implemented only where the table shows **✅**. On other platforms the app may compile for UI work, but **connect** is not available. **Legend:** ✅ supported · ❌ not supported.

<table>
<thead>
<tr>
<th align="left">Protocol</th>
<th align="center">Android</th>
<th align="center">Linux</th>
<th align="center">Windows</th>
<th align="center">macOS</th>
<th align="center">iOS</th>
<th align="center">Web</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>VLESS</strong></td>
<td align="center">✅</td>
<td align="center">✅</td>
<td align="center">❌</td>
<td align="center">✅</td>
<td align="center">❌</td>
<td align="center">❌</td>
</tr>
<tr>
<td><strong>AmneziaWG</strong></td>
<td align="center">✅</td>
<td align="center">✅</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
</tr>
<tr>
<td><strong>OpenVPN</strong></td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
</tr>
<tr>
<td><strong>L2TP / IPsec</strong></td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
<td align="center">❌</td>
</tr>
</tbody>
</table>

**Notes**

- **VLESS**: URI import (`vless://…`), profiles stored in-app; **Android** uses **libv2ray.aar**; **Linux** and **Windows** run **Xray-core** with the same JSON (**Windows** needs **xray.exe** + **wintun.dll** next to the app and usually **Administrator** for TUN + routes; see `tools/fetch_xray_windows.ps1`).
- **AmneziaWG**: import WireGuard-style `[Interface]` / `[Peer]` config; not plain stock WireGuard unless the config matches what the bundled **AmneziaWG** stack expects.
- **OpenVPN** and **L2TP** are not implemented (`VpnProtocol` has no active variants for them; imports like OpenVPN are rejected until parsers/backends exist).
- **Linux desktop**: system tray uses a native GTK / StatusNotifier path; see `linux/runner/tray_linux.cc`.

## Features

- **VLESS**: TLS, Reality, TCP / WebSocket / gRPC / HTTP/2 transports; profile CRUD, clipboard and file import, logs
- **AmneziaWG**: `.conf` profiles on Android and Linux only
- **Profile management**: multiple profiles, switching, export/share where applicable
- **Native integration**: Android **VpnService** + Xray; Linux **xray** + `awg-quick` / bundled tools (see `linux/` and `tools/`); Windows **xray.exe** + Wintun + `route` (see `lib/services/vpn_platform_windows.dart`)
- **Connection status** and statistics where the platform exposes them
- **Modern UI**: Material Design

## Architecture (overview)

- **Flutter**: UI and orchestration (`lib/`)
- **Android**: Kotlin + libv2ray, `LibxrayVpnService`, MethodChannel (`android/app/src/main/kotlin/…`)
- **Linux**: `VpnPlatformLinux` — `xray` for VLESS, AmneziaWG via `awg-quick` (see `lib/services/vpn_platform_linux.dart`)
- **Windows**: `VpnPlatformWindows` — `xray` for VLESS with Wintun (see `lib/services/vpn_platform_windows.dart`)
- **Platform entry**: `createVpnPlatform()` in `lib/services/vpn_platform.dart` — **Android**, **Linux**, and **Windows** for VLESS; AmneziaWG only on Android and Linux

## Project structure (abridged)

```
lib/
├── main.dart
├── models/              # VLESS, AmneziaWG, stored profiles
├── services/            # vpn_platform*, xray_runner (Xray JSON), profile_store, …
├── notifiers/
└── screens/

android/                 # Kotlin VPN service, libv2ray
linux/                   # Runner, CMake, optional bundled xray / awg tools
windows/                 # Runner, CMake, optional bundled xray.exe + wintun.dll (windows/xray/)
```

## Requirements

- **Flutter** (stable)
- **Android**: SDK, device with VPN; **libv2ray.aar** is vendored under `android/app/libs/` (rebuild with `scripts/build_libxray_aar.sh` when bumping Xray/libv2ray)
- **Linux**: `pkexec`/polkit or passwordless sudo for TUN where required; optional bundled binaries via `tools/fetch_*.sh` (CI/release)
- **Windows**: Administrator elevation for Wintun and `route`; fetch sidecars with `.\tools\fetch_xray_windows.ps1` before `flutter build windows`

## Building

```bash
flutter pub get
```

**Android** — `libv2ray.aar` is committed under `android/app/libs/`; to rebuild it, run `scripts/build_libxray_aar.sh`, then:

```bash
flutter build apk
```

**Linux** — install GTK/tray build deps first (Debian/Ubuntu example):

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libayatana-appindicator3-dev libdbusmenu-gtk3-dev
flutter build linux
```

Bundled helpers for release bundles: `tools/fetch_xray_linux.sh`, `tools/fetch_amneziawg_tools_linux.sh`, `tools/fetch_amneziawg_go_linux.sh` (used in CI).

**Windows** — download Xray + Wintun into `windows/xray/` (CMake copies them next to `asteriaray.exe`):

```powershell
.\tools\fetch_xray_windows.ps1
flutter build windows
```

Run the built app **as Administrator** so Wintun and IPv4 routes can be applied.

## Usage

1. Add a profile (**+**) or import from clipboard/file (VLESS URI or AmneziaWG `.conf` where supported).
2. Select a profile and connect.
3. Use logs on the home screen if something fails.

## VLESS URI format (short)

```
vless://uuid@host:port?security=tls&sni=example.com&alpn=h2,http/1.1&fp=chrome&type=ws&path=/path&host=example.com#ProfileName
```

- `security`: `none` | `tls` | `reality`
- `type`: `tcp` | `ws` | `grpc` | `h2`
- Reality: `pbk`, `sid` (see in-app / parser)

## Android permissions

- `INTERNET`, `ACCESS_NETWORK_STATE`, `BIND_VPN_SERVICE`, `FOREGROUND_SERVICE`, notifications as needed for the VPN flow
