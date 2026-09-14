import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:cal_tracker/features/design_gallery/design_gallery_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:cal_tracker/theme/tokens.dart';
import 'package:cal_tracker/widgets/sealed_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.build(), home: Scaffold(body: child));

void main() {
  group('SealedNode', () {
    testWidgets('shows the formatted number when revealed', (tester) async {
      await tester.pumpWidget(
        _host(
          const SealedNode(
            label: 'Energy balance',
            value: Revealed<num>(-2340),
          ),
        ),
      );

      expect(find.text('-2340'), findsOneWidget);
    });

    testWidgets('shows no digit anywhere in the tree when sealed',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SealedNode(
            label: 'Energy balance',
            value: Sealed<num>(),
            lore: 'Ask again when the week is done.',
          ),
        ),
      );

      // The label and the flavour line survive the seal.
      expect(find.text('ENERGY BALANCE'), findsOneWidget);
      expect(find.text('Ask again when the week is done.'), findsOneWidget);

      // This is the assertion that actually matters: a sealed node must not
      // render a single digit, whatever the layout around it looks like.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(
        RegExp(r'\d').hasMatch(texts),
        isFalse,
        reason: 'a sealed node rendered a digit: $texts',
      );
    });

    testWidgets('keeps the same height sealed or revealed', (tester) async {
      Future<double> heightOf(SealedValue<num> value) async {
        await tester.pumpWidget(
          _host(
            Center(
              child: SizedBox(
                width: 200,
                child: SealedNode(label: 'Energy balance', value: value),
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(SealedNode)).height;
      }

      // Unsealing must not make the panel jump on reveal day.
      expect(await heightOf(const Sealed<num>()),
          await heightOf(const Revealed<num>(-2340)));
    });
  });

  group('design gallery', () {
    testWidgets('renders every primitive without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Design'), findsOneWidget);
    });

    testWidgets('unsealing swaps the sealed nodes for real numbers',
        (tester) async {
      // Tall viewport so the lazy ListView builds the sealed section without
      // needing to drag past the typography panel.
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask again when the week is done.'), findsOneWidget);
      expect(find.text('-2340'), findsNothing);
      expect(find.text('-0.4 kg'), findsNothing);

      await tester.tap(find.text('UNSEAL'));
      await tester.pumpAndSettle();

      expect(find.text('Ask again when the week is done.'), findsNothing);
      expect(find.text('-2340'), findsOneWidget);
      expect(find.text('-0.4 kg'), findsOneWidget);
    });
  });

  group('theme', () {
    test('uses the Witcher ground rather than a Material default', () {
      final theme = AppTheme.build();
      expect(theme.scaffoldBackgroundColor, Hue.voidBlack);
      expect(theme.colorScheme.primary, Hue.gold);
    });

    test('applies real font weights via the wght axis, not synthetic bold', () {
      // Both families are bundled variable fonts. Relying on fontWeight alone
      // would make Flutter fake the bold instead of using the real axis.
      final heading = AppTheme.build().textTheme.displayLarge!;
      expect(heading.fontFamily, 'Cinzel');
      expect(heading.fontVariations, isNotEmpty);
      expect(heading.fontVariations!.first.axis, 'wght');
    });
  });
}
