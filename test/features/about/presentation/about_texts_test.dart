import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import 'about_harness.dart';

/// The 15 texts of the Contact tab in one language, by name.
Map<String, String> aboutTextsOf(AppLocalizations l) => {
  'aboutText': l.aboutText,
  'aboutContactsTitle': l.aboutContactsTitle,
  'aboutPhoneLabel': l.aboutPhoneLabel,
  'aboutEmailLabel': l.aboutEmailLabel,
  'aboutAddressLabel': l.aboutAddressLabel,
  'aboutWorkingHoursLabel': l.aboutWorkingHoursLabel,
  'aboutShowOnMap': l.aboutShowOnMap,
  'aboutCopy': l.aboutCopy,
  'aboutCopied': l.aboutCopied,
  'aboutOpenFailed': l.aboutOpenFailed,
  'aboutContactsError': l.aboutContactsError,
  'aboutFacebook': l.aboutFacebook,
  'aboutInstagram': l.aboutInstagram,
  'aboutWhatsapp': l.aboutWhatsapp,
  'aboutTelegram': l.aboutTelegram,
};

/// The brand names: the same in every language.
const brands = [
  'aboutFacebook',
  'aboutInstagram',
  'aboutWhatsapp',
  'aboutTelegram',
];

void main() {
  test('15 texts, filled in ka, ru and en, without outer spaces', () {
    for (final language in ['ka', 'ru', 'en']) {
      final texts = aboutTextsOf(aboutTexts(language));
      expect(texts, hasLength(15));
      texts.forEach((name, text) {
        expect(text, isNotEmpty, reason: '$language $name');
        expect(text.trim(), text, reason: '$language $name');
      });
    }
  });

  test('translated texts differ; the brand names are the same', () {
    final ka = aboutTextsOf(aboutTexts('ka'));
    final ru = aboutTextsOf(aboutTexts('ru'));
    final en = aboutTextsOf(aboutTexts('en'));
    for (final name in en.keys) {
      final values = {ka[name], ru[name], en[name]};
      expect(values, hasLength(brands.contains(name) ? 1 : 3), reason: name);
    }
  });

  test('the reused keys are unchanged', () {
    final en = aboutTexts('en');
    expect(en.aboutTitle, 'About us');
    expect(en.tryAgain, 'Try again');
  });
}
