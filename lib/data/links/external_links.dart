import 'package:flutter/services.dart';

/// Opening a web page in whatever the phone uses for one.
///
/// Hand-rolled over a platform channel rather than added as `url_launcher`,
/// for the reason CLAUDE.md §3 gives about `permission_handler`: a plugin that
/// resolves in pub can still fail to build on Android, and this project has
/// been bitten by exactly that. The Kotlin side of this is about fifteen lines
/// in `MainActivity.kt`, beside the storage channel that exists for the same
/// reason.
///
/// An interface so tests — which have no platform channel — can substitute a
/// fake and still exercise everything above it.
abstract interface class ExternalLinks {
  /// Opens [url]. Returns false if nothing on the device would take it.
  ///
  /// A boolean rather than a throw: "no browser installed" is a thing to tell
  /// the user about calmly, next to the transcript they can still copy, not an
  /// error to unwind a sheet over.
  Future<bool> open(Uri url);
}

class PlatformExternalLinks implements ExternalLinks {
  const PlatformExternalLinks();

  static const _channel = MethodChannel('com.whitecoldd.cal_tracker/links');

  @override
  Future<bool> open(Uri url) async {
    // Only ever http(s). The channel would happily fire any intent it is
    // handed, and the one caller builds its URL from a barcode — but a
    // launcher that will open anything is the kind of thing that later gets
    // reused with a string from somewhere less careful.
    if (url.scheme != 'http' && url.scheme != 'https') return false;

    try {
      return await _channel.invokeMethod<bool>(
            'open',
            <String, String>{'url': url.toString()},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Not Android — a test host, or a desktop build.
      return false;
    }
  }
}

/// Records what it was asked to open and opens nothing. For tests.
class RecordingExternalLinks implements ExternalLinks {
  RecordingExternalLinks({this.succeeds = true});

  final bool succeeds;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}
