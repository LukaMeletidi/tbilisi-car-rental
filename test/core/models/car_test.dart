import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';

Map<String, dynamic> validCarMap() => {
  'brand': 'Toyota',
  'model': 'Prius',
  'year': 2019,
  'drivetrain': 'fwd',
  'transmission': 'automatic',
  'fuelType': 'hybrid',
  'seats': 5,
  'engineSize': 1.8,
  'pricePerDay': 45,
  'description': {'ka': 'ქართული', 'ru': 'Русский', 'en': 'English'},
  'photos': ['https://example.com/prius.jpg'],
  'active': true,
};

Map<String, dynamic> carMapWith(String field, Object? value) =>
    validCarMap()..[field] = value;

Map<String, dynamic> carMapWithout(String field) =>
    validCarMap()..remove(field);

void main() {
  group('LocalizedText.forLanguage', () {
    const text = LocalizedText(ka: 'ქართული', ru: 'Русский', en: 'English');

    test('returns the text in the requested language', () {
      expect(text.forLanguage(AppLanguage.ka), 'ქართული');
      expect(text.forLanguage(AppLanguage.ru), 'Русский');
      expect(text.forLanguage(AppLanguage.en), 'English');
    });

    test('falls back to English when the language is missing', () {
      const onlyEnglish = LocalizedText(en: 'English');
      expect(onlyEnglish.forLanguage(AppLanguage.ka), 'English');
      expect(onlyEnglish.forLanguage(AppLanguage.ru), 'English');
    });

    test('treats a text of only spaces as missing', () {
      const spaces = LocalizedText(ka: '   ', en: 'English');
      expect(spaces.forLanguage(AppLanguage.ka), 'English');
    });

    test('returns an empty text when English is missing too', () {
      const onlyRussian = LocalizedText(ru: 'Русский');
      expect(onlyRussian.forLanguage(AppLanguage.ka), '');
      expect(onlyRussian.forLanguage(AppLanguage.en), '');
      expect(const LocalizedText().forLanguage(AppLanguage.ru), '');
    });
  });

  group('Car.fromMap', () {
    test('reads a complete document', () {
      final car = Car.fromMap('car-1', validCarMap());

      expect(car.id, 'car-1');
      expect(car.brand, 'Toyota');
      expect(car.model, 'Prius');
      expect(car.year, 2019);
      expect(car.drivetrain, Drivetrain.fwd);
      expect(car.transmission, Transmission.automatic);
      expect(car.fuelType, FuelType.hybrid);
      expect(car.seats, 5);
      expect(car.engineSize, 1.8);
      expect(car.pricePerDay, 45.0);
      expect(
        car.description,
        const LocalizedText(ka: 'ქართული', ru: 'Русский', en: 'English'),
      );
      expect(car.photos, ['https://example.com/prius.jpg']);
      expect(car.active, true);
    });

    test('engineSize is optional', () {
      final car = Car.fromMap('id', carMapWithout('engineSize'));
      expect(car.engineSize, isNull);
    });

    test('accepts whole and decimal numbers', () {
      expect(
        Car.fromMap('id', carMapWith('pricePerDay', 45)).pricePerDay,
        45.0,
      );
      expect(
        Car.fromMap('id', carMapWith('pricePerDay', 45.5)).pricePerDay,
        45.5,
      );
      expect(Car.fromMap('id', carMapWith('engineSize', 2)).engineSize, 2.0);
      expect(Car.fromMap('id', carMapWith('year', 2019.0)).year, 2019);
      expect(Car.fromMap('id', carMapWith('seats', 7.0)).seats, 7);
    });

    test('throws when a required field is missing', () {
      const requiredFields = [
        'brand',
        'model',
        'year',
        'drivetrain',
        'transmission',
        'fuelType',
        'seats',
        'pricePerDay',
        'active',
      ];
      for (final field in requiredFields) {
        expect(
          () => Car.fromMap('id', carMapWithout(field)),
          throwsFormatException,
          reason: 'missing $field',
        );
      }
    });

    test('throws when a field has the wrong type', () {
      expect(
        () => Car.fromMap('id', carMapWith('seats', '5')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('brand', 123)),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('active', 'true')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('engineSize', '1.8')),
        throwsFormatException,
      );
    });

    test('throws when a whole-number field has a fraction', () {
      expect(
        () => Car.fromMap('id', carMapWith('year', 2019.5)),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('seats', 4.5)),
        throwsFormatException,
      );
    });

    test('throws for an unknown category value', () {
      expect(
        () => Car.fromMap('id', carMapWith('drivetrain', '4x4')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('transmission', 'robot')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('fuelType', 'gas')),
        throwsFormatException,
      );
    });

    test('category values are case-sensitive', () {
      expect(
        () => Car.fromMap('id', carMapWith('transmission', 'Automatic')),
        throwsFormatException,
      );
    });

    test('throws when seats is zero or negative', () {
      expect(
        () => Car.fromMap('id', carMapWith('seats', 0)),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('seats', -2)),
        throwsFormatException,
      );
    });

    test('throws when pricePerDay is zero or negative', () {
      expect(
        () => Car.fromMap('id', carMapWith('pricePerDay', 0)),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('pricePerDay', -10)),
        throwsFormatException,
      );
    });

    test('throws when brand is empty or only spaces', () {
      expect(
        () => Car.fromMap('id', carMapWith('brand', '')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('brand', '   ')),
        throwsFormatException,
      );
    });

    test('throws when model is empty or only spaces', () {
      expect(
        () => Car.fromMap('id', carMapWith('model', '')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('model', '   ')),
        throwsFormatException,
      );
    });

    test('throws when engineSize is present but zero or negative', () {
      expect(
        () => Car.fromMap('id', carMapWith('engineSize', 0)),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('engineSize', -1.6)),
        throwsFormatException,
      );
    });

    test('the year is not validated', () {
      expect(Car.fromMap('id', carMapWith('year', 1900)).year, 1900);
      expect(Car.fromMap('id', carMapWith('year', 3000)).year, 3000);
    });

    test('photos may be missing or empty', () {
      expect(Car.fromMap('id', carMapWithout('photos')).photos, isEmpty);
      expect(Car.fromMap('id', carMapWith('photos', [])).photos, isEmpty);
    });

    test('throws when photos is not a list of strings', () {
      expect(
        () => Car.fromMap('id', carMapWith('photos', 'https://example.com')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('photos', ['ok', 42])),
        throwsFormatException,
      );
    });

    test('a missing description is an empty description', () {
      final car = Car.fromMap('id', carMapWithout('description'));
      expect(car.description, const LocalizedText());
    });

    test('a description may have only some languages', () {
      final car = Car.fromMap(
        'id',
        carMapWith('description', {'en': 'English'}),
      );
      expect(car.description, const LocalizedText(en: 'English'));
    });

    test('throws when description is not a map of strings', () {
      expect(
        () => Car.fromMap('id', carMapWith('description', 'text')),
        throwsFormatException,
      );
      expect(
        () => Car.fromMap('id', carMapWith('description', {'en': 5})),
        throwsFormatException,
      );
    });
  });

  group('Car.toMap', () {
    test('toMap then fromMap gives the same car', () {
      final car = Car.fromMap('car-1', validCarMap());
      expect(Car.fromMap('car-1', car.toMap()), car);
    });

    test('does not contain the id', () {
      final map = Car.fromMap('car-1', validCarMap()).toMap();
      expect(map.containsKey('id'), false);
    });

    test('leaves engineSize out when it is not set', () {
      final map = Car.fromMap('id', carMapWithout('engineSize')).toMap();
      expect(map.containsKey('engineSize'), false);
    });

    test('writes categories as lowercase strings', () {
      final map = Car.fromMap('id', validCarMap()).toMap();
      expect(map['drivetrain'], 'fwd');
      expect(map['transmission'], 'automatic');
      expect(map['fuelType'], 'hybrid');
    });
  });

  group('Car.visibleEngineSize', () {
    test('is shown for a hybrid', () {
      final car = Car.fromMap('id', validCarMap());
      expect(car.visibleEngineSize, 1.8);
    });

    test('is hidden for an electric car even when it is set', () {
      final car = Car.fromMap('id', carMapWith('fuelType', 'electric'));
      expect(car.visibleEngineSize, isNull);
    });

    test('is hidden when it is not set', () {
      final car = Car.fromMap('id', carMapWithout('engineSize'));
      expect(car.visibleEngineSize, isNull);
    });
  });

  group('Car equality', () {
    test('cars with the same values are equal', () {
      final a = Car.fromMap('car-1', validCarMap());
      final b = Car.fromMap('car-1', validCarMap());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('cars with a different id, field or photo are not equal', () {
      final car = Car.fromMap('car-1', validCarMap());
      expect(car == Car.fromMap('car-2', validCarMap()), false);
      expect(car == Car.fromMap('car-1', carMapWith('seats', 4)), false);
      expect(
        car == Car.fromMap('car-1', carMapWith('photos', ['other.jpg'])),
        false,
      );
    });
  });
}
