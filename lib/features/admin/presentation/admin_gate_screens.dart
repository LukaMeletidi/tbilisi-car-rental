import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';

/// Shown while the app does not know yet who is signed in: only a spinner.
/// The router moves on as soon as Firebase has answered.
class AdminCheckingScreen extends StatelessWidget {
  const AdminCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
      ),
      body: const SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

/// Shown to a signed-in account that has no admin claim. No admin data is
/// asked for here; the Firestore rules would refuse it anyway.
class AdminNoAccessScreen extends ConsumerWidget {
  const AdminNoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
      ),
      body: SafeArea(
        child: CatalogMessage(
          icon: Icons.lock_outline,
          text: adminNoAccessText,
          action: FilledButton(
            // The session becomes "signed out" and the router shows the
            // login page.
            onPressed: () => ref.read(adminSignInProvider.notifier).signOut(),
            child: const Text(adminSignOutButton),
          ),
        ),
      ),
    );
  }
}
