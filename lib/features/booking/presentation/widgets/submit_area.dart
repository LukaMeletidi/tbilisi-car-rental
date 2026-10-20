import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/core/widgets/privacy_link.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The key of the consent line under Send, for tests.
const privacyConsentKey = ValueKey('privacy-consent');

/// The end of the booking form, on the purple page: a hint to check the
/// fields, the message of a failed sending, the Send button, and under it
/// the consent line with the link to the Privacy Policy.
class SubmitArea extends StatelessWidget {
  const SubmitArea({
    super.key,
    required this.showCheckFields,
    required this.failureText,
    required this.sending,
    required this.onSend,
  });

  /// True after a Send that found errors in the form.
  final bool showCheckFields;

  /// Why the last sending failed, or null.
  final String? failureText;

  /// True while the request is on its way: the button is disabled and shows
  /// a spinner.
  final bool sending;

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failureText = this.failureText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCheckFields) ...[
          Text(
            l10n.bookingCheckFields,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        if (failureText != null) ...[
          AppCard(child: _FailureMessage(text: failureText)),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: sending ? null : onSend,
          child: sending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Flexible(child: Text(l10n.bookingSending)),
                  ],
                )
              : Text(l10n.bookingSubmit),
        ),
        // The consent line and the Privacy Policy (step 7.4). The link is
        // off while the request is on its way.
        const SizedBox(height: 12),
        Text(
          l10n.privacyConsent,
          key: privacyConsentKey,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Center(child: PrivacyLink(enabled: !sending)),
      ],
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: error),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
