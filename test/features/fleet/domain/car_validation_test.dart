import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';

/// 14 Oct 2026, 12:00 UTC: the newest allowed year is 2027.
final now = DateTime.utc(2026, 10, 14, 12);

/// A complete, valid draft. All values are made up.
CarDraft valid() => const CarDraft(
  brand: 'Honda',
  model: 'Civic',
  year: '2019',
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: '5',
  engineSize: '1.8',
  pricePerDay: '45',
  descriptionKa: 'ქართული',
  descriptionRu: 'Русский',
  descriptionEn: 'English',
  photos: ['https://photos.example.com/car-1.jpg'],
);

Set<CarError> errorsOf(CarDraft draft, {DateTime? at}) =>
    validateCarDraft(draft, now: at ?? now).errors;

Map<int, CarPhotoError> photoErrorsOf(List<String> photos) =>
    validateCarDraft(valid().copyWith(photos: photos), now: now).photoErrors;

String letters(int count) => 'a' * count;

void main() {
  test('a valid draft has no errors', () {
    final result = validateCarDraft(valid(), now: now);
    expect(result.errors, isEmpty);
    expect(result.photoErrors, isEmpty);
    expect(result.hasErrors, false);
  });

  test('an empty draft names every required field', () {
    expect(errorsOf(const CarDraft()), {
      CarError.brandRequired,
      CarError.modelRequired,
      CarError.yearRequired,
      CarError.drivetrainRequired,
      CarError.transmissionRequired,
      CarError.fuelTypeRequired,
      CarError.seatsRequired,
      CarError.priceRequired,
      CarError.descriptionKaRequired,
      CarError.descriptionRuRequired,
      CarError.descriptionEnRequired,
    });
  });

  group('brand and model', () {
    test('40 characters pass, 41 do not', () {
      expect(errorsOf(valid().copyWith(brand: letters(40))), isEmpty);
      expect(errorsOf(valid().copyWith(brand: letters(41))), {
        CarError.brandTooLong,
      });
      expect(errorsOf(valid().copyWith(model: letters(41))), {
        CarError.modelTooLong,
      });
    });

    test('only spaces is empty; spaces at the ends do not count', () {
      expect(errorsOf(valid().copyWith(brand: '   ')), {
        CarError.brandRequired,
      });
      expect(errorsOf(valid().copyWith(model: ' ${letters(40)} ')), isEmpty);
    });
  });

  group('year', () {
    test('1990 to this year plus one', () {
      expect(errorsOf(valid().copyWith(year: '1990')), isEmpty);
      expect(errorsOf(valid().copyWith(year: '2027')), isEmpty);
      expect(errorsOf(valid().copyWith(year: '1989')), {CarError.yearTooOld});
      expect(errorsOf(valid().copyWith(year: '2028')), {CarError.yearTooNew});
    });

    test('a whole number only', () {
      for (final text in ['2019.0', '2019.5', '20 19', 'abc', '-2019']) {
        expect(errorsOf(valid().copyWith(year: text)), {
          CarError.yearNotWhole,
        }, reason: text);
      }
      expect(errorsOf(valid().copyWith(year: ' 2019 ')), isEmpty);
    });

    test('the newest year comes from the UTC year of the clock: on 31 Dec '
        'at 23:30 in Tbilisi it is still the old year in UTC', () {
      // 31 Dec 2026 23:30 Tbilisi = 19:30 UTC.
      final newYearsEve = DateTime.utc(2026, 12, 31, 19, 30);
      expect(
        errorsOf(valid().copyWith(year: '2027'), at: newYearsEve),
        isEmpty,
      );
      expect(errorsOf(valid().copyWith(year: '2028'), at: newYearsEve), {
        CarError.yearTooNew,
      });
      // 1 Jan 2027 00:30 UTC: now 2028 is allowed.
      expect(
        errorsOf(valid().copyWith(year: '2028'), at: DateTime.utc(2027)),
        isEmpty,
      );
    });
  });

  test('the three fixed lists are required', () {
    const empty = CarDraft(
      brand: 'Honda',
      model: 'Civic',
      year: '2019',
      seats: '5',
      pricePerDay: '45',
      descriptionKa: 'ქართული',
      descriptionRu: 'Русский',
      descriptionEn: 'English',
    );
    expect(errorsOf(empty), {
      CarError.drivetrainRequired,
      CarError.transmissionRequired,
      CarError.fuelTypeRequired,
    });
  });

  group('seats', () {
    test('1 to 9', () {
      expect(errorsOf(valid().copyWith(seats: '1')), isEmpty);
      expect(errorsOf(valid().copyWith(seats: '9')), isEmpty);
      expect(errorsOf(valid().copyWith(seats: '0')), {
        CarError.seatsOutOfRange,
      });
      expect(errorsOf(valid().copyWith(seats: '10')), {
        CarError.seatsOutOfRange,
      });
    });

    test('a whole number only', () {
      expect(errorsOf(valid().copyWith(seats: '4.5')), {
        CarError.seatsNotWhole,
      });
      expect(errorsOf(valid().copyWith(seats: '5.0')), {
        CarError.seatsNotWhole,
      });
    });
  });

  group('engine size', () {
    test('empty is fine: it is optional', () {
      expect(errorsOf(valid().copyWith(engineSize: '')), isEmpty);
      expect(errorsOf(valid().copyWith(engineSize: '  ')), isEmpty);
    });

    test('above 0, up to 8, at most two decimals, a comma allowed', () {
      expect(errorsOf(valid().copyWith(engineSize: '8')), isEmpty);
      expect(errorsOf(valid().copyWith(engineSize: '1,6')), isEmpty);
      expect(errorsOf(valid().copyWith(engineSize: '0.01')), isEmpty);
      expect(errorsOf(valid().copyWith(engineSize: '0')), {
        CarError.engineSizeOutOfRange,
      });
      expect(errorsOf(valid().copyWith(engineSize: '8.01')), {
        CarError.engineSizeOutOfRange,
      });
      expect(errorsOf(valid().copyWith(engineSize: '1.655')), {
        CarError.engineSizeInvalid,
      });
      expect(errorsOf(valid().copyWith(engineSize: 'big')), {
        CarError.engineSizeInvalid,
      });
    });
  });

  group('price per day', () {
    test('above 0, up to 2000', () {
      expect(errorsOf(valid().copyWith(pricePerDay: '0.01')), isEmpty);
      expect(errorsOf(valid().copyWith(pricePerDay: '2000')), isEmpty);
      expect(errorsOf(valid().copyWith(pricePerDay: '0')), {
        CarError.priceOutOfRange,
      });
      expect(errorsOf(valid().copyWith(pricePerDay: '2000.01')), {
        CarError.priceOutOfRange,
      });
    });

    test('a comma, spaces, and at most two decimals', () {
      expect(errorsOf(valid().copyWith(pricePerDay: '45,50')), isEmpty);
      expect(errorsOf(valid().copyWith(pricePerDay: ' 45 ')), isEmpty);
      expect(errorsOf(valid().copyWith(pricePerDay: '45.555')), {
        CarError.priceInvalid,
      });
      expect(errorsOf(valid().copyWith(pricePerDay: '-5')), {
        CarError.priceInvalid,
      });
    });
  });

  group('description', () {
    test('each language is required', () {
      expect(errorsOf(valid().copyWith(descriptionKa: '')), {
        CarError.descriptionKaRequired,
      });
      expect(errorsOf(valid().copyWith(descriptionRu: ' ')), {
        CarError.descriptionRuRequired,
      });
      expect(errorsOf(valid().copyWith(descriptionEn: '\n')), {
        CarError.descriptionEnRequired,
      });
    });

    test('1000 characters pass, 1001 do not, counted in Georgian letters', () {
      expect(errorsOf(valid().copyWith(descriptionKa: 'ა' * 1000)), isEmpty);
      expect(errorsOf(valid().copyWith(descriptionKa: 'ა' * 1001)), {
        CarError.descriptionKaTooLong,
      });
      expect(errorsOf(valid().copyWith(descriptionRu: 'ж' * 1001)), {
        CarError.descriptionRuTooLong,
      });
      expect(errorsOf(valid().copyWith(descriptionEn: letters(1001))), {
        CarError.descriptionEnTooLong,
      });
    });

    test('line breaks inside are fine', () {
      expect(
        errorsOf(valid().copyWith(descriptionEn: 'One line\nAnother line')),
        isEmpty,
      );
    });
  });

  group('photos', () {
    test('none is fine', () {
      expect(photoErrorsOf(const []), isEmpty);
    });

    test('the same pattern as the rules', () {
      expect(carPhotoPattern.pattern, r'^https://\S+\.\S+$');
      expect(carPhotoProblem('https://a.b'), isNull);
      expect(carPhotoProblem('https://.com'), CarPhotoError.notWebAddress);
      expect(carPhotoProblem('https://a.'), CarPhotoError.notWebAddress);
      expect(
        carPhotoProblem('https://localhost/car'),
        CarPhotoError.notWebAddress,
      );
      expect(carPhotoProblem('https://'), CarPhotoError.notWebAddress);
      expect(carPhotoProblem('https://a b.c'), CarPhotoError.hasSpace);
      expect(carPhotoProblem('http://a.b'), CarPhotoError.notHttps);
      expect(carPhotoProblem('HTTPS://a.b'), CarPhotoError.notHttps);
      expect(carPhotoProblem(''), CarPhotoError.notHttps);
    });

    test('500 characters pass, 501 do not', () {
      const start = 'https://a.example/';
      expect(carPhotoProblem('$start${letters(500 - start.length)}'), isNull);
      expect(
        carPhotoProblem('$start${letters(501 - start.length)}'),
        CarPhotoError.tooLong,
      );
    });

    test('spaces at the ends are trimmed first', () {
      expect(carPhotoProblem('  https://a.b  '), isNull);
    });

    test(
      'a duplicate is reported at its second place, also after trimming',
      () {
        expect(
          photoErrorsOf(const ['https://a.b/1.jpg', ' https://a.b/1.jpg ']),
          {1: CarPhotoError.duplicate},
        );
      },
    );

    test('each bad address is reported at its place', () {
      expect(
        photoErrorsOf(const ['https://a.b', 'http://a.b', 'https://a b.c']),
        {1: CarPhotoError.notHttps, 2: CarPhotoError.hasSpace},
      );
    });

    test('10 photos pass, 11 do not', () {
      List<String> photos(int count) => [
        for (var i = 0; i < count; i++) 'https://photos.example.com/$i.jpg',
      ];
      expect(errorsOf(valid().copyWith(photos: photos(carMaxPhotos))), isEmpty);
      expect(errorsOf(valid().copyWith(photos: photos(carMaxPhotos + 1))), {
        CarError.tooManyPhotos,
      });
    });
  });

  group('parseWholeInput', () {
    test('digits only', () {
      expect(parseWholeInput('2019'), 2019);
      expect(parseWholeInput(' 5 '), 5);
      expect(parseWholeInput('5.0'), isNull);
      expect(parseWholeInput(''), isNull);
      expect(parseWholeInput('-1'), isNull);
      expect(parseWholeInput('1234567'), isNull);
    });
  });
}
