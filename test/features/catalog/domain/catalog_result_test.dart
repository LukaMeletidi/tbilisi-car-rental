import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/catalog_result.dart';

Car car({
  required String id,
  String brand = 'Brand',
  String model = 'Model',
  double pricePerDay = 50,
  FuelType fuelType = FuelType.petrol,
}) {
  return Car(
    id: id,
    brand: brand,
    model: model,
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

    test('with a search query returns the matching cars, cheapest first', () {
      final fleet = [
        car(id: 'prius', brand: 'Toyota', model: 'Prius', pricePerDay: 45),
        car(id: 'yaris', brand: 'Toyota', model: 'Yaris', pricePerDay: 30),
        car(id: 'fit', brand: 'Honda', model: 'Fit', pricePerDay: 25),
      ];
      final result = buildCatalog(fleet, searchQuery: 'toyota');
      expect(result.cars.map((car) => car.id), ['yaris', 'prius']);
      expect(result.totalActive, 3);
    });

    test('the search and the filter must both match', () {
      final fleet = [
        car(id: 'prius', brand: 'Toyota', model: 'Prius'),
        car(
          id: 'hilux',
          brand: 'Toyota',
          model: 'Hilux',
          fuelType: FuelType.diesel,
        ),
        car(id: 'octavia', brand: 'Skoda', fuelType: FuelType.diesel),
      ];
      final result = buildCatalog(
        fleet,
        filter: const CarFilter(fuelType: FuelType.diesel),
        searchQuery: 'toyota',
      );
      expect(result.cars.map((car) => car.id), ['hilux']);
      expect(result.totalActive, 3);
    });

    test('a search with no match keeps the count of all active cars', () {
      final result = buildCatalog(cars, searchQuery: 'zzz');
      expect(result.cars, isEmpty);
      expect(result.totalActive, 3);
    });

    test('a blank search query returns every car', () {
      final result = buildCatalog(cars, searchQuery: '   ');
      expect(result.cars.map((car) => car.id), ['low', 'mid', 'high']);
    });
  });
}
