import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The language menu in the app bar: a globe icon that opens the three
/// languages, each written in its own language.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);

    return PopupMenuButton<AppLanguage>(
      icon: const Icon(Icons.language),
      tooltip: AppLocalizations.of(context).languageLabel,
      initialValue: current,
      onSelected: (language) =>
          ref.read(appLanguageProvider.notifier).setLanguage(language),
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          CheckedPopupMenuItem(
            value: language,
            checked: language == current,
            child: Text(language.nativeName),
          ),
      ],
    );
  }
}
