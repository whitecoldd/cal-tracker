import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_service.dart';
import '../../data/backup/snapshot.dart';
import '../../data/backup/storage_access.dart';
import '../../providers/app_providers.dart';

/// All-files access, over the platform channel. Overridden in tests.
final storageAccessProvider =
    Provider<StorageAccess>((ref) => const PlatformStorageAccess());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    db: ref.watch(databaseProvider),
    access: ref.watch(storageAccessProvider),
  ),
);

/// Bumped after a write, a restore, or a return from the settings screen.
final backupTickProvider =
    NotifierProvider<BackupTick, int>(BackupTick.new);

class BackupTick extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

/// Whether the folder can be written to at all.
final storageGrantedProvider = FutureProvider<bool>((ref) {
  ref.watch(backupTickProvider);
  return ref.watch(storageAccessProvider).hasAccess();
});

/// The backup sitting in the folder, if there is one.
final existingBackupProvider = FutureProvider<BackupSnapshot?>((ref) async {
  ref.watch(backupTickProvider);
  if (!await ref.watch(storageGrantedProvider.future)) return null;
  return ref.watch(backupServiceProvider).findExisting();
});

/// Whether this install has no life of its own yet.
///
/// Drives the offer to restore on first launch. An app that already has a
/// profile must never be quietly overwritten by a folder someone left behind.
final isFreshInstallProvider = FutureProvider<bool>(
  (ref) => ref.watch(backupServiceProvider).isFresh,
);

/// Whether to offer a restore before the user starts typing a new profile.
///
/// Both conditions: nothing here, and something there.
final offerRestoreProvider = FutureProvider<BackupSnapshot?>((ref) async {
  if (!await ref.watch(isFreshInstallProvider.future)) return null;
  return ref.watch(existingBackupProvider.future);
});
