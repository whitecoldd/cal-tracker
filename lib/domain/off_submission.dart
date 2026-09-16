/// What it takes to hand a food the app could not find to Open Food Facts.
///
/// Pure Dart, so the URL and the transcript are testable without a device.
/// That matters because both are read by a human standing in a kitchen with a
/// packet, and a wrong figure in the transcript would be copied into a public
/// database where it outlives the mistake.
library;

import 'nutrition.dart';

/// Builds the hand-off for one product.
///
/// **Deliberately does not submit anything.** Open Food Facts has no scoped
/// API token: its write endpoint takes a username and a password, sent on
/// every call, so contributing from inside the app would mean holding the
/// user's whole account credential on the device. The data is worth
/// contributing; the password is not worth holding. So the app opens the
/// ledger's own form and hands over a transcript to paste, and the account
/// stays where it belongs.
abstract final class OffSubmission {
  /// Salt to sodium, as the food industry and Open Food Facts both use it.
  /// The same constant `OffMapper` divides by on the way in.
  static const _saltToSodium = 2.5;

  /// Where Open Food Facts takes a new product.
  ///
  /// The `type=add` form keyed by barcode, which is the page the ledger's own
  /// apps land on. Prefilling more than the code is not possible — the form
  /// takes a session, not query parameters — which is why the transcript
  /// exists.
  static Uri addProductUrl(String barcode) => Uri.parse(
        'https://world.openfoodfacts.org/cgi/product.pl'
        '?type=add&code=${Uri.encodeQueryComponent(barcode.trim())}',
      );

  /// The panel as plain text, for pasting into that form.
  ///
  /// Laid out the way a European pack prints it — energy, fat, saturates,
  /// carbohydrate, sugars, fibre, protein, salt — rather than in the order the
  /// `foods` table happens to hold them. The person pasting is reading a
  /// packet, and matching its order is what lets the two be checked against
  /// each other line by line.
  ///
  /// Salt is given as well as sodium because the Open Food Facts form asks for
  /// salt and every pack here states salt, while the app stores sodium. Doing
  /// that conversion here rather than in someone's head is the difference
  /// between a contribution and a wrong one.
  static String transcript({
    required String name,
    required String barcode,
    required FoodPanel panel,
    String? brand,
  }) {
    final trimmedBrand = brand?.trim();

    final lines = <String>[
      name.trim(),
      if (trimmedBrand != null && trimmedBrand.isNotEmpty)
        'Brand: $trimmedBrand',
      'Barcode: ${barcode.trim()}',
      '',
      'Per 100 g / 100 ml:',
      'Energy: ${_g(panel.kcal)} kcal',
      'Fat: ${_g(panel.fatG)} g',
      '  of which saturates: ${_g(panel.satFatG)} g',
      'Carbohydrate: ${_g(panel.carbsG)} g',
      '  of which sugars: ${_g(panel.sugarG)} g',
      'Fibre: ${_g(panel.fibreG)} g',
      'Protein: ${_g(panel.proteinG)} g',
      // Two decimals, unlike everything above it. Salt is stated on packs at
      // figures like 0.05 g and 0.95 g, where one decimal is the difference
      // between a right answer and a doubled or halved one — and this line is
      // going into a public record.
      'Salt: ${_g(panel.sodiumMg * _saltToSodium / 1000, 2)} g',
      '  (sodium: ${_g(panel.sodiumMg)} mg)',
    ];

    return lines.join('\n');
  }

  /// A figure as a packet prints it: one decimal at most, none on a whole
  /// number. A transcript that disagrees with the pack in small ways invites
  /// the person copying it to distrust the parts that are right.
  static String _g(double value, [int decimals = 1]) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(decimals);
}
