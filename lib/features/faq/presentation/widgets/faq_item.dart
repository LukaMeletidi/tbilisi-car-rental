import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_entries.dart';

/// The key of the card of question [number] (from 1), for tests.
ValueKey<String> faqItemKey(int number) => ValueKey('faq-item-$number');

/// One question on a white card; a tap opens or closes its answer. Several
/// answers may be open at once. Screen readers hear "expanded" or
/// "collapsed".
class FaqItem extends StatelessWidget {
  const FaqItem({super.key, required this.entry});

  final FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: _Tile(entry: entry),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one: the question in its purple, the answer and the arrow dark.
class _Tile extends StatelessWidget {
  const _Tile({required this.entry});

  final FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      // No divider lines: the card is the frame.
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedAlignment: Alignment.centerLeft,
      iconColor: theme.colorScheme.onSurface,
      collapsedIconColor: theme.colorScheme.onSurface,
      title: Text(
        entry.question,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [Text(entry.answer, style: theme.textTheme.bodyMedium)],
    );
  }
}
