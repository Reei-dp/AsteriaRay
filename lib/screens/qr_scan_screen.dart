import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';

/// Scans a QR code and returns the decoded text via [Navigator.pop].
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  Future<void> _requestCameraAccess() async {
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (e.errorCode != MobileScannerErrorCode.permissionDenied) return;
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isGranted) {
        await _controller.start();
        return;
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline_rounded,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? l10n.cameraPermissionHint
                    : (error.errorDetails?.message ?? l10n.cameraOpenFailed),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _requestCameraAccess,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(denied ? l10n.allowAccess : l10n.retry),
              ),
              if (denied) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: Text(l10n.openAppSettings),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQrTitle),
        actions: [
          IconButton(
            tooltip: l10n.flashlight,
            onPressed: () => _controller.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded);
                  case TorchState.off:
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off_rounded);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto_rounded);
                }
              },
            ),
          ),
          IconButton(
            tooltip: l10n.switchCamera,
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _buildError,
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                l10n.scanQrHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
