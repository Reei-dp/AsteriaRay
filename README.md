# AsteriaRay

A modern Android VPN client for the VLESS protocol, built with Flutter and powered by sing-box.

## Features

- **VLESS Protocol Support**: Full support for VLESS with TLS, Reality, and various transport types
- **Profile Management**: Add, edit, delete, and switch between multiple VLESS profiles
- **Import/Export**: Import profiles from clipboard or file, export and share configurations
- **Reality Support**: Built-in support for Reality protocol with public key and short ID
- **Transport Types**: Support for TCP, WebSocket (WS), gRPC, and HTTP/2 transports
- **Native Integration**: Uses embedded libcore (NekoBox/sing-box) for VPN core
- **Connection Status**: Real-time VPN connection status and statistics
- **Logs Viewing**: View sing-box logs directly in the app
- **Modern UI**: Clean and intuitive Material Design interface

## Architecture

AsteriaRay is built with Flutter for cross-platform UI and uses native Android components for VPN functionality:

- **Flutter**: UI layer and business logic
- **libcore**: NekoBox libcore (sing-box) via JNI for VPN core functionality
- **VpnService**: Android VPN service for TUN interface management
- **Platform Channels**: Communication between Flutter and native Android code

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── vless_profile.dart   # VLESS profile model
│   └── vless_types.dart     # Transport types and utilities
├── services/                 # Business logic services
│   ├── profile_store.dart   # Profile persistence
│   ├── vless_uri.dart       # URI parser
│   ├── vpn_platform.dart    # VPN platform interface
│   └── xray_runner.dart     # sing-box configuration builder
├── notifiers/                # State management
│   ├── profile_notifier.dart
│   └── vpn_notifier.dart
└── screens/                  # UI screens
    ├── home_screen.dart
    ├── profile_form_screen.dart
    └── log_screen.dart

android/
└── app/src/main/kotlin/vpn/asteria/com/
    ├── AsteriaApplication.kt       # Application entry, libcore init
    ├── MainActivity.kt             # Method channel handler
    ├── LibcoreVpnService.kt        # VPN service implementation
    ├── LibcorePlatformInterface.kt # Platform callbacks for libcore
    ├── DefaultNetworkMonitor.kt    # Network monitoring
    └── LocalResolver.kt           # DNS resolver
```

## Requirements

- Flutter SDK (latest stable)
- Android SDK (API level 21+)
- Android device with VPN support
- libcore.aar (from NekoBoxForAndroid build)

## Building

1. Clone the repository and install dependencies:
```bash
flutter pub get
```

2. Build libcore and copy it into the project (requires Go and Android NDK):
```bash
cd ../NekoBoxForAndroid
./run lib core
cd -
./scripts/copy_libcore.sh
```
Or with custom NekoBox path: `./scripts/copy_libcore.sh /path/to/NekoBoxForAndroid`

3. Build the APK:
```bash
flutter build apk
```

Or run in debug mode:
```bash
flutter run
```

## Usage

1. **Add a Profile**: Tap the "+" button to add a new VLESS profile manually or import from URI
2. **Import Profile**: Use the import button to import from clipboard or file
3. **Connect**: Select a profile and tap "Connect" to start the VPN
4. **View Logs**: Access logs from the home screen to troubleshoot connection issues
5. **Export/Share**: Long-press a profile to export or share the configuration

## VLESS URI Format

AsteriaRay supports standard VLESS URI format:
```
vless://uuid@host:port?security=tls&sni=example.com&alpn=h2,http/1.1&fp=chrome&type=ws&path=/path&host=example.com#ProfileName
```

### Parameters

- `security`: `none`, `tls`, or `reality`
- `sni`: Server Name Indication for TLS
- `alpn`: Application-Layer Protocol Negotiation (comma-separated)
- `fp`: uTLS fingerprint (e.g., `chrome`, `firefox`)
- `type`: Transport type (`tcp`, `ws`, `grpc`, `h2`)
- `path`: Path for WS/H2 transport
- `host`: Host header for WS/H2 transport
- `pbk`: Reality public key
- `sid`: Reality short ID

## Configuration

The app generates sing-box configuration automatically based on the selected profile. Key features:

- **TUN Interface**: Automatic TUN interface creation and routing
- **DNS**: Configurable DNS servers with hijacking support
- **Routing**: Automatic route detection and traffic routing
- **Network Monitoring**: Real-time network interface monitoring

## Permissions

The app requires the following Android permissions:

- `INTERNET`: For network connectivity
- `ACCESS_NETWORK_STATE`: For network monitoring
- `BIND_VPN_SERVICE`: For VPN service binding
- `FOREGROUND_SERVICE`: For persistent VPN connection
