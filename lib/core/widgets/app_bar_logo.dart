import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const appBarLogoAsset = 'assets/images/app_bar_logo.png';

/// Height of the logo in the app bar, in logical pixels.
const appBarLogoHeight = 48.0;

/// Height of an app bar that shows the logo.
const appBarLogoToolbarHeight = 64.0;

/// The company logo for the app bar. Screen readers read the app name.
/// If the image cannot be loaded, the app name is shown as text.
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key, this.height = appBarLogoHeight});

  final double height;

  @override
  Widget build(BuildContext context) {
    final appTitle = AppLocalizations.of(context).appTitle;

    return Image.asset(
      appBarLogoAsset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: appTitle,
      errorBuilder: (context, error, stackTrace) => Text(appTitle),
    );
  }
}
