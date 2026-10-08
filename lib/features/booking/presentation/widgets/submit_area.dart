import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The end of the booking form, on the purple page: a hint to check the
/// fields, the message of a failed sending, and the Send button.
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
