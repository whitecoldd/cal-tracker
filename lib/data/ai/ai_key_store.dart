import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the OpenRouter key lives.
///
/// The Android keystore, never the repo and never a build-time define. A
/// `--dart-define` would bake the key into the APK, which is exactly what this
/// avoids — see CLAUDE.md §2. The key is typed into Settings by the user, and
/// the app is fully usable without one.
///
/// An interface so tests can substitute an in-memory store: a test that needed
/// the real keystore would need a device, and a test that needed a real key
/// would need the key in the repo.
abstract interface class AiKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> clear();

  /// Whether the user has made the one-time purchase that raises the daily cap
  /// from 50 to 1,000. Stored beside the key because it is a fact about the
  /// same account.
  Future<bool> hasPurchasedCredit();
  Future<void> setPurchasedCredit({required bool value});
}

class SecureAiKeyStore implements AiKeyStore {
  /// No options passed: `flutter_secure_storage` 11.x already defaults to
  /// AES-GCM with RSA key wrapping on Android, and the 10.x-era
  /// `encryptedSharedPreferences` flag no longer exists.
  SecureAiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyName = 'openrouter_api_key';
  static const _creditName = 'openrouter_has_credit';

  @override
  Future<String?> read() async {
    final value = await _storage.read(key: _keyName);
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> write(String key) => _storage.write(
        key: _keyName,
        value: key.trim(),
      );

  @override
  Future<void> clear() => _storage.delete(key: _keyName);

  @override
  Future<bool> hasPurchasedCredit() async =>
      await _storage.read(key: _creditName) == 'true';

  @override
  Future<void> setPurchasedCredit({required bool value}) =>
      _storage.write(key: _creditName, value: '$value');
}

/// An in-memory store, for tests and for a build with no keystore.
///
/// Holds the same contract as [SecureAiKeyStore], blank-is-absent included. A
/// fake that treats "   " as a key while the real one treats it as none would
/// let a test pass on behaviour the device does not have.
class InMemoryAiKeyStore implements AiKeyStore {
  InMemoryAiKeyStore({String? key, bool purchased = false})
      : _key = key?.trim(),
        _purchased = purchased;

  String? _key;
  bool _purchased;

  @override
  Future<String?> read() async {
    final value = _key;
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> write(String key) async => _key = key.trim();

  @override
  Future<void> clear() async => _key = null;

  @override
  Future<bool> hasPurchasedCredit() async => _purchased;

  @override
  Future<void> setPurchasedCredit({required bool value}) async =>
      _purchased = value;
}

/// Whether a string looks like an OpenRouter key.
///
/// A shape check only, so Settings can reject an obvious paste error without a
/// network round trip — which would cost a call against the budget.
bool looksLikeOpenRouterKey(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('sk-or-') && trimmed.length >= 20;
}
