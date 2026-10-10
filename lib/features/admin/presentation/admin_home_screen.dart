import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The first page of the admin area. For now a placeholder: it says that
/// an administrator is signed in and offers Sign out. It reads no data. The
/// bookings list replaces it in step 3.6.
///
/// The router shows this page only to an account with the admin claim.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        title: const AppBarLogo(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: adminLoginMaxWidth),
              child: const AppCard(child: _AdminHomeContent()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _AdminHomeContent extends ConsumerWidget {
  const _AdminHomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(adminHomeTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(adminHomeSignedIn),
        const SizedBox(height: 4),
        const Text(adminHomeComingNext),
        const SizedBox(height: 16),
        FilledButton(
          // The session becomes "signed out" and the router shows the login
          // page.
          onPressed: () => ref.read(adminSignInProvider.notifier).signOut(),
          child: const Text(adminSignOutButton),
        ),
      ],
    );
  }
}
