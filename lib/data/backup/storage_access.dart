import 'package:flutter/services.dart';

/// All-files access, over the platform channel in `MainActivity.kt`.
///
/// Hand-rolled rather than a package because `permission_handler` does not
/// compile against this project's Gradle setup, and this is the only
/// permission it was wanted for. See CLAUDE.md §3.
///
/// An interface so tests — which have no platform channel — can substitute a
/// fake and still exercise everything above it.
abstract interface class StorageAccess {
  Future<bool> hasAccess();

  /// Sends the user to the system settings screen.
  ///
  /// Returns nothing, because Android returns nothing: the user leaves the app
  /// and may never come back. Re-check [hasAccess] on resume rather than
  /// waiting for a result that might never arrive.
  Future<void> requestAccess();
}

class PlatformStorageAccess implements StorageAccess {
  const PlatformStorageAccess();

  static const _channel =
      MethodChannel('com.whitecoldd.cal_tracker/storage');

  @override
  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Not Android — a test host, or the web build.
      return false;
    }
  }

  @override
  Future<void> requestAccess() async {
    try {
      await _channel.invokeMethod<void>('requestAccess');
    } on PlatformException {
      // Nothing useful to do: the screen either opened or it did not, and the
      // resume check will tell us which.
    } on MissingPluginException {
      // Not Android.
    }
  }
}

/// Always granted. For tests and for a host with no channel.
class AlwaysGrantedStorageAccess implements StorageAccess {
  const AlwaysGrantedStorageAccess();

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<void> requestAccess() async {}
}
