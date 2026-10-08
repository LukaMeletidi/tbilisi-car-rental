import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';

Map<String, dynamic> location(String id, {String en = 'Name'}) => {
  'id': id,
  'name': {'en': en, 'ru': 'Название'},
};

Map<String, dynamic> document(List<Object?> items) => {'items': items};

void main() {
  test('reads the locations in the order of the document', () {
    final locations = parsePickupLocations(
      document([
        location('tbilisiAirport', en: 'Tbilisi Airport'),
        location('kutaisiAirport', en: 'Kutaisi Airport'),
      ]),
    );

    expect(locations.map((l) => l.id), ['tbilisiAirport', 'kutaisiAirport']);
    expect(locations.first.name.en, 'Tbilisi Airport');
    expect(locations.first.name.ru, 'Название');
  });

  test('a missing language falls back to the English name', () {
    final locations = parsePickupLocations(
      document([location('tbilisiOffice', en: 'Tbilisi Office')]),
    );
    expect(locations.single.name.forLanguage(AppLanguage.ka), 'Tbilisi Office');
  });

  test('throws when the document does not exist', () {
    expect(() => parsePickupLocations(null), throwsFormatException);
  });

  test('throws when items is missing, not a list, or empty', () {
    expect(() => parsePickupLocations({}), throwsFormatException);
    expect(() => parsePickupLocations({'items': 'x'}), throwsFormatException);
    expect(() => parsePickupLocations(document([])), throwsFormatException);
  });

  test('throws when an item is not a map', () {
    expect(
      () => parsePickupLocations(document(['tbilisiAirport'])),
      throwsFormatException,
    );
  });

  test('throws when an id is missing, empty or not text', () {
    expect(
      () => parsePickupLocations(
        document([
          {
            'name': {'en': 'Name'},
          },
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => parsePickupLocations(document([location('   ')])),
      throwsFormatException,
    );
    expect(
      () => parsePickupLocations(
        document([
          {
            'id': 7,
            'name': {'en': 'Name'},
          },
        ]),
      ),
      throwsFormatException,
    );
  });

  test('throws when an id is used twice', () {
    expect(
      () => parsePickupLocations(
        document([location('tbilisiAirport'), location('tbilisiAirport')]),
      ),
      throwsFormatException,
    );
  });

  test('throws when a location uses the reserved id "other"', () {
    expect(
      () => parsePickupLocations(
        document([location('tbilisiAirport'), location('other')]),
      ),
      throwsFormatException,
    );
  });

  test('an id that only contains the word "other" is allowed', () {
    final locations = parsePickupLocations(
      document([location('otherOffice'), location('Other')]),
    );
    expect(locations.map((l) => l.id), ['otherOffice', 'Other']);
  });

  test('accepts ids of letters, digits, "_" and "-"', () {
    final ids = ['a', 'tbilisiAirport', 'Office_2', 'batumi-port', 'a' * 64];
    final locations = parsePickupLocations(
      document([for (final id in ids) location(id)]),
    );
    expect(locations.map((l) => l.id), ids);
  });

  test('throws when an id has the wrong shape', () {
    for (final id in [
      'tbilisi airport',
      ' tbilisiAirport',
      'tbilisiAirport ',
      '1airport',
      '_airport',
      '-airport',
      'tbilisi.airport',
      'tbilisi/airport',
      'аэропорт',
      'a' * 65,
    ]) {
      expect(
        () => parsePickupLocations(document([location(id)])),
        throwsFormatException,
        reason: 'id "$id"',
      );
    }
  });

  test('throws when a location has no English name', () {
    expect(
      () => parsePickupLocations(
        document([
          {'id': 'tbilisiAirport'},
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => parsePickupLocations(document([location('a', en: '  ')])),
      throwsFormatException,
    );
    expect(
      () => parsePickupLocations(
        document([
          {
            'id': 'a',
            'name': {'ru': 'Название'},
          },
        ]),
      ),
      throwsFormatException,
    );
  });

  test('throws when a name is not text', () {
    expect(
      () => parsePickupLocations(
        document([
          {
            'id': 'a',
            'name': {'en': 5},
          },
        ]),
      ),
      throwsFormatException,
    );
  });

  test('the list cannot be changed', () {
    final locations = parsePickupLocations(document([location('a')]));
    expect(() => locations.clear(), throwsUnsupportedError);
  });
}
