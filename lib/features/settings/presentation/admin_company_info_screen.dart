import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/widgets/admin_settings_placeholder.dart';

/// The Company Info page of Settings. A placeholder until step 6.7; it
/// reads nothing and writes nothing.
class AdminCompanyInfoScreen extends StatelessWidget {
  const AdminCompanyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSettingsPlaceholder(
      title: adminSettingsCompanyTitle,
      description: adminSettingsCompanyDescription,
    );
  }
}
