import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_placeholder.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The Home tab of the public app. A placeholder until step 6b.6.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPlaceholder(title: AppLocalizations.of(context).appTitle);
  }
}
