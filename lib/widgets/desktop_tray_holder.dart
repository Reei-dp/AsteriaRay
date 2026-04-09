import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Linux / Windows / macOS: closing the window hides it; app stays in the system tray.
bool get desktopTraySupported =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// Linux tray is implemented in the GTK runner (`tray_linux.cc`); Dart plugin is Win/macOS only.
bool get _useDartTray =>
    desktopTraySupported && !Platform.isLinux;

class DesktopTrayHolder extends StatefulWidget {
  const DesktopTrayHolder({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopTrayHolder> createState() => _DesktopTrayHolderState();
}

class _DesktopTrayHolderState extends State<DesktopTrayHolder>
    with WindowListener, TrayListener {
  /// Linux: last bounds before "close to tray".
  Rect? _linuxSavedBounds;

  /// True while quitting from the tray menu — ignore [onWindowClose] so destroy can run.
  bool _quitting = false;

  /// Wayland often ignores arbitrary [WindowManager.setBounds]; X11 can use off-screen hide.
  static bool get _linuxWayland {
    final w = Platform.environment['WAYLAND_DISPLAY'];
    return w != null && w.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    if (_useDartTray) {
      trayManager.addListener(this);
    }
    // Re-assert after hot restart / isolate restarts where native flag may not match Dart.
    Future.microtask(() => windowManager.setPreventClose(true));
    _initDesktop();
  }

  Future<void> _initDesktop() async {
    if (!_useDartTray) return;
    try {
      await _initTray();
    } catch (e, st) {
      debugPrint('DesktopTrayHolder: tray init failed, window closes normally: $e');
      debugPrint('$st');
    }
  }

  Future<void> _initTray() async {
    final iconPath = await _materializeTrayIcon();
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('AsteriaRay');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Показать AsteriaRay',
          ),
          MenuItem(
            key: 'quit',
            label: 'Выход',
          ),
        ],
      ),
    );
  }

  /// Tray plugin: macOS reads [iconPath] via [rootBundle.load]; Windows native code uses
  /// [LoadImage] with [IMAGE_ICON] — only `.ico` works, not PNG (`tray_manager_plugin.cpp`).
  Future<String> _materializeTrayIcon() async {
    if (Platform.isMacOS) {
      return 'assets/dekstop_icon.png';
    }
    // Windows (Dart tray only; Linux uses GTK tray in the runner).
    final dir = await getApplicationSupportDirectory();
    final f = File(p.join(dir.path, 'tray_icon.ico'));
    if (!await f.exists()) {
      final data = await rootBundle.load('assets/tray_icon.ico');
      await f.writeAsBytes(data.buffer.asUint8List());
    }
    return f.path;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (_useDartTray) {
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void onWindowClose() async {
    if (_quitting) return;
    assert(() {
      debugPrint('DesktopTrayHolder: close → tray');
      return true;
    }());
    if (Platform.isLinux) {
      await _linuxCloseToTray();
    } else {
      await windowManager.hide();
    }
  }

  /// Wayland: [minimize] keeps a taskbar entry on many compositors (e.g. Plasma); use
  /// [hide] to unmap the window so only the tray icon remains. X11: move off-screen.
  Future<void> _linuxCloseToTray() async {
    try {
      _linuxSavedBounds = await windowManager.getBounds();
      await windowManager.setSkipTaskbar(true);
      if (_linuxWayland) {
        await windowManager.hide();
        return;
      }
      final b = _linuxSavedBounds!;
      await windowManager.setBounds(
        Rect.fromLTWH(-10000, -10000, b.width, b.height),
      );
    } catch (e, st) {
      debugPrint('DesktopTrayHolder: Linux close fallback: $e\n$st');
      try {
        await windowManager.setSkipTaskbar(true);
        await windowManager.hide();
      } catch (e2, st2) {
        debugPrint('DesktopTrayHolder: hide fallback failed: $e2\n$st2');
        try {
          await windowManager.minimize();
        } catch (e3, st3) {
          debugPrint('DesktopTrayHolder: minimize fallback failed: $e3\n$st3');
        }
      }
    }
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key == 'show_window') {
      _showWindow();
    } else if (item.key == 'quit') {
      _quitApp();
    }
  }

  Future<void> _showWindow() async {
    if (Platform.isLinux) {
      await windowManager.setSkipTaskbar(false);
      if (_linuxWayland) {
        await windowManager.show();
        await windowManager.restore();
      }
      final b = _linuxSavedBounds;
      if (b != null) {
        await windowManager.setBounds(b);
      }
    } else {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    _quitting = true;
    try {
      await windowManager.setPreventClose(false);
    } catch (e, st) {
      debugPrint('DesktopTrayHolder: setPreventClose(false): $e\n$st');
    }
    if (_useDartTray) {
      try {
        await trayManager.destroy();
      } catch (e, st) {
        debugPrint('DesktopTrayHolder: tray destroy: $e\n$st');
      }
    }
    try {
      await windowManager.destroy();
    } catch (e, st) {
      debugPrint('DesktopTrayHolder: window destroy: $e\n$st');
      exit(0);
    }
  }
}
