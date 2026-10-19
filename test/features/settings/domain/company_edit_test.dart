import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// A made-up company.
final company = CompanyInfo(
  name: 'Example Car Rental',
  phone: '+995555000000',
  email: 'info@example.com',
  address: const LocalizedText(
    ka: 'თბილისი, სანიმუშო ქუჩა 1',
    ru: 'Тбилиси, Примерная улица 1',
    en: 'Tbilisi, 1 Example Street',
  ),
  social: const {CompanySocialLink.telegram: 'https://www.example.com/t'},
);

CompanyInput inputOf(CompanyInfo? info) => CompanyInput.fromCompany(info);

CompanyInput withName(CompanyInput input, String name) => CompanyInput(
  name: name,
  phone: input.phone,
  email: input.email,
  address: input.address,
  workingHours: input.workingHours,
  mapUrl: input.mapUrl,
  social: input.social,
);

CompanyInput withPhone(CompanyInput input, String phone) => CompanyInput(
  name: input.name,
  phone: phone,
  email: input.email,
  address: input.address,
  workingHours: input.workingHours,
  mapUrl: input.mapUrl,
  social: input.social,
);

void main() {
  group('companyDraftChanged', () {
    test('no document and an empty form: no change', () {
      expect(companyDraftChanged(null, const CompanyInput()), false);
    });

    test('no document and a form with only spaces: no change', () {
      expect(companyDraftChanged(null, const CompanyInput(name: '   ')), false);
    });

    test('no document and a filled field: a change', () {
      expect(
        companyDraftChanged(null, const CompanyInput(name: 'Example')),
        true,
      );
    });

    test('an empty stored document and an empty form: no change', () {
      expect(
        companyDraftChanged(CompanyInfo.empty, const CompanyInput()),
        false,
      );
    });

    test('the form as it opened: no change', () {
      expect(companyDraftChanged(company, inputOf(company)), false);
    });

    test('spaces around a text: no change', () {
      expect(
        companyDraftChanged(
          company,
          withName(inputOf(company), '  Example Car Rental  '),
        ),
        false,
      );
    });

    test('the stored phone typed with spaces: no change', () {
      expect(
        companyDraftChanged(
          company,
          withPhone(inputOf(company), '+995 555 00-00-00'),
        ),
        false,
      );
    });

    test('a cleared field: a change', () {
      expect(
        companyDraftChanged(company, withName(inputOf(company), '')),
        true,
      );
    });

    test('another value: a change', () {
      expect(
        companyDraftChanged(company, withName(inputOf(company), 'Other')),
        true,
      );
    });

    test('a text with a problem: a change', () {
      expect(
        companyDraftChanged(company, withPhone(inputOf(company), 'x')),
        true,
      );
      expect(companyDraftChanged(null, const CompanyInput(phone: 'x')), true);
    });
  });

  group('sameCompanyInput', () {
    test('equal texts, also with spaces at the ends', () {
      expect(
        sameCompanyInput(
          inputOf(company),
          withName(inputOf(company), ' Example Car Rental '),
        ),
        true,
      );
    });

    test('a social link that is empty equals one that is missing', () {
      expect(
        sameCompanyInput(
          const CompanyInput(),
          const CompanyInput(social: {CompanySocialLink.facebook: ' '}),
        ),
        true,
      );
    });

    test('a different translated text is not the same', () {
      expect(
        sameCompanyInput(
          const CompanyInput(),
          const CompanyInput(workingHours: LocalizedText(ru: 'Пн')),
        ),
        false,
      );
    });
  });

  test('every save failure has its notice', () {
    expect(
      noticeForCompanyWriteFailure(SettingsWriteFailure.noConnection),
      CompanySaveNotice.noConnection,
    );
    expect(
      noticeForCompanyWriteFailure(SettingsWriteFailure.refused),
      CompanySaveNotice.refused,
    );
    expect(
      noticeForCompanyWriteFailure(SettingsWriteFailure.changedElsewhere),
      CompanySaveNotice.changedElsewhere,
    );
    expect(
      noticeForCompanyWriteFailure(SettingsWriteFailure.unknown),
      CompanySaveNotice.unknown,
    );
  });
}
