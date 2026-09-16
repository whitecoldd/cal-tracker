import 'package:cal_tracker/theme/app_theme.dart';
import 'package:cal_tracker/widgets/runic_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int selected,
    required ValueChanged<int> onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: RunicTabs<int>(
            tabs: const [
              RunicTab(
                value: 0,
                label: 'The Tally',
                lore: 'The week in figures.',
              ),
              RunicTab(value: 1, label: 'The Tale', lore: 'The week in words.'),
            ],
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every segment, upper-cased', (tester) async {
    await pump(tester, selected: 0, onSelected: (_) {});

    expect(find.text('THE TALLY'), findsOneWidget);
    expect(find.text('THE TALE'), findsOneWidget);
  });

  testWidgets('shows the lore of the chosen segment only', (tester) async {
    await pump(tester, selected: 0, onSelected: (_) {});
    expect(find.text('The week in figures.'), findsOneWidget);
    expect(find.text('The week in words.'), findsNothing);

    await pump(tester, selected: 1, onSelected: (_) {});
    expect(find.text('The week in words.'), findsOneWidget);
  });

  testWidgets('reports the value that was tapped', (tester) async {
    int? chosen;
    await pump(tester, selected: 0, onSelected: (value) => chosen = value);

    await tester.tap(find.text('THE TALE'));
    await tester.pumpAndSettle();

    expect(chosen, 1);
  });

  testWidgets('does not select anything itself', (tester) async {
    // The caller owns the selection, exactly as ChoiceList works — so the mode
    // can live in a provider and a golden can be taken of either state.
    var calls = 0;
    await pump(tester, selected: 0, onSelected: (_) => calls++);

    await tester.tap(find.text('THE TALE'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    // Still showing the caller's value, unchanged.
    expect(find.text('The week in figures.'), findsOneWidget);
  });

  testWidgets('marks the chosen segment for a screen reader', (tester) async {
    await pump(tester, selected: 1, onSelected: (_) {});

    bool isMarkedSelected(String label) => tester
        .widgetList<Semantics>(
          find.ancestor(of: find.text(label), matching: find.byType(Semantics)),
        )
        .any((s) => s.properties.selected ?? false);

    expect(isMarkedSelected('THE TALE'), isTrue);
    expect(isMarkedSelected('THE TALLY'), isFalse);
  });

  testWidgets('leaves nothing animating', (tester) async {
    // Engraved, not animated. An implicit animation here would be one more
    // thing pumpAndSettle has to outlive on every screen that uses it.
    await pump(tester, selected: 0, onSelected: (_) {});

    expect(tester.hasRunningAnimations, isFalse);
  });
}
