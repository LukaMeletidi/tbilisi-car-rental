import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/widgets/privacy_link.dart';
import 'package:tbilisi_car_rental/core/widgets/section_title.dart';
import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/about_text_card.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/contacts_card.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/contacts_states.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_tab_app_bar.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The content of the Contact page is never wider than this; on a wide
/// screen it stands in the middle (as Home and FAQ).
const aboutMaxWidth = 720.0;

/// The Contact tab of the public app (step 6b.8): "About us" with the
/// static paragraph, then the contact details from settings/company, read
/// live. While they load the contacts card shows a spinner; when they
/// cannot be loaded, a message and "Try again". When nothing is filled in
/// (or the document does not exist), only the paragraph is shown.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider);
    final company = ref.watch(companyInfoProvider);

    // The card under "Contacts"; null when nothing is filled in.
    final Widget? contacts = company.when(
      // Show the spinner again after "Try again" is pressed.
      skipLoadingOnRefresh: false,
      loading: () => const ContactsLoadingCard(),
      error: (error, stackTrace) =>
          ContactsErrorCard(onRetry: () => ref.invalidate(companyInfoProvider)),
      data: (info) {
        final title = contactsTitle(info);
        final rows = contactRows(info, language);
        if (title == null && rows.isEmpty) return null;
        return ContactsCard(title: title, rows: rows);
      },
    );

    return Scaffold(
      appBar: const PublicTabAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: aboutMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(l10n.aboutTitle),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: AboutTextCard(),
                    ),
                    if (contacts != null) ...[
                      SectionTitle(l10n.aboutContactsTitle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: contacts,
                      ),
                    ],
                    // The Privacy Policy (step 7.4).
                    const SizedBox(height: 12),
                    const Center(child: PrivacyLink()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
