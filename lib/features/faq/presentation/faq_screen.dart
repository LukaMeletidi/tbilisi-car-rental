import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_placeholder.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The FAQ tab of the public app. A placeholder until step 6b.7.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPlaceholder(title: AppLocalizations.of(context).faqTitle);
  }
}
