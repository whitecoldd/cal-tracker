import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/off_submission.dart';
import 'package:flutter_test/flutter_test.dart';

/// Banzai salted almonds — the product that started this, and one Open Food
/// Facts genuinely does not hold.
const _almonds = FoodPanel(
  kcal: 607,
  proteinG: 21.2,
  carbsG: 6.9,
  sugarG: 4.4,
  fatG: 52.5,
  satFatG: 4.1,
  fibreG: 12.5,
  sodiumMg: 380,
);

void main() {
  group('where the hand-off sends you', () {
    test('is the ledger\'s own add-product form, keyed by the barcode', () {
      final url = OffSubmission.addProductUrl('4840811001867');

      expect(url.host, 'world.openfoodfacts.org');
      expect(url.path, '/cgi/product.pl');
      expect(url.queryParameters['type'], 'add');
      expect(url.queryParameters['code'], '4840811001867');
    });

    test('a barcode with stray whitespace still builds a usable URL', () {
      expect(
        OffSubmission.addProductUrl('  4840811001867 ')
            .queryParameters['code'],
        '4840811001867',
      );
    });
  });

  group('the transcript', () {
    test('states the panel in the order a pack prints it', () {
      // The person pasting is reading a packet. Matching its order is what
      // lets the two be checked against each other line by line.
      final text = OffSubmission.transcript(
        name: 'Salted almonds',
        brand: 'Banzai',
        barcode: '4840811001867',
        panel: _almonds,
      );

      expect(
        text,
        stringContainsInOrder([
          'Salted almonds',
          'Brand: Banzai',
          'Barcode: 4840811001867',
          'Energy: 607 kcal',
          'Fat: 52.5 g',
          'of which saturates: 4.1 g',
          'Carbohydrate: 6.9 g',
          'of which sugars: 4.4 g',
          'Fibre: 12.5 g',
          'Protein: 21.2 g',
        ]),
      );
    });

    test('converts sodium to the salt the form asks for', () {
      // The app stores sodium, every pack here states salt, and the Open Food
      // Facts form wants salt. Doing that in the transcript rather than in
      // someone's head is the difference between a contribution and a wrong
      // one. 380 mg sodium x 2.5 = 950 mg salt = 0.95 g — and at one decimal
      // that prints as 0.9, which is why salt alone gets two.
      final text = OffSubmission.transcript(
        name: 'Salted almonds',
        barcode: '4840811001867',
        panel: _almonds,
      );

      expect(text, contains('Salt: 0.95 g'));
      // Both, so a reader who has the sodium figure can check the conversion
      // rather than having to trust it.
      expect(text, contains('(sodium: 380 mg)'));
    });

    test('says nothing about a brand there is none of', () {
      // "Brand: null" pasted into a public record would be worse than silence.
      final text = OffSubmission.transcript(
        name: 'Borscht',
        barcode: '4840811001867',
        panel: _almonds,
      );

      expect(text, isNot(contains('Brand')));
      expect(text, isNot(contains('null')));

      final blank = OffSubmission.transcript(
        name: 'Borscht',
        brand: '   ',
        barcode: '4840811001867',
        panel: _almonds,
      );
      expect(blank, isNot(contains('Brand')));
    });

    test('keeps a small salt figure from rounding away', () {
      // 0.05 g of salt is an ordinary figure on a pack. At one decimal it
      // becomes 0.1 — double — which is not a rounding error worth making in
      // a public database.
      final text = OffSubmission.transcript(
        name: 'Oat flakes',
        barcode: '4840811001867',
        panel: const FoodPanel(kcal: 370, sodiumMg: 20),
      );

      expect(text, contains('Salt: 0.05 g'));
    });

    test('prints whole numbers whole', () {
      // A transcript that disagrees with the pack in small ways invites the
      // person copying it to distrust the parts that are right.
      final text = OffSubmission.transcript(
        name: 'Water',
        barcode: '4840811001867',
        panel: const FoodPanel(kcal: 0),
      );

      expect(text, contains('Energy: 0 kcal'));
      expect(text, isNot(contains('0.0')));
    });
  });
}
