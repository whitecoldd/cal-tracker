import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/ai/ai_key_store.dart';
import '../../data/ai/image_prep.dart';
import '../../data/ai/meal_resolver.dart';
import '../../data/ai/openrouter_client.dart';
import '../../data/daos/ai_calls_dao.dart';
import '../../data/meal_photo_store.dart';
import '../../providers/app_providers.dart';

/// Where the OpenRouter key lives. Overridden in tests with an in-memory store.
final aiKeyStoreProvider = Provider<AiKeyStore>((ref) => SecureAiKeyStore());

final openRouterClientProvider = Provider<OpenRouterClient>(
  (ref) => OpenRouterClient(
    keys: ref.watch(aiKeyStoreProvider),
    calls: ref.watch(databaseProvider).aiCallsDao,
  ),
);

/// Where a photographed meal's picture is kept.
///
/// Overridden in tests, which have no `path_provider`.
final mealPhotoStoreProvider = Provider<MealPhotoStore>(
  (ref) => MealPhotoStore(),
);

/// The camera and gallery. Overridden in tests, which have neither.
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

/// Takes a photograph, or picks one, and returns its bytes.
///
/// A function rather than the picker itself, for the same reason
/// `barcodeScannerProvider` is one: [ImagePicker] reaches a platform channel
/// that does not exist in a widget test, so every screen built on it was
/// testable only down to the point where it asks for a picture — which is one
/// line before everything worth testing. Injecting the whole step means a test
/// can hand a screen a photograph.
///
/// [quality] is the first-pass compression the camera layer applies, before
/// [ImagePrep] does the real work. A meal is read for what is on a plate and
/// can afford 85; a nutrition table is read for small print, where JPEG
/// artefacts land hardest on the thin strokes that separate a 3 from an 8.
final photoPickerProvider =
    Provider<Future<Uint8List?> Function(ImageSource, {int quality})>((ref) {
  final picker = ref.watch(imagePickerProvider);

  return (source, {int quality = 85}) async {
    // The camera permission is requested by image_picker itself — there is no
    // `permission_handler` in this project (CLAUDE.md §3).
    final file = await picker.pickImage(
      source: source,
      // Cheaper than handing twelve megapixels to a platform channel.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: quality,
    );
    if (file == null) return null;
    return file.readAsBytes();
  };
});

/// Shrinks a photograph and strips its metadata before it is sent.
final imagePrepProvider = Provider<ImagePrep>((ref) => const ImagePrep());

final mealResolverProvider = Provider<MealResolver>(
  (ref) => MealResolver(ref.watch(databaseProvider).foodsDao),
);

/// Bumped after every call so the budget re-reads.
///
/// The count lives in the database, but nothing there is a stream — and the
/// figure only changes when this app makes a call, so a counter is honest and
/// cheaper than watching a table.
final aiCallTickProvider = NotifierProvider<AiCallTick, int>(AiCallTick.new);

class AiCallTick extends Notifier<int> {
  @override
  int build() => 0;

  void spent() => state++;
}

/// Whether a key has been entered at all.
///
/// Drives whether the UI offers AI at all rather than offering it and failing:
/// the app is fully usable with no key, and a button that always errors is
/// worse than no button.
final aiAvailableProvider = FutureProvider<bool>((ref) async {
  ref.watch(aiKeyStoreProvider);
  ref.watch(aiCallTickProvider);
  return ref.watch(openRouterClientProvider).hasKey;
});

/// Today's usage against the cap, for Settings.
final aiBudgetProvider = FutureProvider<AiBudget>((ref) {
  ref.watch(aiCallTickProvider);
  return ref.watch(openRouterClientProvider).budget();
});
