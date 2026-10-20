import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import 'faq_harness.dart';

AppLocalizations texts(String language) =>
    lookupAppLocalizations(Locale(language));

/// The 21 FAQ texts of one language: the heading, then the questions and
/// the answers.
List<String> faqTextsOf(String language) => [
  texts(language).faqPageHeading,
  for (final entry in faqOf(language)) ...[entry.question, entry.answer],
];

void main() {
  test('21 FAQ texts, filled in ka, ru and en, without outer spaces', () {
    for (final language in ['ka', 'ru', 'en']) {
      final all = faqTextsOf(language);
      expect(all, hasLength(21));
      for (final (index, text) in all.indexed) {
        expect(text, isNotEmpty, reason: '$language $index');
        expect(text.trim(), text, reason: '$language $index');
      }
    }
  });

  test('the three languages differ (no text left untranslated)', () {
    final ka = faqTextsOf('ka');
    final ru = faqTextsOf('ru');
    final en = faqTextsOf('en');
    for (var i = 0; i < en.length; i++) {
      expect({ka[i], ru[i], en[i]}, hasLength(3), reason: '$i');
    }
  });
}
