import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';

/// A white Home card with a bold title and a text below it. The title is
/// purple ([purpleTitle]) or dark, as in the traffic cards.
class HomeInfoCard extends StatelessWidget {
  const HomeInfoCard({
    super.key,
    required this.title,
    required this.text,
    this.purpleTitle = true,
  });

  final String title;
  final String text;
  final bool purpleTitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: _Content(title: title, text: text, purpleTitle: purpleTitle),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one: its primary is the app purple and its onSurface is dark.
class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.text,
    required this.purpleTitle,
  });

  final String title;
  final String text;
  final bool purpleTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: purpleTitle
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
