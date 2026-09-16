import 'dart:io';
import 'dart:typed_data';

import 'package:cal_tracker/data/remote/creature_image_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// One canned HTTP reply.
class _Reply {
  const _Reply.bytes(this.bytes) : status = 200, throws = false;
  const _Reply.status(this.status) : bytes = const [], throws = false;
  const _Reply.boom()
      : status = 200,
        bytes = const [],
        throws = true;

  final int status;
  final List<int> bytes;
  final bool throws;
}

/// Stands in for the network. No test may reach a real image host: it would be
/// slow, flaky, and would hammer Open Food Facts from a test suite.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  final List<_Reply> replies;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = replies[calls.clamp(0, replies.length - 1)];
    calls++;

    if (reply.throws) throw const SocketException('offline');

    return ResponseBody.fromBytes(reply.bytes, reply.status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('creatures_test'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ({CreatureImageStore store, _FakeAdapter adapter}) build(
    List<_Reply> replies,
  ) {
    final adapter = _FakeAdapter(replies);
    return (
      store: CreatureImageStore(
        dio: Dio()..httpClientAdapter = adapter,
        directory: dir,
      ),
      adapter: adapter,
    );
  }

  const url = 'https://images.example/almonds.jpg';
  final bytes = List<int>.filled(128, 7);

  group('fetching a plate', () {
    test('downloads it once and reads it from disk after that', () async {
      // The whole point of the store. A food costs at most one fetch, ever —
      // the same rule the food library itself follows (CLAUDE.md §4).
      final built = build([_Reply.bytes(bytes)]);

      final first = await built.store.fileFor(foodId: 12, url: url);
      expect(first, isNotNull);
      expect(await first!.readAsBytes(), bytes);
      expect(built.adapter.calls, 1);

      final second = await built.store.fileFor(foodId: 12, url: url);
      expect(second!.path, first.path);
      expect(built.adapter.calls, 1, reason: 'the second read hit the disk');
    });

    test('a cached plate is served with the network gone', () async {
      // The offline guarantee: once seen, a picture keeps working.
      final built = build([_Reply.bytes(bytes), const _Reply.boom()]);

      await built.store.fileFor(foodId: 12, url: url);

      final offline = CreatureImageStore(
        dio: Dio()..httpClientAdapter = _FakeAdapter([const _Reply.boom()]),
        directory: dir,
      );

      expect(await offline.fileFor(foodId: 12, url: url), isNotNull);
    });

    test('different foods do not collide', () async {
      final built = build([_Reply.bytes(bytes)]);

      final a = await built.store.fileFor(foodId: 1, url: url);
      final b = await built.store.fileFor(foodId: 2, url: url);

      expect(a!.path, isNot(b!.path));
      expect(built.adapter.calls, 2);
    });
  });

  group('everything that can go wrong is silent', () {
    test('no url at all is not a fetch', () async {
      final built = build([_Reply.bytes(bytes)]);

      expect(await built.store.fileFor(foodId: 1), isNull);
      expect(await built.store.fileFor(foodId: 1, url: '   '), isNull);
      expect(built.adapter.calls, 0);
    });

    test('offline returns nothing rather than throwing', () async {
      // A food sheet must not fail because a decorative picture could not be
      // had. Nothing on this path is the user's to act on.
      final built = build([const _Reply.boom()]);

      expect(await built.store.fileFor(foodId: 1, url: url), isNull);
    });

    test('a dead link is an answer, not an exception', () async {
      final built = build([const _Reply.status(404)]);

      expect(await built.store.fileFor(foodId: 1, url: url), isNull);
    });

    test('an empty body is refused', () async {
      final built = build([const _Reply.bytes([])]);

      expect(await built.store.fileFor(foodId: 1, url: url), isNull);
    });

    test('something far too large to be a food photograph is refused',
        () async {
      final built = build([
        _Reply.bytes(List<int>.filled(CreatureImageStore.maxBytes + 1, 0)),
      ]);

      expect(await built.store.fileFor(foodId: 1, url: url), isNull);
    });
  });

  group('a failed download cannot poison the cache', () {
    test('nothing is left behind for the next call to find', () async {
      // The one failure this cache could not recover from on its own: a
      // half-written file that merely *exists* would be served as a hit for
      // the life of the install. Hence the write-then-rename.
      final built = build([const _Reply.boom(), _Reply.bytes(bytes)]);

      expect(await built.store.fileFor(foodId: 9, url: url), isNull);

      final cacheDir = Directory('${dir.path}/${CreatureImageStore.folder}');
      if (cacheDir.existsSync()) {
        expect(
          cacheDir.listSync(),
          isEmpty,
          reason: 'a partial download was left in the cache',
        );
      }

      // And the next attempt still works.
      expect(await built.store.fileFor(foodId: 9, url: url), isNotNull);
    });
  });
}
