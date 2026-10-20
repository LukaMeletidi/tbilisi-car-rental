import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

import '../about_samples.dart';

List<ContactKind> kinds(List<ContactRow> rows) => [
  for (final row in rows) row.kind,
];

void main() {
  test('no document, or nothing filled in: no rows and no title', () {
    expect(contactRows(null, AppLanguage.en), isEmpty);
    expect(contactRows(CompanyInfo.empty, AppLanguage.en), isEmpty);
    expect(contactsTitle(null), isNull);
    expect(contactsTitle(CompanyInfo.empty), isNull);
  });

  test('every field: the rows in order; the address opens the map', () {
    final rows = contactRows(fullCompany(), AppLanguage.en);
    expect(kinds(rows), [
      ContactKind.phone,
      ContactKind.email,
      ContactKind.address,
      ContactKind.workingHours,
      ContactKind.facebook,
      ContactKind.instagram,
      ContactKind.whatsapp,
      ContactKind.telegram,
    ]);
    expect(rows[0].uri, Uri.parse('tel:+995555000001'));
    expect(rows[1].uri, Uri.parse('mailto:info@example.com'));
    expect(rows[2].text, sampleAddress.en);
    expect(rows[2].uri, Uri.parse('https://www.example.com/map'));
    expect(rows[3].text, sampleHours.en);
    expect(rows[3].uri, isNull);
    expect(rows[4].uri, Uri.parse('https://www.example.com/facebook'));
    expect(contactsTitle(fullCompany()), 'Example Car Rental');
  });

  test('the address and the working hours follow the language', () {
    for (final language in AppLanguage.values) {
      final rows = contactRows(fullCompany(), language);
      expect(rows[2].text, sampleAddress.forLanguage(language));
      expect(rows[3].text, sampleHours.forLanguage(language));
    }
  });

  test('no map link: the address is plain text, no map row', () {
    final rows = contactRows(fullCompany(mapUrl: null), AppLanguage.en);
    final row = rows.firstWhere((row) => row.kind == ContactKind.address);
    expect(row.uri, isNull);
    expect(kinds(rows), isNot(contains(ContactKind.map)));
  });

  test('a map link without an address: a row of its own', () {
    final rows = contactRows(
      CompanyInfo(mapUrl: 'https://www.example.com/map'),
      AppLanguage.en,
    );
    expect(rows, [
      ContactRow(
        kind: ContactKind.map,
        uri: Uri.parse('https://www.example.com/map'),
      ),
    ]);
  });

  test('only the filled fields', () {
    final rows = contactRows(
      CompanyInfo(
        phone: '+995555000001',
        social: const {
          CompanySocialLink.telegram: 'https://www.example.com/telegram',
        },
      ),
      AppLanguage.en,
    );
    expect(kinds(rows), [ContactKind.phone, ContactKind.telegram]);
  });

  test('blank values are hidden', () {
    final rows = contactRows(
      CompanyInfo(
        name: '  ',
        phone: ' ',
        email: '\t',
        address: const LocalizedText(ka: ' ', ru: ' ', en: ' '),
        workingHours: const LocalizedText(ka: ' ', ru: ' ', en: ' '),
        mapUrl: ' ',
      ),
      AppLanguage.en,
    );
    expect(rows, isEmpty);
  });

  test('values are trimmed; the links have no spaces', () {
    final rows = contactRows(
      CompanyInfo(
        name: ' Example Car Rental ',
        phone: ' +995 555 000 001 ',
        email: ' info@example.com ',
      ),
      AppLanguage.en,
    );
    expect(rows[0].text, '+995 555 000 001');
    expect(rows[0].uri.toString(), 'tel:+995555000001');
    expect(rows[1].text, 'info@example.com');
    expect(rows[1].uri.toString(), 'mailto:info@example.com');
    expect(
      contactsTitle(CompanyInfo(name: ' Example Car Rental ')),
      'Example Car Rental',
    );
  });

  test('a map or social link that is not https is left out', () {
    final rows = contactRows(
      CompanyInfo(
        mapUrl: 'http://www.example.com/map',
        social: const {
          CompanySocialLink.facebook: 'javascript:alert(1)',
          CompanySocialLink.instagram: 'https://www.example.com/instagram',
        },
      ),
      AppLanguage.en,
    );
    expect(kinds(rows), [ContactKind.instagram]);
  });

  test('copy: phone, e-mail and address; a link copies its address', () {
    final rows = contactRows(fullCompany(), AppLanguage.en);
    expect(
      [for (final row in rows) row.copyable],
      [true, true, true, false, false, false, false, false],
    );
    expect(rows[0].copyText, '+995555000001');
    expect(rows[4].copyText, 'https://www.example.com/facebook');
  });
}
