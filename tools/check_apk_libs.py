"""Checks that a built APK actually carries the sqlite3 native asset.

`sqlite3` 3.x is delivered as a Dart *code asset*: a build hook drops
`libsqlite3.so` into `build/native_assets/android/jniLibs/lib/<abi>/`, which the
Flutter Gradle plugin has registered as a `jniLibs` source directory. Nothing
verifies the copy happened. If that directory is empty when Gradle runs, the
build still succeeds and the APK installs — and then the very first
`sqlite3` call dies with

    Failed to load dynamic library 'libsqlite3.so'

which surfaces in the app as "The Path is blocked" and nothing else.

`flutter assemble`'s `install_code_assets` step declares only
`native_assets.json` as its output, so deleting `build/native_assets/` by hand
makes the step look up to date forever and the libraries are never re-copied.
That is exactly how a release APK once shipped without SQLite.

Run this after every `flutter build apk`:

    python tools/check_apk_libs.py

Exits non-zero, loudly, when an ABI that has Flutter in it has no SQLite.
"""
import os
import sys
import zipfile
from collections import defaultdict

# Every release APK a documented build command can produce. Which ones exist
# depends on the flags used: `--split-per-abi` writes one file per ABI and no
# `app-release.apk` at all, so checking a fixed single path would silently pass
# by checking nothing, or fail on a file that was never supposed to exist.
DEFAULT_APKS = [
    'build/app/outputs/flutter-apk/app-release.apk',
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
    'build/app/outputs/flutter-apk/app-x86_64-release.apk',
]

# An ABI folder that carries the engine is an ABI the app claims to run on, so
# it needs every native asset too. Plugin .so files are not a useful marker:
# they arrive from AARs that ship ABIs the app itself was never built for.
ENGINE = 'libflutter.so'
REQUIRED = ['libsqlite3.so']


def abis(apk):
    """Maps each `lib/<abi>/` folder in the APK to the .so names inside it."""
    found = defaultdict(set)
    with zipfile.ZipFile(apk) as zf:
        for entry in zf.namelist():
            parts = entry.split('/')
            if len(parts) == 3 and parts[0] == 'lib' and parts[2].endswith('.so'):
                found[parts[1]].add(parts[2])
    return found


def check(apk):
    """Returns a list of human-readable problems with one APK."""
    try:
        found = abis(apk)
    except FileNotFoundError:
        return ['not found (build it first)']
    except zipfile.BadZipFile:
        return ['not a readable APK']

    if not found:
        return ['contains no native libraries at all']

    # A split-per-abi APK holds one ABI; a fat one holds several. Either way,
    # the engine marks the ones that matter.
    engine_abis = sorted(abi for abi, libs in found.items() if ENGINE in libs)
    if not engine_abis:
        return [f'no {ENGINE} in any ABI — this is not a Flutter APK']

    problems = []
    for abi in engine_abis:
        for lib in REQUIRED:
            if lib not in found[abi]:
                problems.append(f'lib/{abi}/ has {ENGINE} but no {lib}')
    return problems


def main(argv):
    apks = argv[1:]

    if not apks:
        apks = [path for path in DEFAULT_APKS if os.path.exists(path)]
        if not apks:
            print('FAIL no release APK found in build/app/outputs/flutter-apk/')
            print('     Build one first, or pass a path.')
            return 1

    failed = False

    for apk in apks:
        problems = check(apk)
        if problems:
            failed = True
            print(f'FAIL {apk}')
            for problem in problems:
                print(f'       {problem}')
        else:
            print(f'ok   {apk}')

    if failed:
        print()
        print('The APK would install and then fail at the first database call.')
        print('Fix: rm -f .dart_tool/flutter_build/*/install_code_assets.stamp')
        print('     and build again. See CLAUDE.md section 3.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
