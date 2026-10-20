import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import 'home_harness.dart';

/// The 33 Home texts of one language, by name.
Map<String, String> homeTextsOf(AppLocalizations l) => {
  'homeHeroTitle': l.homeHeroTitle,
  'homeHeroSubtitle': l.homeHeroSubtitle,
  'homeTopCarsTitle': l.homeTopCarsTitle,
  'homeProcessTitle': l.homeProcessTitle,
  'homeProcess1Title': l.homeProcess1Title,
  'homeProcess1Text': l.homeProcess1Text,
  'homeProcess2Title': l.homeProcess2Title,
  'homeProcess2Text': l.homeProcess2Text,
  'homeProcess3Title': l.homeProcess3Title,
  'homeProcess3Text': l.homeProcess3Text,
  'homeProcess4Title': l.homeProcess4Title,
  'homeProcess4Text': l.homeProcess4Text,
  'homeBenefitsTitle': l.homeBenefitsTitle,
  'homeBenefit1Title': l.homeBenefit1Title,
  'homeBenefit1Text': l.homeBenefit1Text,
  'homeBenefit2Title': l.homeBenefit2Title,
  'homeBenefit2Text': l.homeBenefit2Text,
  'homeBenefit3Title': l.homeBenefit3Title,
  'homeBenefit3Text': l.homeBenefit3Text,
  'homeTermsTitle': l.homeTermsTitle,
  'homeTerms1Title': l.homeTerms1Title,
  'homeTerms1Text': l.homeTerms1Text,
  'homeTerms2Title': l.homeTerms2Title,
  'homeTerms2Text': l.homeTerms2Text,
  'homeTerms3Title': l.homeTerms3Title,
  'homeTerms3Text': l.homeTerms3Text,
  'homeTrafficTitle': l.homeTrafficTitle,
  'homeTraffic1Title': l.homeTraffic1Title,
  'homeTraffic1Text': l.homeTraffic1Text,
  'homeTraffic2Title': l.homeTraffic2Title,
  'homeTraffic2Text': l.homeTraffic2Text,
  'homeTraffic3Title': l.homeTraffic3Title,
  'homeTraffic3Text': l.homeTraffic3Text,
};

void main() {
  test('33 Home texts, filled in ka, ru and en, without outer spaces', () {
    for (final language in ['ka', 'ru', 'en']) {
      final texts = homeTextsOf(homeTexts(language));
      expect(texts, hasLength(33));
      texts.forEach((name, text) {
        expect(text, isNotEmpty, reason: '$language $name');
        expect(text.trim(), text, reason: '$language $name');
      });
    }
  });

  test('the three languages differ (no text left untranslated)', () {
    final ka = homeTextsOf(homeTexts('ka'));
    final ru = homeTextsOf(homeTexts('ru'));
    final en = homeTextsOf(homeTexts('en'));
    for (final name in en.keys) {
      expect({ka[name], ru[name], en[name]}, hasLength(3), reason: name);
    }
  });

  testWidgets('the three photos are bundled and are JPEGs', (tester) async {
    for (final image in [homeHeroImage, homeProcessImage, homeTrafficImage]) {
      final data = await rootBundle.load(image);
      final bytes = data.buffer.asUint8List();
      expect(bytes.length, greaterThan(50000), reason: image);
      expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: image);
    }
  });
}
