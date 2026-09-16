import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a photographed meal's picture is kept.
///
/// `Entries.photoPath` has existed since T9 and was written by nothing: the
/// photo path compressed a picture, sent it to a vision model, logged the items
/// it came back with, and dropped the picture on the floor. This keeps it.
///
/// **The column holds a path relative to the documents directory, never an
/// absolute one.** An absolute path is a fact about where the app happened to
/// be installed, and it stops being true the moment that changes — which is
/// precisely the situation a restored backup is in. A name resolved against
/// wherever the app lives now cannot go stale that way.
class MealPhotoStore {
  MealPhotoStore({Directory? directory}) : _directory = directory;

  /// Overridden in tests, which have no `path_provider`.
  final Directory? _directory;

  static const String folder = 'meals';

  Future<Directory> _base() async =>
      _directory ?? await getApplicationDocumentsDirectory();

  /// Writes [jpeg] and returns the relative path to record on the entries.
  ///
  /// Null when it could not be written, which is never worth failing a meal
  /// over: the food is the log, the picture is a souvenir.
  Future<String?> save(Uint8List jpeg, {required String stamp}) async {
    if (jpeg.isEmpty) return null;

    try {
      final dir = Directory(p.join((await _base()).path, folder));
      await dir.create(recursive: true);

      // Colons are legal in a path on Android and not on Windows, and this
      // string is an ISO timestamp. Replaced so a desktop test writes the same
      // name a phone does.
      final name = '${stamp.replaceAll(':', '-')}.jpg';
      await File(p.join(dir.path, name)).writeAsBytes(jpeg, flush: true);

      return p.join(folder, name).replaceAll(r'\', '/');
    } catch (_) {
      return null;
    }
  }

  /// The file a recorded path points at, or null if it is not there any more.
  ///
  /// **Missing is an ordinary answer, not an error.** The backup mirror holds
  /// table rows and a Markdown journal — no binaries — so after a restore every
  /// `photoPath` names a file that does not exist. The entry is still true; only
  /// its souvenir is gone.
  Future<File?> resolve(String? relative) async {
    if (relative == null || relative.trim().isEmpty) return null;

    try {
      final file = File(p.join((await _base()).path, relative));
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// Deletes photographs no entry points at any more.
  ///
  /// One photograph belongs to several entries — a dish breaks into its
  /// components and they all carry the same path — so an entry being deleted
  /// cannot delete the file. Without a sweep the orphans stay for the life of
  /// the install, which is the difference between a feature and a leak.
  ///
  /// Takes the paths still in use rather than reading the database itself: this
  /// is a file-system concern, and a store that knew how to query entries would
  /// be two things at once.
  Future<int> prune(Set<String> stillUsed) async {
    try {
      final dir = Directory(p.join((await _base()).path, folder));
      if (!await dir.exists()) return 0;

      final keep = {
        for (final path in stillUsed) p.basename(path.replaceAll(r'\', '/')),
      };

      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (keep.contains(p.basename(entity.path))) continue;

        await entity.delete();
        removed++;
      }
      return removed;
    } catch (_) {
      // A sweep that cannot run is not a failure anyone needs to hear about.
      return 0;
    }
  }
}
