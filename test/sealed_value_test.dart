import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SealedValue', () {
    test('revealed carries its value, sealed carries nothing', () {
      const revealed = Revealed<int>(42);
      const sealed = Sealed<int>();

      expect(revealed.isRevealed, isTrue);
      expect(revealed.valueOrNull, 42);
      expect(sealed.isRevealed, isFalse);
      expect(sealed.valueOrNull, isNull);
    });

    test('map transforms a revealed value and leaves a sealed one sealed', () {
      expect(const Revealed<int>(3).map((v) => v * 2), const Revealed<int>(6));
      expect(const Sealed<int>().map((v) => v * 2), const Sealed<int>());
    });

    test('equality is by value, so providers can dedupe rebuilds', () {
      expect(const Revealed<int>(1), const Revealed<int>(1));
      expect(const Revealed<int>(1), isNot(const Revealed<int>(2)));
      expect(const Sealed<int>(), const Sealed<int>());
      expect(const Sealed<int>(), isNot(const Revealed<int>(1)));
    });

    test('sealed values of different types hash differently', () {
      // Comparing them is a static error, so the guarantee we can assert at
      // runtime is that they do not collide in a map or a provider cache.
      expect(const Sealed<int>().hashCode, isNot(const Sealed<String>().hashCode));
    });

    test('a switch over the type is exhaustive with two arms', () {
      // The analyzer enforces this (non_exhaustive_switch_expression is an
      // error), which is what stops a verdict leaking through a new branch.
      String render(SealedValue<num> v) => switch (v) {
            Revealed(value: final n) => n.toString(),
            Sealed() => '???',
          };

      expect(render(const Revealed<num>(7)), '7');
      expect(render(const Sealed<num>()), '???');
    });
  });
}
