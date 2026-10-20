import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_entries.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/widgets/faq_item.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The FAQ page alone, at [size] and [textScale], in [language].
Future<void> pumpFaq(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  double textScale = 1,
  String language = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const FaqScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The questions and answers of [language].
List<FaqEntry> faqOf(String language) =>
    faqEntries(lookupAppLocalizations(Locale(language)));

/// Scrolls question [number] (from 1) into view and taps it.
Future<void> tapQuestion(WidgetTester tester, int number, String text) async {
  final question = find.descendant(
    of: find.byKey(faqItemKey(number)),
    matching: find.text(text),
  );
  await tester.ensureVisible(question);
  await tester.pumpAndSettle();
  await tester.tap(question);
  await tester.pumpAndSettle();
}
