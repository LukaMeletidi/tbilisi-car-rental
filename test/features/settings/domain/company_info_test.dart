import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

String letters(int count) => 'a' * count;
String linkOfLength(int count) {
  const start = 'https://www.example.com/';
  return start + letters(count - start.length);
}

/// A settings/company with every field set. All values are made up.
Map<String, dynamic> fullDocument() => {
  'name': 'Example Car Rental',
  'phone': '+995555000000',
  'email': 'info@example.com',
  'address': {
    'ka': 'თბილისი, სანიმუშო ქუჩა 1',
    'ru': 'Тбилиси, Примерная улица 1',
    'en': 'Tbilisi, 1 Example Street',
  },
  'workingHours': {
    'ka': 'ყოველდღე 09:00–20:00',
    'ru': 'Ежедневно 09:00–20:00',
    'en': 'Every day 09:00–20:00',
  },
  'mapUrl': 'https://maps.example.com/tbilisi',
  'social': {
    'facebook': 'https://www.example.com/facebook',
    'instagram': 'https://www.example.com/instagram',
    'whatsapp': 'https://www.example.com/whatsapp',
    'telegram': 'https://www.example.com/telegram',
  },
};

/// The full document with one change.
Map<String, dynamic> changed(void Function(Map<String, dynamic> d) change) {
  final document = fullDocument();
  change(document);
  return document;
}

void expectInvalid(Map<String, dynamic> document) {
  expect(() => CompanyInfo.fromMap(document), throwsA(isA<FormatException>()));
}

