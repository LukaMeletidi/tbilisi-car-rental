import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/links/url_opener.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The key of the row of [kind], for tests.
ValueKey<String> contactRowKey(ContactKind kind) =>
    ValueKey('contact-${kind.name}');

/// The key of the copy button of [kind], for tests.
ValueKey<String> contactCopyKey(ContactKind kind) =>
    ValueKey('contact-copy-${kind.name}');

/// The white card with the company name and one row per filled field. A
/// link is purple and underlined; a tap opens it. When it cannot be opened,
/// the text is copied and a message says so. Every value can be selected,
/// and the phone, the e-mail and the address have a copy button.
///
/// Company data is shown, never logged.
class ContactsCard extends StatelessWidget {
  const ContactsCard({super.key, required this.title, required this.rows});

  /// The company name; null when it is not set.
  final String? title;
  final List<ContactRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: _Content(title: title, rows: rows),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white
/// one.
class _Content extends StatelessWidget {
  const _Content({required this.title, required this.rows});

  final String? title;
  final List<ContactRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final name?) ...[
          SelectableText(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (rows.isNotEmpty) const SizedBox(height: 8),
        ],
        for (final row in rows) _Row(key: contactRowKey(row.kind), row: row),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({super.key, required this.row});

  final ContactRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, label, value) = switch (row.kind) {
      ContactKind.phone => (Icons.phone, l10n.aboutPhoneLabel, row.text),
      ContactKind.email => (
        Icons.email_outlined,
        l10n.aboutEmailLabel,
        row.text,
      ),
      ContactKind.address => (
        Icons.place_outlined,
        l10n.aboutAddressLabel,
        row.text,
      ),
      ContactKind.workingHours => (
        Icons.schedule,
        l10n.aboutWorkingHoursLabel,
        row.text,
      ),
      ContactKind.map => (Icons.map_outlined, null, l10n.aboutShowOnMap),
      ContactKind.facebook => (Icons.public, null, l10n.aboutFacebook),
      ContactKind.instagram => (
        Icons.photo_camera_outlined,
        null,
        l10n.aboutInstagram,
      ),
      ContactKind.whatsapp => (Icons.chat_outlined, null, l10n.aboutWhatsapp),
      ContactKind.telegram => (Icons.send_outlined, null, l10n.aboutTelegram),
    };
    final uri = row.uri;
    final valueStyle = uri == null
        ? theme.textTheme.bodyLarge
        : theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Semantics(
                  link: uri != null,
                  child: SelectableText(
                    value,
                    style: valueStyle,
                    onTap: uri == null ? null : () => _open(context, ref),
                  ),
                ),
              ],
            ),
          ),
          if (row.copyable)
            IconButton(
              key: contactCopyKey(row.kind),
              tooltip: l10n.aboutCopy,
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(context, row.text, l10n.aboutCopied),
            ),
        ],
      ),
    );
  }

  /// Opens the link; when nothing can open it, copies it and says so.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final failed = AppLocalizations.of(context).aboutOpenFailed;
    final opened = await ref.read(urlOpenerProvider)(row.uri!);
    if (opened || !context.mounted) return;
    await _copy(context, row.copyText, failed);
  }
}

Future<void> _copy(BuildContext context, String text, String message) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
