import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';

void main() {
  group('resolveStartingLanguage', () {
    test('uses the device language when it is supported', () {
      expect(resolveStartingLanguage(['en']), AppLanguage.en);
      expect(resolveStartingLanguage(['ka']), AppLanguage.ka);
      expect(resolveStartingLanguage(['ru']), AppLanguage.ru);
    });

    test('the first supported language in the list wins', () {
      expect(resolveStartingLanguage(['de', 'ru']), AppLanguage.ru);
      expect(resolveStartingLanguage(['de', 'ka', 'ru']), AppLanguage.ka);
      expect(resolveStartingLanguage(['ru', 'en']), AppLanguage.ru);
    });

    test('falls back to English when nothing is supported', () {
      expect(resolveStartingLanguage(['de']), AppLanguage.en);
      expect(resolveStartingLanguage(['de', 'fr']), AppLanguage.en);
    });

    test('falls back to English for an empty list', () {
      expect(resolveStartingLanguage([]), AppLanguage.en);
    });

    test('ignores letter case', () {
      expect(resolveStartingLanguage(['RU']), AppLanguage.ru);
      expect(resolveStartingLanguage(['de', 'Ka']), AppLanguage.ka);
    });
  });
}
