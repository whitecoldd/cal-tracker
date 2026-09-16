/// The app's own version, as a Dart constant.
///
/// `pubspec.yaml` is the source of truth — this file mirrors it so a screen can
/// print the version without `package_info_plus`, which is a plugin, and
/// CLAUDE.md §3 is a record of what an unnecessary plugin costs on Android.
///
/// The mirror is not maintained by discipline: `test/version_test.dart` reads
/// `pubspec.yaml` and `CHANGELOG.md` and fails if the three disagree. So a
/// commit that bumps one and forgets the others does not build green.
///
/// The scheme is `MAJOR.MINOR.PATCH+BUILD`, documented in CLAUDE.md §9:
/// every commit moves PATCH, a large change moves MINOR, a remaster moves
/// MAJOR, and BUILD only ever counts upward because Play will not accept a
/// versionCode it has already seen.
library;

/// The semantic version, without the build number.
const String appVersion = '1.0.3';

/// The Android `versionCode`. Monotonic, one per released version.
const int appBuild = 4;

/// What `pubspec.yaml` says, in full.
const String appVersionFull = '$appVersion+$appBuild';

/// The name this version answers to in the changelog.
///
/// Flavour, not identity — nothing keys off it. It exists because "1.0.0" says
/// nothing about what a release *was*, and the vault and the changelog both
/// want a handle for it.
const String appReleaseName = 'First Contract';
