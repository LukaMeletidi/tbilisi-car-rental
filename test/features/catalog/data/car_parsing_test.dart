import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';

Map<String, dynamic> carData({String brand = 'Toyota'}) => {
  'brand': brand,
  'model': 'Prius',
  'year': 2019,
  'drivetrain': 'fwd',
  'transmission': 'automatic',
  'fuelType': 'hybrid',
  'seats': 5,
  'pricePerDay': 45,
  'active': true,
};

void main() {
  group('parseCars', () {
    test('turns every valid document into a car, in the same order', () {
      final cars = parseCars([
        (id: 'a', data: carData(brand: 'Toyota')),
        (id: 'b', data: carData(brand: 'Honda')),
      ]);

      expect(cars.map((car) => car.id), ['a', 'b']);
      expect(cars.map((car) => car.brand), ['Toyota', 'Honda']);
    });

    test('skips a bad document and keeps the others', () {
      final cars = parseCars([
        (id: 'good-1', data: carData()),
        (id: 'bad', data: carData()..['transmission'] = 'Automatic'),
        (id: 'good-2', data: carData()),
      ]);

      expect(cars.map((car) => car.id), ['good-1', 'good-2']);
    });

    test('reports each skipped document with its id, error and stack trace', () {
      final errors = <String, Object>{};
      final stackTraces = <String, StackTrace>{};

      parseCars(
        [
          (id: 'good', data: carData()),
          (id: 'no-seats', data: carData()..remove('seats')),
          (id: 'bad-price', data: carData()..['pricePerDay'] = 0),
        ],
        onSkipped: (id, error, stackTrace) {
          errors[id] = error;
          stackTraces[id] = stackTrace;
        },
      );

      expect(errors.keys, ['no-seats', 'bad-price']);
      expect(errors['no-seats'], isA<FormatException>());
      expect(errors['bad-price'], isA<FormatException>());
      expect(stackTraces.keys, ['no-seats', 'bad-price']);
      expect(stackTraces['no-seats'].toString(), isNotEmpty);
    });

    test('does not report anything when every document is valid', () {
      var skippedCount = 0;

      parseCars([
        (id: 'a', data: carData()),
      ], onSkipped: (id, error, stackTrace) => skippedCount++);

      expect(skippedCount, 0);
    });

    test('returns an empty list for an empty input', () {
      final skippedIds = <String>[];

      final cars = parseCars(
        [],
        onSkipped: (id, error, stackTrace) => skippedIds.add(id),
      );

      expect(cars, isEmpty);
      expect(skippedIds, isEmpty);
    });

    test('returns an empty list when every document is bad', () {
      final skippedIds = <String>[];

      final cars = parseCars(
        [
          (id: 'empty', data: <String, dynamic>{}),
          (id: 'blank-brand', data: carData()..['brand'] = '   '),
        ],
        onSkipped: (id, error, stackTrace) => skippedIds.add(id),
      );

      expect(cars, isEmpty);
      expect(skippedIds, ['empty', 'blank-brand']);
    });
  });
}
