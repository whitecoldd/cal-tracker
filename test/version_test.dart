import 'dart:io';

import 'package:cal_tracker/version.dart';
import 'package:flutter_test/flutter_test.dart';

/// The version lives in three files and they must agree.
///
/// `pubspec.yaml` is what Gradle reads, `lib/version.dart` is what the app
/// prints, and `CHANGELOG.md` is what a human reads. Nothing at runtime
/// notices when they drift apart — the APK would simply carry one number and
/// show another — so the check belongs here, where it fails before a commit.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final changelog = File('CHANGELOG.md').readAsStringSync();

  /// `1.0.0+1` out of the `version:` line.
  final declared = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
      .firstMatch(pubspec)
      ?.group(1);

  test('pubspec declares a version', () {
    expect(declared, isNotNull, reason: 'pubspec.yaml has no version: line');
  });

  test('the version is MAJOR.MINOR.PATCH+BUILD', () {
    // Anchored, and no pre-release or build-metadata suffix: the scheme in
    // CLAUDE.md §9 has exactly four numbers in it, and "1.0.0-rc1+2" would
    // pass a looser pattern and then confuse everything downstream.
    expect(declared, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
  });

  test('lib/version.dart mirrors pubspec.yaml', () {
    expect(appVersionFull, declared);
    expect(appVersion, isNot(contains('+')));
    expect(appBuild, greaterThan(0));
  });

  test('the newest changelog entry is this version', () {
    final newest = RegExp(r'^## (\d+\.\d+\.\d+\+\d+)', multiLine: true)
        .firstMatch(changelog)
        ?.group(1);

    expect(
      newest,
      appVersionFull,
      reason: 'CHANGELOG.md must open with a section for the current version. '
          'Every commit bumps the patch and adds its line — see CLAUDE.md §9.',
    );
  });

  test('the changelog names the release', () {
    expect(changelog, contains(appReleaseName));
  });
}
