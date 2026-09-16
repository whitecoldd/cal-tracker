import 'package:cal_tracker/domain/food_query.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the two searches that came back from use', () {
    // Both failed outright before this. The old query was a single LIKE over
    // the whole typed string, so a multi-word search matched only words that
    // were adjacent and in the order typed, and a leading digit was searched
    // for literally.

    test('"white monster" finds Monster Energy Ultra White', () {
      final query = parseFoodQuery('white monster');

      expect(query.terms, ['white', 'monster']);
      expect(matchTier('monster energy ultra white', query), 1);
    });

    test('"5 fried eggs" is five of them, and searches for fried egg', () {
      final query = parseFoodQuery('5 fried eggs');

      expect(query.quantity, 5);
      expect(query.terms, ['fried', 'egg']);
      // Upstream is shown words, never stems.
      expect(query.remoteText, 'fried eggs');
      expect(matchTier('egg whole', parseFoodQuery('eggs')), isNotNull);
    });
  });

  group('normaliseSearchText', () {
    test('lowercases, strips punctuation and collapses space', () {
      expect(normaliseSearchText('  Coca-Cola   ZERO! '), 'coca cola zero');
    });

    test('joins a brand onto the name', () {
      expect(normaliseSearchText('Chocolate bar', 'Milka'),
          'chocolate bar milka');
    });

    test('keeps digits, which are part of some names', () {
      expect(normaliseSearchText('Beer, 5%'), 'beer 5');
    });
  });

  group('stemWord', () {
    test('drops a plural s', () {
      expect(stemWord('eggs'), 'egg');
      expect(stemWord('oats'), 'oat');
    });

    test('drops es and ies', () {
      expect(stemWord('tomatoes'), 'tomato');
      expect(stemWord('berries'), 'berr');
    });

    test('leaves a double s alone', () {
      expect(stemWord('glass'), 'glass');
    });

    test('refuses to gut a short word', () {
      // Without the floors these become "i", "fr" and "ga", which match
      // almost everything.
      expect(stemWord('is'), 'is');
      expect(stemWord('gas'), 'gas');
    });

    test('a singular is left as it is', () {
      expect(stemWord('egg'), 'egg');
      expect(stemWord('bread'), 'bread');
    });

    test('truncating is what makes the stored key safe to leave alone', () {
      // The whole no-migration argument in one assertion: the stem of the
      // plural is a prefix of the singular, so containment finds both.
      expect('egg whole'.contains(stemWord('eggs')), isTrue);
      expect('scrambled eggs'.contains(stemWord('eggs')), isTrue);
      expect('scrambled eggs'.contains(stemWord('egg')), isTrue);
    });
  });

  group('a leading quantity', () {
    test('a bare number', () {
      final query = parseFoodQuery('3 bananas');
      expect(query.quantity, 3);
      expect(query.unit, isNull);
      expect(query.terms, ['banana']);
    });

    test('a number and a unit word, with the stopword dropped', () {
      final query = parseFoodQuery('2 slices of bread');
      expect(query.quantity, 2);
      expect(query.unit, PortionUnit.slice);
      expect(query.terms, ['bread']);
    });

    test('a unit glued to the number', () {
      final query = parseFoodQuery('500ml coke');
      expect(query.quantity, 500);
      expect(query.unit, PortionUnit.millilitres);
      expect(query.terms, ['coke']);
    });

    test('a number word', () {
      final query = parseFoodQuery('two eggs');
      expect(query.quantity, 2);
      expect(query.terms, ['egg']);
    });

    test('a dozen is twelve', () {
      // Number words earn their place: since every term must match, an
      // unrecognised leading "dozen" would block the query entirely and
      // return nothing, which is worse than what this replaces.
      final query = parseFoodQuery('a dozen eggs');
      expect(query.quantity, 12);
      expect(query.terms, ['egg']);
    });

    test('a decimal', () {
      final query = parseFoodQuery('1.5 cup rice');
      expect(query.quantity, 1.5);
      expect(query.unit, PortionUnit.cup);
      expect(query.terms, ['rice']);
    });

    test('a number alone is searched for, not stripped', () {
      // There would be nothing left to search for otherwise.
      final query = parseFoodQuery('500');
      expect(query.quantity, isNull);
      expect(query.terms, ['500']);
    });

    test('a number with only stopwords after it is searched for', () {
      final query = parseFoodQuery('5 of the');
      expect(query.quantity, isNull);
    });

    test('a number in the middle is left alone', () {
      // "Beer, 5%" is a real seed food, and the 5 is part of its name.
      final query = parseFoodQuery('beer 5');
      expect(query.quantity, isNull);
      expect(query.terms, contains('5'));
    });
  });

  group('stopwords', () {
    test('do not block a match', () {
      final query = parseFoodQuery('bowl of oats');
      expect(query.terms, ['bowl', 'oat']);
    });

    test('a query of nothing but stopwords is searched for literally', () {
      final query = parseFoodQuery('the');
      expect(query.isEmpty, isFalse);
      expect(query.terms, ['the']);
    });
  });

  group('matchTier', () {
    final query = parseFoodQuery('rice');

    test('an exact key is the best answer there is', () {
      expect(matchTier('rice', query), 0);
    });

    test('beginning a word ranks above appearing mid-word', () {
      expect(matchTier('brown rice', query), 1);
      // "Ricecakes" begins with the term, so it is a tier 1 answer too — a
      // prefix is what typing into a search box means.
      expect(matchTier('ricecakes', query), 1);
      // "Licorice" merely contains it.
      expect(matchTier('licorice', query), 2);
    });

    test('a missing term is no match at all', () {
      expect(matchTier('brown bread', query), isNull);
    });

    test('every term must be present, not just one', () {
      final two = parseFoodQuery('brown rice');
      expect(matchTier('brown rice', two), 0);
      expect(matchTier('white rice', two), isNull);
    });

    test('order does not matter', () {
      expect(
        matchTier('monster energy ultra white', parseFoodQuery('white monster')),
        matchTier('monster energy ultra white', parseFoodQuery('monster white')),
      );
    });

    test('an empty query answers nothing', () {
      expect(matchTier('rice', FoodQuery.empty), isNull);
      expect(matchTier('rice', parseFoodQuery('   ')), isNull);
    });
  });

  group('what goes upstream', () {
    test('is words, never stems', () {
      // A stem is not a word anybody wrote, and Open Food Facts searches text.
      expect(parseFoodQuery('fried eggs').remoteText, 'fried eggs');
      expect(parseFoodQuery('tomatoes').remoteText, 'tomatoes');
    });

    test('has the leading quantity removed', () {
      expect(parseFoodQuery('500ml coke').remoteText, 'coke');
      expect(parseFoodQuery('5 fried eggs').remoteText, 'fried eggs');
    });

    test('has stopwords removed', () {
      expect(parseFoodQuery('2 slices of bread').remoteText, 'bread');
    });
  });
}
