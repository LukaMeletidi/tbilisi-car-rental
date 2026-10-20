import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The contacts card while the company data loads: a spinner.
class ContactsLoadingCard extends StatelessWidget {
  const ContactsLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// The contacts card when the company data cannot be loaded: the message
/// and "Try again".
class ContactsErrorCard extends StatelessWidget {
  const ContactsErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(child: _ErrorContent(onRetry: onRetry));
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_off),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.aboutContactsError,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      ],
    );
  }
}
