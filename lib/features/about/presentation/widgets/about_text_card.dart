import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The white card with the "About us" paragraph. Static: it shows at once,
/// whatever the company data does.
class AboutTextCard extends StatelessWidget {
  const AboutTextCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(child: _Text());
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one.
class _Text extends StatelessWidget {
  const _Text();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).aboutText,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
