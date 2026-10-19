import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// A page below Settings that is not built yet (step 6.5): the back arrow,
/// the title, one line about the page and "not ready yet". It reads
/// nothing, writes nothing, and has no field and no button.
class AdminSettingsPlaceholder extends StatelessWidget {
  const AdminSettingsPlaceholder({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        leading: BackButton(
          onPressed: () => context.go(AppRoutes.adminSettings),
        ),
        title: const AppBarLogo(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            AppCard(child: _NotReadyContent(description: description)),
          ],
        ),
      ),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one. (Read outside the card, the text styles would carry the white text
/// of the purple page.)
class _NotReadyContent extends StatelessWidget {
  const _NotReadyContent({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(adminSettingsNotReady, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