void main() {
  group('fromMap', () {
    test('reads a document with every field', () {
      final company = CompanyInfo.fromMap(fullDocument());
      expect(company.name, 'Example Car Rental');
      expect(company.phone, '+995555000000');
      expect(company.email, 'info@example.com');
      expect(company.address!.en, 'Tbilisi, 1 Example Street');
      expect(company.workingHours!.ru, 'Ежедневно 09:00–20:00');
      expect(company.mapUrl, 'https://maps.example.com/tbilisi');
      expect(company.social, {
        CompanySocialLink.facebook: 'https://www.example.com/facebook',
        CompanySocialLink.instagram: 'https://www.example.com/instagram',
        CompanySocialLink.whatsapp: 'https://www.example.com/whatsapp',
        CompanySocialLink.telegram: 'https://www.example.com/telegram',
      });
      expect(company.isEmpty, false);
    });

    test('an empty document means nothing is filled in', () {
      final company = CompanyInfo.fromMap({});
      expect(company.isEmpty, true);
      expect(company, CompanyInfo.empty);
    });

    test('each field alone is valid', () {
      for (final field in companyFields) {
        final company = CompanyInfo.fromMap({field: fullDocument()[field]});
        expect(company.isEmpty, false, reason: field);
        expect(company.toMap().keys, [field], reason: field);
      }
    });

    test('an unknown field is refused', () {
      expectInvalid(changed((d) => d['vatNumber'] = '000000000'));
    });

    test('a field that is null is refused, one by one', () {
      for (final field in companyFields) {
        expectInvalid(changed((d) => d[field] = null));
      }
    });

    test('the name: limits, empty, spaces at the ends, a number', () {
      expect(CompanyInfo.fromMap({'name': letters(100)}).name, letters(100));
      expectInvalid({'name': letters(101)});
      expectInvalid({'name': ''});
      expectInvalid({'name': 'Example Car Rental '});
      expectInvalid({'name': ' Example Car Rental'});
      expectInvalid({'name': 5});
    });

    test('the phone must be in its stored form', () {
      expect(CompanyInfo.fromMap({'phone': '+99555500'}).phone, '+99555500');
      expect(
        CompanyInfo.fromMap({'phone': '+995555000000000'}).phone,
        '+995555000000000',
      );
      expectInvalid({'phone': '+9955550'});
      expectInvalid({'phone': '+9955550000000000'});
      expectInvalid({'phone': '+995 555 000 000'});
      expectInvalid({'phone': '+0555000000'});
      expectInvalid({'phone': 995555000000});
    });

    test('the e-mail: the booking check, nothing around it', () {
      final long = '${letters(254 - '@example.com'.length)}@example.com';
      expect(CompanyInfo.fromMap({'email': long}).email, long);
      expectInvalid({'email': 'a$long'});
      expectInvalid({'email': 'info@example'});
      expectInvalid({'email': 'info @example.com'});
      expectInvalid({'email': 'info@@example.com'});
      expectInvalid({'email': ' info@example.com'});
      expectInvalid({'email': 5});
    });

    test('a translated text needs all three languages', () {
      final text = {'ka': letters(300), 'ru': letters(300), 'en': letters(300)};
      expect(
        CompanyInfo.fromMap({'address': text}).address,
        LocalizedText(ka: letters(300), ru: letters(300), en: letters(300)),
      );
      expectInvalid({
        'address': {...text, 'en': letters(301)},
      });
      expectInvalid({
        'address': {'en': 'Tbilisi, 1 Example Street'},
      });
      expectInvalid({
        'address': {...text, 'de': 'Tiflis'},
      });
      expectInvalid({
        'address': {...text, 'ka': ''},
      });
      expectInvalid({'address': 'Tbilisi, 1 Example Street'});
      expectInvalid({
        'workingHours': {...text, 'ru': 5},
      });
    });

    test('a line break inside a translated text is fine', () {
      final company = CompanyInfo.fromMap({
        'workingHours': {
          'ka': 'ორშ–პარ 09:00–20:00\nშაბ 10:00–18:00',
          'ru': 'Пн–Пт 09:00–20:00\nСб 10:00–18:00',
          'en': 'Mon–Fri 09:00–20:00\nSat 10:00–18:00',
        },
      });
      expect(company.workingHours!.en, contains('\n'));
    });

    test('the map link: https, no space, a dot, at most 500', () {
      expect(
        CompanyInfo.fromMap({'mapUrl': linkOfLength(500)}).mapUrl,
        linkOfLength(500),
      );
      expectInvalid({'mapUrl': linkOfLength(501)});
      expectInvalid({'mapUrl': 'http://maps.example.com/tbilisi'});
      expectInvalid({'mapUrl': 'https://maps.example.com/tbilisi office'});
      expectInvalid({'mapUrl': 'https://localhost'});
    });

    test('the social links', () {
      expect(
        CompanyInfo.fromMap({
          'social': {'telegram': 'https://www.example.com/telegram'},
        }).social,
        {CompanySocialLink.telegram: 'https://www.example.com/telegram'},
      );
      expectInvalid({'social': <String, dynamic>{}});
      expectInvalid({
        'social': {'tiktok': 'https://www.example.com/tiktok'},
      });
      expectInvalid({
        'social': {'facebook': 'http://www.example.com/facebook'},
      });
      expectInvalid({
        'social': {'facebook': 'https://www.example.com/face book'},
      });
      expectInvalid({
        'social': {'facebook': linkOfLength(501)},
      });
      expectInvalid({
        'social': {'facebook': 5},
      });
      expectInvalid({
        'social': {'facebook': null},
      });
      expectInvalid({
        'social': ['https://www.example.com/facebook'],
      });
    });

    test('the message names the field, never the value', () {
      try {
        CompanyInfo.fromMap({'email': 'secret value@example.com'});
        fail('Expected a FormatException.');
      } on FormatException catch (error) {
        expect(error.message, contains('"email"'));
        expect(error.message, isNot(contains('secret value')));
      }
    });
  });

  group('toMap', () {
    test('a full company gives back the stored document', () {
      expect(CompanyInfo.fromMap(fullDocument()).toMap(), fullDocument());
    });

    test('a field that is not set is left out, never null or empty', () {
      final company = CompanyInfo(name: 'Example Car Rental');
      expect(company.toMap(), {'name': 'Example Car Rental'});
      expect(CompanyInfo.empty.toMap(), isEmpty);
    });

    test('its keys are always among the allowed fields', () {
      expect(
        companyFields,
        containsAll(CompanyInfo.fromMap(fullDocument()).toMap().keys),
      );
    });

    test('the social links keep the stored key names', () {
      expect([
        for (final link in CompanySocialLink.values) link.name,
      ], companySocialFields);
    });
  });

  group('equality', () {
    test('equal values are equal, with equal hash codes', () {
      final a = CompanyInfo.fromMap(fullDocument());
      final b = CompanyInfo.fromMap(fullDocument());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the order of the social links does not matter', () {
      final a = CompanyInfo(
        social: {
          CompanySocialLink.facebook: 'https://www.example.com/facebook',
          CompanySocialLink.telegram: 'https://www.example.com/telegram',
        },
      );
      final b = CompanyInfo(
        social: {
          CompanySocialLink.telegram: 'https://www.example.com/telegram',
          CompanySocialLink.facebook: 'https://www.example.com/facebook',
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('one different field makes them different', () {
      final a = CompanyInfo.fromMap(fullDocument());
      for (final field in companyFields) {
        final b = CompanyInfo.fromMap(changed((d) => d.remove(field)));
        expect(a == b, false, reason: field);
      }
    });

    test('the social links cannot be changed', () {
      final company = CompanyInfo.fromMap(fullDocument());
      expect(
        () => company.social[CompanySocialLink.facebook] = 'x',
        throwsUnsupportedError,
      );
    });
  });

  group('the stored-value checks', () {
    test('isCompanyName', () {
      expect(isCompanyName('a'), true);
      expect(isCompanyName(letters(100)), true);
      expect(isCompanyName(letters(101)), false);
      expect(isCompanyName(''), false);
      expect(isCompanyName(' a'), false);
    });

    test('isCompanyTextPart counts characters, not code units', () {
      // 300 Georgian letters are 300 characters.
      expect(isCompanyTextPart('ა' * 300), true);
      expect(isCompanyTextPart('ა' * 301), false);
    });

    test('isStoredCompanyPhone', () {
      expect(isStoredCompanyPhone('+995555000000'), true);
      expect(isStoredCompanyPhone('+995-555-000000'), false);
    });

    test('isStoredCompanyEmail', () {
      expect(isStoredCompanyEmail('info@example.com'), true);
      expect(isStoredCompanyEmail('info@example.com '), false);
    });

    test('isCompanyLink', () {
      expect(isCompanyLink('https://www.example.com/a'), true);
      expect(isCompanyLink('HTTPS://www.example.com/a'), false);
      expect(isCompanyLink('https://'), false);
    });
  });
}
