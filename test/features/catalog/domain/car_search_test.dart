import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_search.dart';

Car car(String id, String brand, String model) {
  return Car(
    id: id,
    brand: brand,
    model: model,
    year: 2020,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: FuelType.petrol,
    seats: 5,
    engineSize: 2.0,
    pricePerDay: 50,
    description: const LocalizedText(),
    photos: const [],
    active: true,
  );
}

void main() {
  final prius = car('prius', 'Toyota', 'Prius');
  final pajero = car('pajero', 'Mitsubishi', 'Pajero Sport');
  final mx5 = car('mx5', 'Mazda', 'MX-5');

  group('matchesCarSearch', () {
    test('an empty or blank query matches every car', () {
      expect(matchesCarSearch(prius, ''), true);
      expect(matchesCarSearch(prius, '   '), true);
    });

    test('matches the brand or the model', () {
      expect(matchesCarSearch(prius, 'toyota'), true);
      expect(matchesCarSearch(prius, 'prius'), true);
      expect(matchesCarSearch(prius, 'mazda'), false);
    });

    test('ignores letter case', () {
      expect(matchesCarSearch(prius, 'TOYOTA'), true);
      expect(matchesCarSearch(prius, 'pRiUs'), true);
    });

    test('matches a part of a word', () {
      expect(matchesCarSearch(prius, 'toy'), true);
      expect(matchesCarSearch(prius, 'riu'), true);
    });

    test('every word of the query must be found', () {
      expect(matchesCarSearch(prius, 'toyota pri'), true);
      expect(matchesCarSearch(prius, 'toyota camry'), false);
      expect(matchesCarSearch(pajero, 'mitsubishi sport'), true);
    });

    test('the order of the words does not matter', () {
      expect(matchesCarSearch(prius, 'prius toyota'), true);
    });

    test('ignores spaces around and between the words', () {
      expect(matchesCarSearch(prius, '  toyota   prius  '), true);
    });

    test('a hyphen is matched as typed', () {
      expect(matchesCarSearch(mx5, 'mx-5'), true);
      expect(matchesCarSearch(mx5, 'mx5'), false);
    });

    test('text in another alphabet finds nothing', () {
      expect(matchesCarSearch(prius, 'тойота'), false);
    });
  });

  group('applyCarSearch', () {
    final cars = [prius, pajero, mx5];

    test('an empty query returns every car', () {
      expect(applyCarSearch(cars, ''), cars);
    });

    test('a blank query returns every car', () {
      expect(applyCarSearch(cars, '   '), cars);
    });

    test('returns the matching cars in their original order', () {
      final result = applyCarSearch(cars, 'm');
      expect(result.map((car) => car.id), ['pajero', 'mx5']);
    });

    test('returns an empty list when nothing matches', () {
      expect(applyCarSearch(cars, 'zzz'), isEmpty);
    });
  });
}
