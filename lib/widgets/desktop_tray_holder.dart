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

class DesktopTrayHolder extends StatefulWidget {
  const DesktopTrayHolder({super.key, required this.child});
 
  final Widget child;

  @override
  State<DesktopTrayHolder> createState() => _DesktopTrayHolderState();
}

class _DesktopTrayHolderState extends State<DesktopTrayHolder>
    with WindowListener, TrayListener {
  /// Linux: last bounds before "close to tray" (off-screen move); avoid hide/minimize
  /// which unmap the window and can trigger FlutterEngineRemoveView on the GTK embedder.
  Rect? _linuxSavedBounds;

  /// True while quitting from the tray menu — ignore [onWindowClose] so destroy can run.
  bool _quitting = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    // Re-assert after hot restart / isolate restarts where native flag may not match Dart.
    Future.microtask(() => windowManager.setPreventClose(true));
    _initDesktop();
  }

  Future<void> _initDesktop() async {
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
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Выход',
          ),
        ],
      ),
    );
  }

  Future<String> _materializeTrayIcon() async {
    final dir = await getApplicationSupportDirectory();
    final f = File(p.join(dir.path, 'tray_icon.png'));
    if (!await f.exists()) {
      final data = await rootBundle.load('assets/icon.png');
      await f.writeAsBytes(data.buffer.asUint8List());
    }
    return f.path;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void onWindowClose() async {
    if (_quitting) return;
    // Do not gate on isPreventClose() — it can read false while GTK still prevents
    // close, so the window would stay open with no tray action and no logs.
    assert(() {
      debugPrint('DesktopTrayHolder: close → tray');
      return true;
    }());
    // Linux: hide() and minimize()/iconify() unmap the GTK window and can trigger
    // FlutterEngineRemoveView ("implicit view cannot be removed"). Moving off-screen
    // keeps the view mapped; setPreventClose is set from main() to avoid races.
    if (Platform.isLinux) {
      _linuxSavedBounds = await windowManager.getBounds();
      await windowManager.setSkipTaskbar(true);
      final w = _linuxSavedBounds!.width;
      final h = _linuxSavedBounds!.height;
      await windowManager.setBounds(
        Rect.fromLTWH(-10000, -10000, w, h),
      );
    } else {
      await windowManager.hide();
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
    await trayManager.destroy();
    await windowManager.destroy();
  }
}
