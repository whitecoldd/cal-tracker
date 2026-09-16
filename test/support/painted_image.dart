import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

/// An [ImageProvider] that is ready on the first frame.
///
/// Every ordinary image provider decodes asynchronously — `MemoryImage` and
/// `FileImage` both go through `instantiateImageCodec`, which needs a real
/// event loop. A widget test body runs in fake async that never turns one, so
/// an image either never appears or the test hangs waiting for it (the same
/// trap CLAUDE.md §2 describes for drift queries).
///
/// `toImageSync` rasterises a recorded picture immediately, so this one is
/// available the moment it is asked for and a golden can draw it.
///
/// Shared rather than copied into each suite, for the reason
/// `fake_openrouter.dart` gives: two of them would drift apart.
class PaintedTestImage extends ImageProvider<PaintedTestImage> {
  const PaintedTestImage({this.color = const Color(0xFFB07A3C), this.size = 32});

  final Color color;
  final int size;

  @override
  Future<PaintedTestImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<PaintedTestImage>(this);

  @override
  ImageStreamCompleter loadImage(
    PaintedTestImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: _paint())),
    );
  }

  ui.Image _paint() {
    final recorder = ui.PictureRecorder();
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

    Canvas(recorder, rect).drawRect(rect, Paint()..color = color);

    return recorder.endRecording().toImageSync(size, size);
  }

  @override
  bool operator ==(Object other) =>
      other is PaintedTestImage && other.color == color && other.size == size;

  @override
  int get hashCode => Object.hash(color, size);
}
