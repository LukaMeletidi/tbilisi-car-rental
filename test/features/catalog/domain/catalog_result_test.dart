import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/catalog_result.dart';

Car car({
  required String id,
  double pricePerDay = 50,
  FuelType fuelType = FuelType.petrol,
}) {
  return Car(
    id: id,
    brand: 'Brand',
    model: 'Model',
    year: 2020,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: fuelType,
    seats: 5,
    engineSize: 2.0,
    pricePerDay: pricePerDay,
    description: const LocalizedText(),
    photos: const [],
    active: true,
  );
}

void main() {
  group('buildCatalog', () {
    final cars = [
      car(id: 'mid', pricePerDay: 60, fuelType: FuelType.diesel),
      car(id: 'high', pricePerDay: 90),
      car(id: 'low', pricePerDay: 30, fuelType: FuelType.diesel),
    ];

    test('without a filter returns every car, cheapest first', () {
      final result = buildCatalog(cars);
      expect(result.cars.map((car) => car.id), ['low', 'mid', 'high']);
      expect(result.totalActive, 3);
    });

    test('with a filter returns the matching cars, cheapest first', () {
      final result = buildCatalog(
        cars,
        filter: const CarFilter(fuelType: FuelType.diesel),
      );
      expect(result.cars.map((car) => car.id), ['low', 'mid']);
      expect(result.totalActive, 3);
    });

    test('no match keeps the count of all active cars', () {
      final result = buildCatalog(
        cars,
        filter: const CarFilter(fuelType: FuelType.electric),
      );
      expect(result.cars, isEmpty);
      expect(result.totalActive, 3);
    });

    test('no cars at all gives an empty result and a count of 0', () {
      final result = buildCatalog([]);
      expect(result.cars, isEmpty);
      expect(result.totalActive, 0);
    });
  });
}
