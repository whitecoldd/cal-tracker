import 'dart:io';
import 'dart:typed_data';

import 'package:cal_tracker/data/meal_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late MealPhotoStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('meal_photos_test');
    store = MealPhotoStore(directory: dir);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final jpeg = Uint8List.fromList(List<int>.filled(64, 9));

  Directory folder() => Directory(p.join(dir.path, MealPhotoStore.folder));

  group('keeping a photograph', () {
    test('writes the bytes and hands back a path that resolves', () async {
      final path = await store.save(jpeg, stamp: '2026-09-16T12:00:00.000');

      expect(path, isNotNull);
      final file = await store.resolve(path);
      expect(await file!.readAsBytes(), jpeg);
    });

    test('the recorded path is relative, never absolute', () async {
      // An absolute path is a fact about where the app happened to be
      // installed, and it stops being true the moment that changes. A restored
      // backup is exactly that situation.
      final path = await store.save(jpeg, stamp: '2026-09-16T12:00:00.000');

      expect(p.isAbsolute(path!), isFalse);
      expect(path, startsWith(MealPhotoStore.folder));
      expect(path, isNot(contains(dir.path)));
    });

    test('the name survives a filesystem that refuses colons', () async {
      // The stamp is an ISO timestamp. Colons are legal in an Android path and
      // not in a Windows one, and the tests run on Windows.
      final path = await store.save(jpeg, stamp: '2026-09-16T12:00:00.000');

      expect(path, isNot(contains(':')));
      expect(await store.resolve(path), isNotNull);
    });

    test('nothing to keep is not a file', () async {
      expect(await store.save(Uint8List(0), stamp: 'x'), isNull);
    });
  });

  group('a photograph that is gone', () {
    test('resolves to nothing rather than failing', () async {
      // The normal state after a restore: the mirror carries table rows and a
      // Markdown journal, never binaries, so the entries come back and their
      // photographs do not. The entry is still true.
      expect(await store.resolve('meals/never-existed.jpg'), isNull);
      expect(await store.resolve(null), isNull);
      expect(await store.resolve('   '), isNull);
    });
  });

  group('the sweep', () {
    test('keeps what entries still point at and deletes the rest', () async {
      final kept = await store.save(jpeg, stamp: '2026-09-16T10:00:00.000');
      final orphan = await store.save(jpeg, stamp: '2026-09-16T11:00:00.000');

      expect(await store.prune({kept!}), 1);

      expect(await store.resolve(kept), isNotNull);
      expect(await store.resolve(orphan), isNull);
    });

    test('one photograph shared by several entries is kept once', () async {
      // A dish breaks into components and every one of them carries the same
      // path, so the set the sweep is given has one entry for many rows.
      final path = await store.save(jpeg, stamp: '2026-09-16T10:00:00.000');

      expect(await store.prune({path!, path}), 0);
      expect(await store.resolve(path), isNotNull);
    });

    test('nothing in use empties the folder', () async {
      await store.save(jpeg, stamp: '2026-09-16T10:00:00.000');
      await store.save(jpeg, stamp: '2026-09-16T11:00:00.000');

      expect(await store.prune(const {}), 2);
      expect(folder().listSync(), isEmpty);
    });

    test('a folder that was never written is not an error', () async {
      expect(await store.prune(const {}), 0);
    });
  });
}
