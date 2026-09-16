import 'dart:async';
import 'dart:io';

import 'package:openfoodfacts/openfoodfacts.dart' as off;

import 'off_mapper.dart';
import 'remote_food.dart';

/// Step three of the food resolution order in CLAUDE.md §4: free, keyless, and
/// tried only after the local library and the seed table have both missed.
///
/// An interface rather than a concrete class so tests can substitute a fake —
/// the alternative is a test suite that needs the network, which would make the
/// offline behaviour the one thing that is never tested.
abstract interface class FoodRemote {
  /// What upstream holds for this barcode.
  ///
  /// Throws [RemoteUnavailable] if upstream could not be reached; every other
  /// outcome, including "never heard of it", is a [ProductLookup].
  Future<ProductLookup> byBarcode(String barcode);

  /// Free-text search.
  Future<List<RemoteFood>> search(String query, {int limit});
}

/// Upstream could not be reached, or did not answer in time.
///
/// A distinct type because this is **not** an error the user needs to act on:
/// the app is fully usable offline, so the search sheet reports it as a quiet
/// footnote under the local results rather than as a failure.
class RemoteUnavailable implements Exception {
  const RemoteUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'RemoteUnavailable: $reason';
}

/// Open Food Facts, over its public API.
class OffFoodRemote implements FoodRemote {
  OffFoodRemote({Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 8);

  /// Kept short on purpose. A slow lookup is indistinguishable from a broken
  /// one to someone standing in a kitchen, and the local results are already
  /// on screen by the time this is running.
  final Duration _timeout;

  static var _configured = false;

  /// Open Food Facts asks every client to identify itself, and throttles ones
  /// that do not.
  static void configure() {
    if (_configured) return;
    off.OpenFoodAPIConfiguration.userAgent = off.UserAgent(
      name: 'WitcherDiet',
      version: '1.0.0',
      comment: 'Personal offline calorie tracker',
    );
    off.OpenFoodAPIConfiguration.globalLanguages = <off.OpenFoodFactsLanguage>[
      off.OpenFoodFactsLanguage.ENGLISH,
    ];
    _configured = true;
  }

  static const _fields = <off.ProductField>[
    off.ProductField.BARCODE,
    off.ProductField.NAME,
    // Asking for the name in every language, and for the generic name, is what
    // makes a product named only in Romanian or French usable. Without these
    // two, `getBestProductName` has nothing to fall back to and the product is
    // rejected as nameless.
    off.ProductField.NAME_ALL_LANGUAGES,
    off.ProductField.GENERIC_NAME,
    off.ProductField.BRANDS,
    off.ProductField.NUTRIMENTS,
    off.ProductField.NOVA_GROUP,
    off.ProductField.ADDITIVES,
    off.ProductField.SERVING_SIZE,
    off.ProductField.SERVING_QUANTITY,
    off.ProductField.IMAGE_FRONT_SMALL_URL,
  ];

  @override
  Future<ProductLookup> byBarcode(String barcode) async {
    configure();

    final result = await _guard(
      () => off.OpenFoodAPIClient.getProductV3(
        off.ProductQueryConfiguration(
          barcode,
          version: off.ProductQueryVersion.v3,
          language: off.OpenFoodFactsLanguage.ENGLISH,
          fields: _fields,
        ),
      ),
    );

    final product = result.product;
    if (product == null) return const ProductUnknown();
    return OffMapper.fromProduct(product);
  }

  @override
  Future<List<RemoteFood>> search(String query, {int limit = 20}) async {
    configure();

    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final result = await _guard(
      () => off.OpenFoodAPIClient.searchProducts(
        null,
        off.ProductSearchQueryConfiguration(
          version: off.ProductQueryVersion.v3,
          language: off.OpenFoodFactsLanguage.ENGLISH,
          fields: _fields,
          parametersList: [
            off.SearchTerms(terms: [trimmed]),
            off.PageSize(size: limit),
          ],
        ),
      ),
    );

    return OffMapper.fromProducts(result.products);
  }

  /// Funnels every way the network can fail into [RemoteUnavailable].
  ///
  /// Without this the search sheet would have to know about socket errors,
  /// timeouts, HTTP throttling and malformed JSON separately, and the one it
  /// forgot would be the one that broke offline use.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      return Future<T>.error(const RemoteUnavailable('timed out'));
    } on SocketException {
      return Future<T>.error(const RemoteUnavailable('no connection'));
    } on off.TooManyRequestsException {
      return Future<T>.error(const RemoteUnavailable('throttled upstream'));
    } on FormatException {
      return Future<T>.error(const RemoteUnavailable('unreadable response'));
    } on Exception catch (e) {
      return Future<T>.error(RemoteUnavailable('$e'));
    } catch (e) {
      // Deliberately catching `Error` too, which is normally a bug worth
      // crashing on. Open Food Facts is crowd-sourced: a product with a string
      // where the schema says a number surfaces here as a `TypeError`, not an
      // `Exception`, and one of those escaping is a failure with no output at
      // all in a minified release build. Upstream data is not our invariant to
      // uphold, so it is reported as an unreachable upstream.
      return Future<T>.error(RemoteUnavailable('$e'));
    }
  }
}
