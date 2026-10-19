import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';

/// The key of the Extras & Prices entry, for tests.
const adminSettingsExtrasKey = ValueKey('admin-settings-extras');

/// The key of the Company Info entry, for tests.
const adminSettingsCompanyKey = ValueKey('admin-settings-company');

/// The Settings section of the admin area: an entry for each of its two
/// pages. It reads nothing and writes nothing. The router shows it only to
/// an admin.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
        actions: const [AdminSignOutButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              adminSettingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _Entry(
              key: adminSettingsExtrasKey,
              icon: Icons.sell_outlined,
              title: adminSettingsExtrasTitle,
              description: adminSettingsExtrasDescription,
              onTap: () => context.go(AppRoutes.adminSettingsExtras),
            ),
            _Entry(
              key: adminSettingsCompanyKey,
              icon: Icons.business_outlined,
              title: adminSettingsCompanyTitle,
              description: adminSettingsCompanyDescription,
              onTap: () => context.go(AppRoutes.adminSettingsCompany),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable white card: an icon, a title, one line, and a chevron.
class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: _EntryContent(icon: icon, title: title, description: description),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one. (Read outside the card, the text styles would carry the white text
/// of the purple page.)
class _EntryContent extends StatelessWidget {
  const _EntryContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(description, style: textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}
