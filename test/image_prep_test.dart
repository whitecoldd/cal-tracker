import 'dart:convert';
import 'dart:typed_data';

import 'package:cal_tracker/data/ai/image_prep.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the platform channel, which no unit test can run.
class _FakeCompressor implements PhotoCompressor {
  _FakeCompressor(this.output);

  final Uint8List output;
  final List<int> sawBytes = [];

  @override
  Future<Uint8List> compress(Uint8List original) async {
    sawBytes.add(original.length);
    return output;
  }
}

Uint8List _bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List.filled(length, fill));

void main() {
  group('the data URI', () {
    test('is the format a vision model expects', () {
      final uri = ImagePrep.toDataUri(_bytes(9));

      expect(uri, startsWith('data:image/jpeg;base64,'));
      expect(
        base64Decode(uri.split(',').last),
        _bytes(9),
      );
    });

    test('refuses a payload past the cap', () {
      // Sending it would spend one of fifty daily requests on an upload
      // likely to time out anyway.
      expect(
        () => ImagePrep.toDataUri(_bytes(ImagePolicy.maxBytes + 1)),
        throwsA(isA<ImageTooLarge>()),
      );
    });

    test('accepts a payload exactly at the cap', () {
      expect(
        () => ImagePrep.toDataUri(_bytes(ImagePolicy.maxBytes)),
        returnsNormally,
      );
    });
  });

  group('preparing a photograph', () {
    test('compresses, then encodes', () async {
      final compressor = _FakeCompressor(_bytes(120));
      final prep = ImagePrep(compressor: compressor);

      final prepared = await prep.prepare(_bytes(3 * 1024 * 1024));

      expect(compressor.sawBytes, [3 * 1024 * 1024]);
      expect(base64Decode(prepared.dataUri.split(',').last), hasLength(120));
    });

    test('the bytes kept are the same bytes sent', () async {
      // The copy stored on the phone is the compressed one, so it is small and
      // it has had its EXIF stripped. Compressing a second time to get it would
      // be the same work twice and a second chance to disagree.
      final prep = ImagePrep(compressor: _FakeCompressor(_bytes(120)));

      final prepared = await prep.prepare(_bytes(3 * 1024 * 1024));

      expect(prepared.jpeg, hasLength(120));
      expect(base64Decode(prepared.dataUri.split(',').last), prepared.jpeg);
    });

    test('rejects something too small to be a photograph', () async {
      final prep = ImagePrep(compressor: _FakeCompressor(_bytes(10)));

      await expectLater(
        prep.prepare(_bytes(10)),
        throwsA(isA<ImageTooLarge>()),
      );
    });

    test('a compressor that returns something enormous still fails', () async {
      // The cap is enforced after compression, not before: a compressor that
      // misbehaves must not be able to push a huge upload through.
      final prep = ImagePrep(
        compressor: _FakeCompressor(_bytes(ImagePolicy.maxBytes + 1)),
      );

      await expectLater(
        prep.prepare(_bytes(2 * 1024 * 1024)),
        throwsA(isA<ImageTooLarge>()),
      );
    });
  });

  group('the policy', () {
    test('shrinks to something a model resolves but a phone can send', () {
      // A phone camera produces twelve megapixels and 3-4 MB; a vision model
      // charges by the tile and the free tier gives fifty requests a day.
      expect(ImagePolicy.maxEdge, lessThanOrEqualTo(1280));
      expect(ImagePolicy.maxEdge, greaterThanOrEqualTo(768));
      expect(ImagePolicy.quality, lessThan(90));
    });

    test('the cap leaves room for a normal meal photograph', () {
      // At 1024px and quality 70 a plate lands around 100-200 KB, so the cap
      // is a backstop rather than something an ordinary photo brushes against.
      expect(ImagePolicy.maxBytes, greaterThan(500 * 1024));
    });
  });

  group('encodedLength', () {
    test('accounts for base64 growing the payload by a third', () {
      // The figure that actually crosses the network.
      expect(ImagePrep.encodedLength(3), 4);
      expect(ImagePrep.encodedLength(6), 8);
      // Padding rounds up to the next block.
      expect(ImagePrep.encodedLength(1), 4);
      expect(ImagePrep.encodedLength(4), 8);
    });

    test('matches what base64 actually produces', () {
      for (final length in [1, 2, 3, 100, 999]) {
        expect(
          ImagePrep.encodedLength(length),
          base64Encode(_bytes(length)).length,
          reason: 'for $length bytes',
        );
      }
    });
  });
}
