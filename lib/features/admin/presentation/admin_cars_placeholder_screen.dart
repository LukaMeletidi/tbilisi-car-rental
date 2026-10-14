import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';

/// The Cars section until the fleet list exists (step 4.4b).
class AdminCarsPlaceholderScreen extends StatelessWidget {
  const AdminCarsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
        actions: const [AdminSignOutButton()],
      ),
      body: const SafeArea(
        child: CatalogMessage(
          icon: Icons.directions_car,
          text: adminCarsComingSoon,
        ),
      ),
    );
  }
}
