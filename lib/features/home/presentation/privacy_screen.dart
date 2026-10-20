import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/core/widgets/section_title.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The content of the page is never wider than this (as Home, FAQ and
/// Contact).
const privacyMaxWidth = 720.0;

/// The key of the "Go to the Contact page" button, for tests.
const privacyGoToContactKey = ValueKey('privacy-go-to-contact');

/// The Privacy Policy (step 7.4): the title and six sections, each a white
/// card with its heading and text. All texts are in the ARB files; the page
/// never shows a phone or an e-mail address, it sends the visitor to the
/// Contact tab instead.
///
/// It lies above the shell (no bottom bar) and is opened with push, so the
/// back arrow returns to the booking form or the Contact tab. Opened
/// directly it has no back arrow, and Android's system Back goes to Home.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = [
      (l10n.privacy1Title, l10n.privacy1Text),
      (l10n.privacy2Title, l10n.privacy2Text),
      (l10n.privacy3Title, l10n.privacy3Text),
      (l10n.privacy4Title, l10n.privacy4Text),
      (l10n.privacy5Title, l10n.privacy5Text),
      (l10n.privacy6Title, l10n.privacy6Text),
    ];
    final canGoBack = Navigator.of(context).canPop();

    return PopScope(
      canPop: kIsWeb || canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          title: const AppBarLogo(),
          actions: const [LanguageMenuButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: privacyMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(l10n.privacyTitle),
                      for (final (title, text) in sections)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: AppCard(
                            child: _Section(title: title, text: text),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          key: privacyGoToContactKey,
                          onPressed: () => context.go(AppRoutes.about),
                          child: Text(l10n.privacyGoToContact),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One section, built inside the white card, so Theme.of(context) is the
/// dark-on-white one: the heading in its purple, the text dark.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
