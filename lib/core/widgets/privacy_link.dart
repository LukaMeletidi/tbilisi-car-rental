import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The key of the link, for tests.
const privacyLinkKey = ValueKey('privacy-link');

/// "Privacy Policy" as a text button on the purple page. It pushes the
/// policy, so Back returns here with everything as it was (the booking form
/// keeps its values). Disabled with [enabled] false.
class PrivacyLink extends StatelessWidget {
  const PrivacyLink({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: privacyLinkKey,
      onPressed: enabled ? () => context.push(AppRoutes.privacy) : null,
      child: Text(
        AppLocalizations.of(context).privacyTitle,
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }
}
