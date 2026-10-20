import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/home/domain/home_popular.dart';

/// A made-up car.
Car car(
  String id, {
  String brand = 'Brand',
  String model = 'Model',
  double price = 40,
  bool active = true,
  bool popular = true,
}) => Car(
  id: id,
  brand: brand,
  model: model,
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: price,
  description: const LocalizedText(en: 'A made-up car.'),
  photos: const [],
  active: active,
  popular: popular,
);

List<String> ids(List<Car> cars) => [for (final car in cars) car.id];

void main() {
  test('only visible cars that are marked', () {
    final cars = [
      car('a'),
      car('hidden', active: false),
      car('plain', popular: false),
      car('b', price: 50),
    ];
    expect(ids(selectHomePopularCars(cars)), ['a', 'b']);
  });

  test('at most homePopularMax, the first ones in catalog order', () {
    final cars = [for (var i = 0; i < 5; i++) car('car-$i', price: 100.0 - i)];
    expect(homePopularMax, 3);
    expect(ids(selectHomePopularCars(cars)), ['car-4', 'car-3', 'car-2']);
  });

  test('the catalog order: cheapest first, then brand and model', () {
    final cars = [
      car('c', brand: 'Gamma', model: 'Three', price: 60),
      car('a', brand: 'beta', model: 'Two', price: 30),
      car('b', brand: 'Alpha', model: 'One', price: 30),
    ];
    final popular = selectHomePopularCars(cars);
    expect(ids(popular), ['b', 'a', 'c']);
    expect(ids(popular), ids(sortCarsByPrice(cars)));
  });

  test('the same price, brand and model: ordered by ID, so it is stable', () {
    final cars = [car('z'), car('m'), car('a')];
    expect(ids(selectHomePopularCars(cars)), ['a', 'm', 'z']);
    expect(ids(selectHomePopularCars(cars.reversed.toList())), ['a', 'm', 'z']);
  });

  test('no car, or none marked: empty', () {
    expect(selectHomePopularCars(const []), isEmpty);
    expect(selectHomePopularCars([car('a', popular: false)]), isEmpty);
  });

  test('the input is not changed and the result cannot be changed', () {
    final cars = [car('b', price: 50), car('a')];
    final popular = selectHomePopularCars(cars);
    expect(ids(cars), ['b', 'a']);
    expect(() => popular.add(car('x')), throwsUnsupportedError);
  });
}
