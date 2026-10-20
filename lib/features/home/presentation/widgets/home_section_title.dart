import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';

/// The white bold title of a Home block, on the purple page, centered over
/// the full width (also when a long title takes several lines).
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(homeGutter, 24, homeGutter, 12),
      child: Semantics(
        header: true,
        child: SizedBox(
          width: double.infinity,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
