import 'package:flutter/material.dart';

/// The top of a partially loaded feed: a spinner while an older page is in
/// flight, otherwise an empty slot of the same height. A sliver box child is
/// built even far off screen, so an always-on spinner would tick forever.
class OlderCardsLoader extends StatelessWidget {
  const OlderCardsLoader({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: loading ? const CircularProgressIndicator(strokeWidth: 2) : null,
      ),
    ),
  );
}
