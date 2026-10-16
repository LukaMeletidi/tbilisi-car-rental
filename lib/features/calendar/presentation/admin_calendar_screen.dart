import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';

/// The Calendar section of the admin area (step 5.5a): for now only the
/// page, with the time zone and an honest line that the calendar is not
/// ready; the grid of confirmed bookings comes in step 5.5b. It reads
/// nothing. The router shows it only to an admin.
class AdminCalendarScreen extends StatelessWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
        actions: const [AdminSignOutButton()],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(adminCalendarTitle, style: textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
                const SizedBox(height: 16),
                const Text(adminCalendarNotReady),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
