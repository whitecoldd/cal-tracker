import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// How a photo is prepared before it is sent to a model.
///
/// The numbers are the whole design. A phone camera produces 3-4 MB and twelve
/// megapixels; a vision model charges for that by the tile, and the free tier
/// gives fifty requests a day. Shrinking to a long edge of 1024 costs nothing
/// in recognition — a plate of food is not a document — and turns a
/// multi-megabyte upload into something that sends over a phone connection.
abstract final class ImagePolicy {
  /// Longest edge, in pixels, after scaling.
  ///
  /// Comfortably above what a vision model resolves a meal at, and far below
  /// what a camera produces.
  static const int maxEdge = 1024;

  /// JPEG quality. Food photographs survive this well; text would not.
  static const int quality = 70;

  /// Refuse to send anything larger than this, in bytes.
  ///
  /// A backstop rather than an expectation: at 1024px and quality 70 a meal
  /// lands around 100-200 KB. If something arrives far bigger, sending it
  /// would spend a request on an upload likely to time out anyway.
  static const int maxBytes = 1500 * 1024;

  /// Smallest input worth sending. Below this it is not a photograph.
  static const int minBytes = 1024;
}

/// A photo that was too large, or too small to be an image at all.
class ImageTooLarge implements Exception {
  const ImageTooLarge(this.bytes);
  final int bytes;

  @override
  String toString() =>
      'ImageTooLarge: ${(bytes / 1024).round()} KB after compression';
}

/// Turns camera bytes into something a model can be sent.
///
/// An interface because the real implementation is a platform channel, which
/// no unit test can run — and the interesting rules (the size cap, the data
/// URI format) are worth testing without a device.
abstract interface class PhotoCompressor {
  Future<Uint8List> compress(Uint8List original);
}

class ImageCompressor implements PhotoCompressor {
  const ImageCompressor();

  @override
  Future<Uint8List> compress(Uint8List original) {
    return FlutterImageCompress.compressWithList(
      original,
      minWidth: ImagePolicy.maxEdge,
      minHeight: ImagePolicy.maxEdge,
      quality: ImagePolicy.quality,
      format: CompressFormat.jpeg,
      // **Explicit, and a privacy decision rather than an inherited default.**
      // A camera photo carries EXIF, and EXIF carries GPS coordinates. This
      // app keeps everything on the device; sending the location of the user's
      // kitchen to a third party along with a picture of dinner would quietly
      // undo that. Re-encoding drops it.
      keepExif: false,
    );
  }
}

/// A photograph ready to send, and the bytes that were sent.
class PreparedPhoto {
  const PreparedPhoto({required this.jpeg, required this.dataUri});

  /// Compressed, re-encoded, and stripped of EXIF.
  final Uint8List jpeg;

  /// The same bytes as the vision API wants them.
  final String dataUri;
}

/// Prepares a photo for a vision request.
class ImagePrep {
  const ImagePrep({PhotoCompressor compressor = const ImageCompressor()})
      : _compressor = compressor;

  final PhotoCompressor _compressor;

  /// Compresses [original] and returns both what to send and what to keep.
  ///
  /// Throws [ImageTooLarge] rather than sending something that would spend a
  /// request on a request that fails.
  ///
  /// It hands back the JPEG as well as the URI because the compressed bytes
  /// are the right thing to *store*: they are already the smallest version
  /// that still shows the meal, and they have had their EXIF stripped by
  /// [ImageCompressor] — so the copy kept on the phone cannot carry the GPS
  /// coordinates of the user's kitchen either. Compressing a second time to get
  /// them would be the same work twice and a second chance to disagree.
  Future<PreparedPhoto> prepare(Uint8List original) async {
    if (original.length < ImagePolicy.minBytes) {
      throw const ImageTooLarge(0);
    }

    final compressed = await _compressor.compress(original);

    return PreparedPhoto(jpeg: compressed, dataUri: toDataUri(compressed));
  }

  /// Wraps JPEG bytes as a `data:` URI, checking the size cap.
  ///
  /// Pure, so the cap and the format are testable without a device.
  static String toDataUri(Uint8List jpeg) {
    if (jpeg.length > ImagePolicy.maxBytes) {
      throw ImageTooLarge(jpeg.length);
    }
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }

  /// How many bytes a base64 payload will occupy on the wire.
  ///
  /// Base64 is four characters per three bytes. Worth knowing because it is
  /// the figure that actually crosses the network, and it is a third larger
  /// than the number the size cap talks about.
  static int encodedLength(int rawBytes) => ((rawBytes + 2) ~/ 3) * 4;
}
