import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';

/// Reads a barcode and returns it. Nothing is looked up or logged here.
///
/// Keeping the screen ignorant of the food library is what lets it be a plain
/// `Navigator.push` that returns a `String?` — the caller owns the resolution
/// order, and this owns the camera.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  /// Pushes the scanner and resolves to the scanned barcode, or null if the
  /// user backed out.
  static Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Only the formats actually printed on food packaging. Narrowing the set
  // makes detection faster and stops the scanner locking onto a QR code on the
  // same label.
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );

  /// The camera keeps firing after a hit. Without this latch the screen pops
  /// once per frame and unwinds the whole navigator.
  bool _handled = false;

  /// Set when a label was seen but could not be decoded.
  bool _unreadable = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;

    _handled = true;

    // The one moment the user learns the read succeeded. Everything after this
    // happens on the sheet behind, and without a tick here a lookup that finds
    // nothing is indistinguishable from a camera that never read anything.
    HapticFeedback.mediumImpact();

    // A capture can arrive after the route has begun to pop — the user pressing
    // back on the same frame as a successful read.
    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  /// A barcode the camera saw but could not decode.
  ///
  /// [MobileScanner] silently discards these when no handler is given, so a
  /// damaged or badly-lit label used to leave the preview running with nothing
  /// to show for it. Not fatal — the next frame may well read — so it is said
  /// once, quietly, under the reticle.
  void _onDetectError(Object error, StackTrace stackTrace) {
    if (!mounted || _handled) return;
    setState(() => _unreadable = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Hue.voidBlack,
      appBar: AppBar(
        title: Text('SCAN THE SIGIL', style: Type.heading(size: 16)),
        backgroundColor: Hue.voidBlack,
        iconTheme: const IconThemeData(color: Hue.parchment),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            onDetectError: _onDetectError,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          const _ScanReticle(),
          Positioned(
            left: Space.lg,
            right: Space.lg,
            bottom: Space.xl,
            child: Text(
              _unreadable
                  ? 'That mark will not be read. Hold steadier, or find better '
                      'light.'
                  : 'Hold the barcode inside the frame.',
              textAlign: TextAlign.center,
              style: Type.lore(
                color: _unreadable ? Hue.adrenaline : Hue.parchment,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner brackets over the camera feed, matching [OrnatePanel].
class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 170,
        child: CustomPaint(painter: _ReticlePainter()),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Hue.gold
      ..strokeWidth = Geometry.frameStroke * 2
      ..style = PaintingStyle.stroke;

    const arm = Geometry.bracketArm * 1.6;

    // Four corner brackets, drawn as two strokes each.
    for (final (x, dx) in [(0.0, 1.0), (size.width, -1.0)]) {
      for (final (y, dy) in [(0.0, 1.0), (size.height, -1.0)]) {
        canvas
          ..drawLine(Offset(x, y), Offset(x + arm * dx, y), paint)
          ..drawLine(Offset(x, y), Offset(x, y + arm * dy), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  /// The camera permission is requested by the plugin itself — there is no
  /// `permission_handler` in this project (CLAUDE.md §3) — so a denial arrives
  /// here as an error rather than as a prompt we control.
  String get _message => switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'The camera has not been granted. Enable it in Android settings, '
              'or search for the food by name instead.',
        MobileScannerErrorCode.unsupported =>
          'This device cannot scan barcodes.',
        _ => 'The camera could not be opened.',
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: OrnatePanel(
          title: 'No sight',
          accent: Hue.bloodRed,
          child: Text(_message, style: Type.lore(size: 13)),
        ),
      ),
    );
  }
}
