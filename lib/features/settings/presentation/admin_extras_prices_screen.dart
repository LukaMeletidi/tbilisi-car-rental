import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/widgets/admin_settings_placeholder.dart';

/// The Extras & Prices page of Settings. A placeholder until step 6.6; it
/// reads nothing and writes nothing.
class AdminExtrasPricesScreen extends StatelessWidget {
  const AdminExtrasPricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSettingsPlaceholder(
      title: adminSettingsExtrasTitle,
      description: adminSettingsExtrasDescription,
    );
  }
}
