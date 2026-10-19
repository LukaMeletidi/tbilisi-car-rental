import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';

final now = DateTime.utc(2026, 10, 14, 12);

/// A complete stored car. All values are made up.
Car storedCar({
  double? engineSize = 1.8,
  double pricePerDay = 45.5,
  bool popular = false,
}) => Car(
  id: 'car-1',
  brand: 'Honda',
  model: 'Civic',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: engineSize,
  pricePerDay: pricePerDay,
  description: const LocalizedText(ka: 'ქართული', ru: 'Русский', en: 'English'),
  photos: const ['https://photos.example.com/car-1.jpg'],
  active: true,
  popular: popular,
);

List<String> requiredFields() => [
  for (final field in carFields)
    if (!carOptionalFields.contains(field)) field,
];

void main() {
  group('CarDraft.fromCar', () {
    test('a full car', () {
      final draft = CarDraft.fromCar(storedCar());
      expect(draft.brand, 'Honda');
      expect(draft.model, 'Civic');
      expect(draft.year, '2019');
      expect(draft.drivetrain, Drivetrain.fwd);
      expect(draft.transmission, Transmission.automatic);
      expect(draft.fuelType, FuelType.petrol);
      expect(draft.seats, '5');
      expect(draft.engineSize, '1.8');
      expect(draft.pricePerDay, '45.5');
      expect(draft.descriptionKa, 'ქართული');
      expect(draft.descriptionRu, 'Русский');
      expect(draft.descriptionEn, 'English');
      expect(draft.photos, ['https://photos.example.com/car-1.jpg']);
      expect(draft.active, true);
    });

    test('an old car without description and photos: empty fields', () {
      final old = Car.fromMap('old-car', {
        'brand': 'Lada',
        'model': 'Niva',
        'year': 2015,
        'drivetrain': 'awd',
        'transmission': 'manual',
        'fuelType': 'petrol',
        'seats': 4,
        'pricePerDay': 30,
        'active': false,
      });
      final draft = CarDraft.fromCar(old);
      expect(draft.descriptionKa, '');
      expect(draft.descriptionRu, '');
      expect(draft.descriptionEn, '');
      expect(draft.photos, isEmpty);
      expect(draft.pricePerDay, '30');
      expect(draft.active, false);
    });

    test('no engine size: an empty field', () {
      expect(CarDraft.fromCar(storedCar(engineSize: null)).engineSize, '');
    });

    test('a hand-typed price with three decimals is shown in full', () {
      final draft = CarDraft.fromCar(storedCar(pricePerDay: 45.555));
      expect(draft.pricePerDay, '45.555');
    });
  });

  test('a new draft starts hidden and empty', () {
    const draft = CarDraft();
    expect(draft.active, false);
    expect(draft.photos, isEmpty);
    expect(draft.drivetrain, isNull);
  });

  test('copyWith changes only what it is given; equality', () {
    final draft = CarDraft.fromCar(storedCar());
    final changed = draft.copyWith(pricePerDay: '50');
    expect(changed.pricePerDay, '50');
    expect(changed.brand, draft.brand);
    expect(changed, isNot(draft));
    expect(draft.copyWith(), draft);
    expect(draft.copyWith().hashCode, draft.hashCode);
    expect(
      draft.copyWith(photos: ['https://photos.example.com/car-1.jpg']),
      draft,
    );
    expect(draft.copyWith(photos: const []), isNot(draft));
  });

  group('carFromDraft', () {
    const draft = CarDraft(
      brand: ' Honda ',
      model: 'Civic ',
      year: ' 2019',
      drivetrain: Drivetrain.fwd,
      transmission: Transmission.automatic,
      fuelType: FuelType.petrol,
      seats: '5 ',
      engineSize: '1,8',
      pricePerDay: '45,5',
      descriptionKa: ' ქართული ',
      descriptionRu: 'Русский\n',
      descriptionEn: ' English',
      photos: [' https://photos.example.com/car-1.jpg '],
      active: true,
    );

    test('trims, parses, and keeps year and seats whole', () {
      final car = carFromDraft('car-1', draft, now: now);
      expect(car, storedCar());
      expect(car.year, isA<int>());
      expect(car.seats, isA<int>());
    });

    test('an empty engine size is no engine size', () {
      final car = carFromDraft(
        'car-1',
        draft.copyWith(engineSize: ''),
        now: now,
      );
      expect(car.engineSize, isNull);
    });

    test('an invalid draft is refused, without its values in the error', () {
      expect(
        () => carFromDraft('car-1', draft.copyWith(seats: '10'), now: now),
        throwsA(
          isA<ArgumentError>().having(
            (error) => '$error',
            'text',
            isNot(contains('Honda')),
          ),
        ),
      );
    });

    test('round trip: car -> draft -> car is the same car', () {
      for (final car in [
        storedCar(),
        storedCar(engineSize: null),
        storedCar(pricePerDay: 2000),
      ]) {
        expect(carFromDraft(car.id, CarDraft.fromCar(car), now: now), car);
      }
    });
  });

  group('carDocument', () {
    test('exactly the fields the rules allow', () {
      // Every optional field set: an engine size and the popular mark.
      expect(
        carDocument(storedCar(popular: true)).keys,
        unorderedEquals(carFields),
      );
      expect(
        carDocument(storedCar(engineSize: null)).keys,
        unorderedEquals(requiredFields()),
      );
    });

    test('year and seats are whole numbers; price and engine size doubles', () {
      final document = carDocument(storedCar());
      expect(document['year'], isA<int>());
      expect(document['seats'], isA<int>());
      expect(document['pricePerDay'], isA<double>());
      expect(document['engineSize'], isA<double>());
      expect(document['description'], {
        'ka': 'ქართული',
        'ru': 'Русский',
        'en': 'English',
      });
    });
  });
}
