import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The special requests: a text of several lines. Near the limit a counter
/// appears ("430 / 500"); typing is never cut off, a text that is too long
/// shows an error instead.
class NotesField extends StatelessWidget {
  const NotesField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.errorText,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The number of characters that count: the text without the spaces at
  /// its ends, as the form checks it.
  final int length;

  final String? errorText;

  /// False while the request is being sent.
  final bool enabled;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      minLines: 3,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: l10n.bookingNotesHint,
        hintMaxLines: 3,
        errorText: errorText,
        errorMaxLines: 6,
        counterText: showsNotesCounter(length)
            ? notesCounterText(length)
            : null,
      ),
    );
  }
}
