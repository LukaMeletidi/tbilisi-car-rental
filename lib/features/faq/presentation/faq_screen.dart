import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/section_title.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_entries.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/widgets/faq_item.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_tab_app_bar.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The content of the FAQ page is never wider than this; on a wide screen
/// it stands in the middle (as Home).
const faqMaxWidth = 720.0;

/// The FAQ tab of the public app (step 6b.7): the heading and the ten
/// questions; a tap on a question opens its answer. All texts are in the
/// ARB files; nothing is read from Firestore.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = faqEntries(l10n);

    return Scaffold(
      appBar: const PublicTabAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: faqMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(l10n.faqPageHeading),
                    for (final (index, entry) in entries.indexed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: FaqItem(
                          key: faqItemKey(index + 1),
                          entry: entry,
                        ),
                      ),
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
