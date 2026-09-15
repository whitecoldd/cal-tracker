import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/ai/ai_key_store.dart';
import '../../data/ai/image_prep.dart';
import '../../data/ai/meal_resolver.dart';
import '../../data/ai/openrouter_client.dart';
import '../../data/daos/ai_calls_dao.dart';
import '../../providers/app_providers.dart';

/// Where the OpenRouter key lives. Overridden in tests with an in-memory store.
final aiKeyStoreProvider = Provider<AiKeyStore>((ref) => SecureAiKeyStore());

final openRouterClientProvider = Provider<OpenRouterClient>(
  (ref) => OpenRouterClient(
    keys: ref.watch(aiKeyStoreProvider),
    calls: ref.watch(databaseProvider).aiCallsDao,
  ),
);

/// The camera and gallery. Overridden in tests, which have neither.
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

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
