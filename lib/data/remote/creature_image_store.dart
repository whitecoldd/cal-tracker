import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fetches a creature's picture once and keeps it forever.
///
/// `Foods.imagePath` holds a **remote URL** — see `remote_food.dart`. Rendering
/// it naively would mean network I/O on a screen CLAUDE.md §4 requires to work
/// with no key and no network, so the picture is treated exactly like the food
/// data around it: resolved once, written down, never fetched again.
///
/// The cache is the filesystem. A file at `<documents>/creatures/<foodId>` is
/// the hit; there is no index and no schema change, so the column keeps meaning
/// what it says and the cache can be deleted at any time without losing
/// anything that is not re-fetchable.
///
/// **Every failure is silent and returns null.** Offline, a dead link, a 404, a
/// truncated body, a host that now serves HTML: none of them is worth a message
/// on a screen the user opened to read about a food. The plate is decoration;
/// the entry is the content.
///
/// No new dependency. `cached_network_image` would pull in
/// `flutter_cache_manager` and with it `sqflite` — a second SQLite in an app
/// with strong opinions about the first one (§3) — to do less than this does.
class CreatureImageStore {
  CreatureImageStore({Dio? dio, Directory? directory, this.timeout = const Duration(seconds: 10)})
      : _dio = dio ?? Dio(),
        _directory = directory;

  final Dio _dio;

  /// Overridden in tests, which have no `path_provider`.
  final Directory? _directory;

  final Duration timeout;

  /// Anything larger than this is not a food photograph, and is refused before
  /// it reaches the disk.
  static const int maxBytes = 4 * 1024 * 1024;

  static const String folder = 'creatures';

  Future<Directory> _cacheDir() async {
    final base = _directory ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, folder));
  }

  /// The local file for a creature's picture, fetching it if this is the first
  /// time it has been asked for.
  ///
  /// Null when there is no picture, or when there was and it could not be had.
  Future<File?> fileFor({required int foodId, String? url}) async {
    if (url == null || url.trim().isEmpty) return null;

    final File cached;
    try {
      final dir = await _cacheDir();
      cached = File(p.join(dir.path, '$foodId'));

      if (await cached.exists() && await cached.length() > 0) return cached;

      await dir.create(recursive: true);
    } catch (_) {
      // No writable documents directory is not a reason to fail a food sheet.
      return null;
    }

    return _download(url, into: cached);
  }

  Future<File?> _download(String url, {required File into}) async {
    // Written beside the target and renamed, so an interrupted download can
    // never be mistaken for a cache hit by the next call. A half-written file
    // that merely exists would poison this food's plate permanently, which is
    // the one failure this cache cannot recover from on its own.
    final temp = File('${into.path}.part');

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          // A 404 is an answer, not an exception to be thrown through the UI.
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final bytes = response.data;
      if (response.statusCode != 200 ||
          bytes == null ||
          bytes.isEmpty ||
          bytes.length > maxBytes) {
        return null;
      }

      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(into.path);
      return into;
    } catch (_) {
      // Deliberately terminal. Upstream is crowd-sourced and the failure modes
      // are not ours to enumerate — a type error out of a redirect to an HTML
      // error page has to be as harmless here as a socket timeout. Same
      // reasoning as the widened catch in T16.
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {
        // Nothing useful to do about a temp file that will not delete.
      }
      return null;
    }
  }
}
