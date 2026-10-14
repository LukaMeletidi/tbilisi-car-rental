import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// A stored car. All values are made up.
Car car({double pricePerDay = 45, bool active = true}) => Car(
  id: 'car-1',
  brand: 'Honda',
  model: 'Civic',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: pricePerDay,
  description: const LocalizedText(ka: 'ქართული', ru: 'Русский', en: 'English'),
  photos: const ['https://photos.example.com/car-1.jpg'],
  active: active,
);

/// The stored document of [value], as Firestore hands it back.
Map<String, dynamic> stored(Car value) => carDocument(value);

void main() {
  test('the write timeout is 20 seconds', () {
    expect(carWriteTimeout, const Duration(seconds: 20));
  });

  test('a car ID has the shape the rules allow', () {
    expect(isPlausibleCarId('abcDEF123_-'), true);
    expect(isPlausibleCarId('a' * 128), true);
    expect(isPlausibleCarId('a' * 129), false);
    expect(isPlausibleCarId(''), false);
    expect(isPlausibleCarId('bad.id'), false);
    expect(isPlausibleCarId('cars/x'), false);
  });

  group('carWriteFailureFromCode', () {
    test('the same mapping as the admin bookings writes', () {
      expect(
        carWriteFailureFromCode('unavailable'),
        CarWriteFailure.noConnection,
      );
      expect(
        carWriteFailureFromCode('deadline-exceeded'),
        CarWriteFailure.noConnection,
      );
      expect(
        carWriteFailureFromCode('permission-denied'),
        CarWriteFailure.refused,
      );
      expect(carWriteFailureFromCode('not-found'), CarWriteFailure.carMissing);
      for (final code in [
        'aborted',
        'failed-precondition',
        'resource-exhausted',
        'internal',
        'unknown',
        '',
      ]) {
        expect(
          carWriteFailureFromCode(code),
          CarWriteFailure.unknown,
          reason: code,
        );
      }
    });
  });

  test('the exception texts name no value of a car', () {
    expect(
      '${const CarWriteException(CarWriteFailure.refused)}',
      'CarWriteException(refused)',
    );
    expect('${const CarWriteNoAnswer()}', 'CarWriteNoAnswer');
  });

  group('decideReplace', () {
    final base = car();
    final target = car(pricePerDay: 60);

    test('no stored document: car missing', () {
      expect(
        decideReplace(storedData: null, base: base, target: target),
        CarReplaceDecision.carMissing,
      );
    });

    test('the stored car is still the base: write', () {
      expect(
        decideReplace(storedData: stored(base), base: base, target: target),
        CarReplaceDecision.write,
      );
    });

    test('retry after a lost answer: the stored car is already the target', () {
      expect(
        decideReplace(storedData: stored(target), base: base, target: target),
        CarReplaceDecision.alreadySaved,
      );
    });

    test('nothing changed in the form: already saved, nothing written', () {
      expect(
        decideReplace(storedData: stored(base), base: base, target: base),
        CarReplaceDecision.alreadySaved,
      );
    });

    test('somebody else changed the car: changed elsewhere', () {
      expect(
        decideReplace(
          storedData: stored(car(pricePerDay: 50)),
          base: base,
          target: target,
        ),
        CarReplaceDecision.changedElsewhere,
      );
    });

    test(
      'a stored document that cannot be read as a car: changed elsewhere',
      () {
        expect(
          decideReplace(
            storedData: {'brand': 'Honda'},
            base: base,
            target: target,
          ),
          CarReplaceDecision.changedElsewhere,
        );
      },
    );

    test('an old incomplete car is the base: write (the repair)', () {
      final oldData = <String, dynamic>{...stored(base)}..remove('description');
      final oldBase = Car.fromMap('car-1', oldData);
      expect(
        decideReplace(storedData: oldData, base: oldBase, target: target),
        CarReplaceDecision.write,
      );
    });

    test('an unknown field is never "already saved": the write drops it', () {
      final withExtra = {...stored(base), 'note': 'old'};
      expect(
        decideReplace(storedData: withExtra, base: base, target: base),
        CarReplaceDecision.write,
      );
    });

    test('a year stored as 2019.0 is never "already saved": the write fixes '
        'it', () {
      final asDouble = {...stored(base), 'year': 2019.0};
      expect(
        decideReplace(storedData: asDouble, base: base, target: base),
        CarReplaceDecision.write,
      );
    });

    test('a price stored as the whole number 45 is the same as 45.0', () {
      final whole = {...stored(base), 'pricePerDay': 45};
      expect(
        decideReplace(storedData: whole, base: base, target: base),
        CarReplaceDecision.alreadySaved,
      );
    });
  });

  group('sameCarDocument', () {
    test('photos in another order are not the same', () {
      final a = stored(car())..['photos'] = ['https://a.b/1', 'https://a.b/2'];
      final b = stored(car())..['photos'] = ['https://a.b/2', 'https://a.b/1'];
      expect(sameCarDocument(a, b), false);
      expect(sameCarDocument(a, Map.of(a)), true);
    });

    test('a missing key is not the same', () {
      final full = stored(car());
      final less = Map.of(full)..remove('engineSize');
      expect(sameCarDocument(less, full), false);
      expect(sameCarDocument(full, less), false);
    });
  });

  group('decideSetActive', () {
    test('no stored document: car missing', () {
      expect(
        decideSetActive(storedData: null, active: false),
        CarActiveDecision.carMissing,
      );
    });

    test('the same bool: nothing is written', () {
      expect(
        decideSetActive(storedData: {'active': true}, active: true),
        CarActiveDecision.alreadySet,
      );
      expect(
        decideSetActive(storedData: {'active': false}, active: false),
        CarActiveDecision.alreadySet,
      );
    });

    test('the other bool: write', () {
      expect(
        decideSetActive(storedData: {'active': true}, active: false),
        CarActiveDecision.write,
      );
    });

    test('no "active" field, or another type in it: write', () {
      expect(
        decideSetActive(storedData: {'brand': 'Lada'}, active: true),
        CarActiveDecision.write,
      );
      expect(
        decideSetActive(storedData: {'active': 'true'}, active: true),
        CarActiveDecision.write,
      );
      expect(
        decideSetActive(storedData: {'active': null}, active: false),
        CarActiveDecision.write,
      );
    });

    test('decided from the raw document: an old car that is not a valid Car '
        'still gets its write', () {
      expect(
        decideSetActive(
          storedData: {'brand': 'Lada', 'active': true},
          active: false,
        ),
        CarActiveDecision.write,
      );
    });
  });
}
