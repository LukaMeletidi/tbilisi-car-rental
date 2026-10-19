import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_tab_app_bar.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// A tab page whose content is not built yet (step 6b.2): the shared app
/// bar, the [title] on the purple page and a white card with "This page is
/// coming soon." It reads nothing.
class PublicPlaceholder extends StatelessWidget {
  const PublicPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PublicTabAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const AppCard(child: _ComingSoon()),
          ],
        ),
      ),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.schedule),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            AppLocalizations.of(context).pageComingSoon,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
