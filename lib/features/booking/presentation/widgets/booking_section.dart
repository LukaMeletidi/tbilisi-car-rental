import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';

/// One block of the booking form: a white card with a small title.
class BookingSection extends StatelessWidget {
  const BookingSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: _SectionContent(title: title, child: child),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
