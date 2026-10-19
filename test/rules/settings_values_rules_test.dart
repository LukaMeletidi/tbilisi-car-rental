import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';

/// The Dart checks of settings/company against the answers the Firestore
/// emulator gave in step 6.2 (tool/check_booking_rules.mjs, section J.2):
/// the SAME sample values, and for each whether the rules accepted it
/// (true) or refused it (false). When a Dart check and the rules disagree
/// on one of these values, this test fails.

String letters(int count) => 'a' * count;
String emailOfLength(int count) =>
    '${letters(count - '@example.com'.length)}@example.com';
String link(String path) => 'https://www.example.com/$path';
String linkOfLength(int count) => link(letters(count - link('').length));

typedef Sample = ({String label, String value, bool accepted});

final names = <Sample>[
  (label: 'Example Car Rental', value: 'Example Car Rental', accepted: true),
  (label: '100 characters', value: letters(100), accepted: true),
  (label: '101 characters', value: letters(101), accepted: false),
  (label: 'empty', value: '', accepted: false),
  (label: 'a space at the end', value: 'Example Car Rental ', accepted: false),
];

final phones = <Sample>[
  (label: 'the full sample', value: '+995555000000', accepted: true),
  (label: '8 digits', value: '+99555500', accepted: true),
  (label: '15 digits', value: '+995555000000000', accepted: true),
  (label: '7 digits', value: '+9955550', accepted: false),
  (label: '16 digits', value: '+9955550000000000', accepted: false),
  (label: 'with spaces', value: '+995 555 000 000', accepted: false),
  (label: 'starts with +0', value: '+0555000000', accepted: false),
];

final emails = <Sample>[
  (label: 'the full sample', value: 'info@example.com', accepted: true),
  (label: '254 characters', value: emailOfLength(254), accepted: true),
  (label: '255 characters', value: emailOfLength(255), accepted: false),
  (label: 'no dot in the domain', value: 'info@example', accepted: false),
  (label: 'a space', value: 'info @example.com', accepted: false),
  (label: 'two "@"', value: 'info@@example.com', accepted: false),
];

final textParts = <Sample>[
  (label: 'the en sample', value: 'Tbilisi, 1 Example Street', accepted: true),
  (label: 'the ka sample', value: 'თბილისი, სანიმუშო ქუჩა 1', accepted: true),
  (label: '300 characters', value: letters(300), accepted: true),
  (label: '301 characters', value: letters(301), accepted: false),
  (label: 'empty', value: '', accepted: false),
  (
    label: 'a line break inside',
    value: 'Mon–Fri 09:00–20:00\nSat 10:00–18:00',
    accepted: true,
  ),
];

final links = <Sample>[
  (
    label: 'the map sample',
    value: 'https://maps.example.com/tbilisi',
    accepted: true,
  ),
  (label: 'a social sample', value: link('facebook'), accepted: true),
  (label: '500 characters', value: linkOfLength(500), accepted: true),
  (label: '501 characters', value: linkOfLength(501), accepted: false),
  (label: 'http', value: 'http://maps.example.com/tbilisi', accepted: false),
  (
    label: 'a space (map)',
    value: 'https://maps.example.com/tbilisi office',
    accepted: false,
  ),
  (
    label: 'a space (social)',
    value: 'https://www.example.com/face book',
    accepted: false,
  ),
  (label: 'no dot', value: 'https://localhost', accepted: false),
];

void checkAll(
  String group,
  List<Sample> samples,
  bool Function(String value) dartCheck,
) {
  for (final sample in samples) {
    test('$group, ${sample.label}: '
        '${sample.accepted ? 'accepted' : 'refused'} as by the rules', () {
      expect(dartCheck(sample.value), sample.accepted);
    });
  }
}

/// The form agrees with the rules for a value typed exactly as stored:
/// no problem for an accepted value, a problem for a refused one. Empty is
/// "not set" in the form, so empty samples are left out here.
void checkForm(
  String group,
  List<Sample> samples,
  CompanyInput Function(String value) input,
  CompanyField field,
) {
  for (final sample in samples.where((sample) => sample.value.isNotEmpty)) {
    if (sample.label == 'with spaces') continue; // see the test below
    if (sample.label.startsWith('a space at the end')) continue; // trimmed
    test('the form, $group, ${sample.label}', () {
      final problems = validateCompanyInput(input(sample.value));
      expect(problems.containsKey(field), !sample.accepted);
    });
  }
}

void main() {
  checkAll('name', names, isCompanyName);
  checkAll('phone', phones, isStoredCompanyPhone);
  checkAll('e-mail', emails, isStoredCompanyEmail);
  checkAll('translated text part', textParts, isCompanyTextPart);
  checkAll('link', links, isCompanyLink);

  checkForm('name', names, (v) => CompanyInput(name: v), CompanyField.name);
  checkForm('phone', phones, (v) => CompanyInput(phone: v), CompanyField.phone);
  checkForm(
    'e-mail',
    emails,
    (v) => CompanyInput(email: v),
    CompanyField.email,
  );
  checkForm(
    'address',
    textParts,
    (v) => CompanyInput(
      address: LocalizedText(ka: v, ru: v, en: v),
    ),
    CompanyField.address,
  );
  checkForm(
    'map link',
    links,
    (v) => CompanyInput(mapUrl: v),
    CompanyField.mapUrl,
  );
  checkForm(
    'social link',
    links,
    (v) => CompanyInput(social: {CompanySocialLink.facebook: v}),
    CompanyField.facebook,
  );

  test('the form stores a phone typed with spaces in the form the rules '
      'accept', () {
    const typed = '+995 555 000 000';
    expect(validateCompanyInput(const CompanyInput(phone: typed)), isEmpty);
    final stored = companyFromInput(const CompanyInput(phone: typed)).phone!;
    expect(stored, '+995555000000');
    expect(isStoredCompanyPhone(stored), true);
  });

  test('the form stores a name typed with a space at the end trimmed, in '
      'the form the rules accept', () {
    final stored = companyFromInput(
      const CompanyInput(name: 'Example Car Rental '),
    ).name!;
    expect(stored, 'Example Car Rental');
    expect(isCompanyName(stored), true);
  });
}
