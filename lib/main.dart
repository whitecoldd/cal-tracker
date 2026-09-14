import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: WitchersDietApp()));
}

/// Root of the application.
///
/// The real shell (Journal / Alchemy / Path / Bestiary) arrives in later tasks;
/// T0 only proves the scaffold boots.
class WitchersDietApp extends StatelessWidget {
  const WitchersDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "The Witcher's Diet",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'The Path begins.',
          style: TextStyle(fontFamily: 'Cinzel', fontSize: 22),
        ),
      ),
    );
  }
}
