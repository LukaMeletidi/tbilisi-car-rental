import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

// Digits, "+", and the signs people type inside a phone number. Everything
// else cannot be typed; the form removes the signs before storing.
final _phoneCharacters = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9+\s\-().]'),
);

/// The customer's name, phone (with the WhatsApp and Telegram checkboxes)
/// and e-mail. The controllers and focus nodes belong to the form.
class ContactFields extends StatelessWidget {
  const ContactFields({
    super.key,
    required this.enabled,
    required this.nameKey,
    required this.nameController,
    required this.nameFocusNode,
    required this.nameError,
    required this.onNameChanged,
    required this.phoneKey,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.phoneError,
    required this.onPhoneChanged,
    required this.whatsapp,
    required this.onWhatsappChanged,
    required this.telegram,
    required this.onTelegramChanged,
    required this.emailKey,
    required this.emailController,
    required this.emailFocusNode,
    required this.emailError,
    required this.onEmailChanged,
  });

  /// False while the request is being sent.
  final bool enabled;

  final Key nameKey;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final String? nameError;
  final ValueChanged<String> onNameChanged;

  final Key phoneKey;
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final String? phoneError;
  final ValueChanged<String> onPhoneChanged;

  final bool whatsapp;
  final ValueChanged<bool> onWhatsappChanged;
  final bool telegram;
  final ValueChanged<bool> onTelegramChanged;

  final Key emailKey;
  final TextEditingController emailController;
  final FocusNode emailFocusNode;
  final String? emailError;
  final ValueChanged<String> onEmailChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: nameKey,
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: enabled,
          onChanged: onNameChanged,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: l10n.bookingFullName,
            helperText: l10n.bookingFullNameHelper,
            errorText: nameError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: phoneKey,
          controller: phoneController,
          focusNode: phoneFocusNode,
          enabled: enabled,
          onChanged: onPhoneChanged,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [_phoneCharacters],
          decoration: InputDecoration(
            labelText: l10n.bookingPhone,
            hintText: bookingPhoneExample,
            errorText: phoneError,
          ),
        ),
        CheckboxListTile(
          value: whatsapp,
          onChanged: enabled ? (value) => onWhatsappChanged(value!) : null,
          title: Text(l10n.bookingWhatsapp),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          value: telegram,
          onChanged: enabled ? (value) => onTelegramChanged(value!) : null,
          title: Text(l10n.bookingTelegram),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 4),
        TextField(
          key: emailKey,
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: enabled,
          onChanged: onEmailChanged,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: l10n.bookingEmail,
            errorText: emailError,
          ),
        ),
      ],
    );
  }
}
