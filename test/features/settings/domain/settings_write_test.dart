import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

ExtrasPrices prices(num price) => ExtrasPrices.fromMap({
  'pricesPerDay': {for (final extra in Extra.values) extra.name: price},
});

final companyA = CompanyInfo(name: 'Example Car Rental');
final companyB = CompanyInfo(name: 'Example Car Rental Two');

void main() {
  group('decideSettingsSave', () {
    test('already exactly the target: nothing is written', () {
      expect(
        decideSettingsSave(
          storedExists: true,
          stored: prices(7),
          base: prices(5),
          target: prices(7),
        ),
        SettingsSaveDecision.alreadySaved,
      );
    });

    test('unchanged since loaded: write', () {
      expect(
        decideSettingsSave(
          storedExists: true,
          stored: prices(5),
          base: prices(5),
          target: prices(7),
        ),
        SettingsSaveDecision.write,
      );
    });

    test('a stored 5 and a loaded 5.0 are the same', () {
      expect(
        decideSettingsSave(
          storedExists: true,
          stored: prices(5),
          base: prices(5.0),
          target: prices(7),
        ),
        SettingsSaveDecision.write,
      );
    });

    test('changed since loaded: nothing is written', () {
      expect(
        decideSettingsSave(
          storedExists: true,
          stored: prices(6),
          base: prices(5),
          target: prices(7),
        ),
        SettingsSaveDecision.changedElsewhere,
      );
    });

    test('the first save of the company: "does not exist" is expected', () {
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: false,
          stored: null,
          base: null,
          target: companyA,
        ),
        SettingsSaveDecision.write,
      );
    });

    test('created meanwhile by somebody else: nothing is written', () {
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: true,
          stored: companyB,
          base: null,
          target: companyA,
        ),
        SettingsSaveDecision.changedElsewhere,
      );
    });

    test('created meanwhile with exactly the target: already saved', () {
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: true,
          stored: companyA,
          base: null,
          target: companyA,
        ),
        SettingsSaveDecision.alreadySaved,
      );
    });

    test('removed meanwhile: nothing is written', () {
      expect(
        decideSettingsSave(
          storedExists: false,
          stored: null,
          base: prices(5),
          target: prices(7),
        ),
        SettingsSaveDecision.changedElsewhere,
      );
    });

    test('exists but cannot be read: nothing is written', () {
      expect(
        decideSettingsSave(
          storedExists: true,
          stored: null,
          base: prices(5),
          target: prices(7),
        ),
        SettingsSaveDecision.changedElsewhere,
      );
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: true,
          stored: null,
          base: null,
          target: companyA,
        ),
        SettingsSaveDecision.changedElsewhere,
      );
    });

    test('an empty company document and no document are not the same', () {
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: true,
          stored: CompanyInfo.empty,
          base: null,
          target: companyA,
        ),
        SettingsSaveDecision.changedElsewhere,
      );
      expect(
        decideSettingsSave<CompanyInfo>(
          storedExists: true,
          stored: CompanyInfo.empty,
          base: CompanyInfo.empty,
          target: companyA,
        ),
        SettingsSaveDecision.write,
      );
    });
  });

  group('extrasDocument', () {
    test('has exactly pricesPerDay with the four extras', () {
      final document = extrasDocument(prices(5));
      expect(document.keys, extrasSettingsFields);
      expect((document['pricesPerDay'] as Map).keys, [
        for (final extra in Extra.values) extra.name,
      ]);
    });

    test('is read back as the same prices', () {
      final saved = ExtrasPrices.fromMap({
        'pricesPerDay': {
          Extra.snowChains.name: 5,
          Extra.childSeat.name: 4.5,
          Extra.infantSeat.name: 0,
          Extra.boosterSeat.name: 100,
        },
      });
      expect(ExtrasPrices.fromMap(extrasDocument(saved)), saved);
    });
  });

  group('settingsWriteFailureFromCode', () {
    test('the codes with a reason', () {
      expect(
        settingsWriteFailureFromCode('unavailable'),
        SettingsWriteFailure.noConnection,
      );
      expect(
        settingsWriteFailureFromCode('deadline-exceeded'),
        SettingsWriteFailure.noConnection,
      );
      expect(
        settingsWriteFailureFromCode('permission-denied'),
        SettingsWriteFailure.refused,
      );
    });

    test('the web prefix is ignored', () {
      expect(
        settingsWriteFailureFromCode('firestore/permission-denied'),
        SettingsWriteFailure.refused,
      );
    });

    test('every other code is unknown, "not-found" and "aborted" too', () {
      for (final code in ['not-found', 'aborted', 'internal', '']) {
        expect(
          settingsWriteFailureFromCode(code),
          SettingsWriteFailure.unknown,
          reason: code,
        );
      }
    });
  });

  test('the exceptions compare by reason and name no value', () {
    const a = SettingsWriteException(SettingsWriteFailure.refused);
    expect(a, const SettingsWriteException(SettingsWriteFailure.refused));
    expect(
      a == const SettingsWriteException(SettingsWriteFailure.unknown),
      false,
    );
    expect(a.toString(), 'SettingsWriteException(refused)');
    expect(const SettingsWriteNoAnswer().toString(), 'SettingsWriteNoAnswer');
  });
}
