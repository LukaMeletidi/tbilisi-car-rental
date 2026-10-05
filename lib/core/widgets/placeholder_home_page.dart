import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// Temporary home screen. Replaced by the public catalog in Phase 1.
class PlaceholderHomePage extends ConsumerWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.placeholderMessage),
            const SizedBox(height: 24),
            Text(l10n.languageLabel),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: [
                for (final option in AppLanguage.values)
                  ButtonSegment(value: option, label: Text(option.nativeName)),
              ],
              selected: {language},
              onSelectionChanged: (selection) => ref
                  .read(appLanguageProvider.notifier)
                  .setLanguage(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}
