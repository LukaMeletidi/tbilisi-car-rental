import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';

String letters(int count) => 'a' * count;

/// A full, valid input. All values are made up.
const fullInput = CompanyInput(
  name: 'Example Car Rental',
  phone: '+995555000000',
  email: 'info@example.com',
  address: LocalizedText(
    ka: 'თბილისი, სანიმუშო ქუჩა 1',
    ru: 'Тбилиси, Примерная улица 1',
    en: 'Tbilisi, 1 Example Street',
  ),
  workingHours: LocalizedText(
    ka: 'ყოველდღე 09:00–20:00',
    ru: 'Ежедневно 09:00–20:00',
    en: 'Every day 09:00–20:00',
  ),
  mapUrl: 'https://maps.example.com/tbilisi',
  social: {
    CompanySocialLink.facebook: 'https://www.example.com/facebook',
    CompanySocialLink.telegram: 'https://www.example.com/telegram',
  },
);

Map<CompanyField, CompanyProblem> problemsOf(CompanyInput input) =>
    validateCompanyInput(input);

void main() {
  group('validateCompanyInput', () {
    test('an empty form is valid: nothing is set', () {
      expect(problemsOf(const CompanyInput()), isEmpty);
    });

    test('a full form is valid', () {
      expect(problemsOf(fullInput), isEmpty);
    });

    test('the name: at most 100 characters after trimming', () {
      expect(problemsOf(CompanyInput(name: '  ${letters(100)}  ')), isEmpty);
      expect(problemsOf(CompanyInput(name: letters(101))), {
        CompanyField.name: CompanyProblem.tooLong,
      });
    });

    test('the phone: spaces and hyphens are fine, the rest is checked', () {
      expect(
        problemsOf(const CompanyInput(phone: '+995 555 00-00-00')),
        isEmpty,
      );
      for (final phone in ['+9955550', '+0555000000', '995555000000', 'x']) {
        expect(problemsOf(CompanyInput(phone: phone)), {
          CompanyField.phone: CompanyProblem.invalid,
        }, reason: phone);
      }
    });

    test('the e-mail: the booking check', () {
      expect(
        problemsOf(const CompanyInput(email: ' info@example.com ')),
        isEmpty,
      );
      for (final email in [
        'info@example',
        'info @example.com',
        'info@@example.com',
      ]) {
        expect(problemsOf(CompanyInput(email: email)), {
          CompanyField.email: CompanyProblem.invalid,
        }, reason: email);
      }
    });

    test('a translated text: all three, or none', () {
      expect(
        problemsOf(
          const CompanyInput(
            address: LocalizedText(en: 'Tbilisi, 1 Example Street'),
          ),
        ),
        {CompanyField.address: CompanyProblem.incomplete},
      );
      expect(
        problemsOf(
          const CompanyInput(
            workingHours: LocalizedText(ka: 'ა', ru: '  '),
          ),
        ),
        {CompanyField.workingHours: CompanyProblem.incomplete},
      );
      expect(
        problemsOf(
          const CompanyInput(
            address: LocalizedText(ka: ' ', ru: ' ', en: ' '),
          ),
        ),
        isEmpty,
      );
    });

    test('a translated text: at most 300 characters per language', () {
      expect(
        problemsOf(
          CompanyInput(
            address: LocalizedText(
              ka: letters(300),
              ru: letters(300),
              en: letters(301),
            ),
          ),
        ),
        {CompanyField.address: CompanyProblem.tooLong},
      );
    });

    test('a link: https, no space, a dot, at most 500', () {
      const start = 'https://www.example.com/';
      expect(
        problemsOf(CompanyInput(mapUrl: start + letters(500 - start.length))),
        isEmpty,
      );
      final cases = {
        start + letters(501 - start.length): CompanyProblem.tooLong,
        'http://maps.example.com/tbilisi': CompanyProblem.notHttps,
        'www.example.com': CompanyProblem.notHttps,
        'https://maps.example.com/tbilisi office': CompanyProblem.invalid,
        'https://localhost': CompanyProblem.invalid,
      };
      for (final MapEntry(key: link, value: problem) in cases.entries) {
        expect(problemsOf(CompanyInput(mapUrl: link)), {
          CompanyField.mapUrl: problem,
        }, reason: link);
      }
    });

    test('each social link has its own field', () {
      final problems = problemsOf(
        const CompanyInput(
          social: {
            CompanySocialLink.facebook: 'http://www.example.com/facebook',
            CompanySocialLink.instagram: 'https://www.example.com/instagram',
            CompanySocialLink.whatsapp: 'https://localhost',
            CompanySocialLink.telegram: '',
          },
        ),
      );
      expect(problems, {
        CompanyField.facebook: CompanyProblem.notHttps,
        CompanyField.whatsapp: CompanyProblem.invalid,
      });
    });

    test('several problems at once, one per field', () {
      final problems = problemsOf(
        CompanyInput(
          name: letters(101),
          phone: 'x',
          mapUrl: 'http://x.example.com',
        ),
      );
      expect(problems.keys, {
        CompanyField.name,
        CompanyField.phone,
        CompanyField.mapUrl,
      });
    });
  });

  group('companyFromInput', () {
    test('trims, leaves out empty texts and stores the phone digits', () {
      final company = companyFromInput(
        const CompanyInput(
          name: '  Example Car Rental ',
          phone: '+995 555 00-00-00',
          email: ' info@example.com ',
          address: LocalizedText(
            ka: ' თბილისი ',
            ru: ' Тбилиси ',
            en: ' Tbilisi ',
          ),
          mapUrl: '   ',
          social: {CompanySocialLink.telegram: ' https://www.example.com/t '},
        ),
      );
      expect(company.toMap(), {
        'name': 'Example Car Rental',
        'phone': '+995555000000',
        'email': 'info@example.com',
        'address': {'ka': 'თბილისი', 'ru': 'Тбилиси', 'en': 'Tbilisi'},
        'social': {'telegram': 'https://www.example.com/t'},
      });
    });

    test('an empty form gives an empty company', () {
      expect(companyFromInput(const CompanyInput()), CompanyInfo.empty);
    });

    test('throws when the input has a problem', () {
      expect(
        () => companyFromInput(const CompanyInput(phone: 'x')),
        throwsArgumentError,
      );
    });

    test('what it builds is always readable as a stored document', () {
      final company = companyFromInput(fullInput);
      expect(CompanyInfo.fromMap(company.toMap()), company);
    });
  });

  group('CompanyInput.fromCompany', () {
    test('no document gives an empty form', () {
      final input = CompanyInput.fromCompany(null);
      expect(input.name, '');
      expect(input.address, const LocalizedText());
      expect(input.social, isEmpty);
    });

    test('the form filled from a company saves the same company', () {
      final company = companyFromInput(fullInput);
      expect(companyFromInput(CompanyInput.fromCompany(company)), company);
    });
  });
}
