# AsteriaRay

Cross-platform VPN client (Flutter) with native tunnels: **VLESS** (Xray-core on Android and Linux) and **AmneziaWG** (WireGuard-compatible `.conf`) on supported platforms.

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
<td align="center">❌</td>
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

- **VLESS**: URI import (`vless://…`), profiles stored in-app; **Android** uses **libv2ray.aar**, **Linux** bundles **xray** (same Xray JSON).
- **AmneziaWG**: import WireGuard-style `[Interface]` / `[Peer]` config; not plain stock WireGuard unless the config matches what the bundled **AmneziaWG** stack expects.
- **OpenVPN** and **L2TP** are not implemented (`VpnProtocol` has no active variants for them; imports like OpenVPN are rejected until parsers/backends exist).
- **Linux desktop**: system tray uses a native GTK / StatusNotifier path; see `linux/runner/tray_linux.cc`.

## Features

- **VLESS**: TLS, Reality, TCP / WebSocket / gRPC / HTTP/2 transports; profile CRUD, clipboard and file import, logs
- **AmneziaWG**: `.conf` profiles on Android and Linux only
- **Profile management**: multiple profiles, switching, export/share where applicable
- **Native integration**: Android **VpnService** + Xray; Linux **xray** + `awg-quick` / bundled tools (see `linux/` and `tools/`)
- **Connection status** and statistics where the platform exposes them
- **Modern UI**: Material Design

## Architecture (overview)

- **Flutter**: UI and orchestration (`lib/`)
- **Android**: Kotlin + libv2ray, `LibxrayVpnService`, MethodChannel (`android/app/src/main/kotlin/…`)
- **Linux**: `VpnPlatformLinux` — `xray` for VLESS, AmneziaWG via `awg-quick` (see `lib/services/vpn_platform_linux.dart`)
- **Platform entry**: `createVpnPlatform()` in `lib/services/vpn_platform.dart` — **Android** and **Linux** only for VPN

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
```

## Requirements

- **Flutter** (stable)
- **Android**: SDK, device with VPN; `android/app/libs/libv2ray.aar` (see `scripts/build_libxray_aar.sh` or releases of AndroidLibXrayLite)
- **Linux**: `pkexec`/polkit or passwordless sudo for TUN where required; optional bundled binaries via `tools/fetch_*.sh` (CI/release)

## Building

```bash
flutter pub get
```

**Android** — положите `libv2ray.aar` в `android/app/libs/`, затем:

```bash
flutter build apk
```

**Linux** — install GTK/tray build deps first (Debian/Ubuntu example):

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libayatana-appindicator3-dev libdbusmenu-gtk3-dev
flutter build linux
```

Bundled helpers for release bundles: `tools/fetch_xray_linux.sh`, `tools/fetch_amneziawg_tools_linux.sh`, `tools/fetch_amneziawg_go_linux.sh` (used in CI).

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
