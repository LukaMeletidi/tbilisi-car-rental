import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';

Car car({
  String id = 'id',
  String brand = 'Brand',
  String model = 'Model',
  int seats = 5,
  FuelType fuelType = FuelType.petrol,
  Transmission transmission = Transmission.automatic,
  double pricePerDay = 50,
}) {
  return Car(
    id: id,
    brand: brand,
    model: model,
    year: 2020,
    drivetrain: Drivetrain.fwd,
    transmission: transmission,
    fuelType: fuelType,
    seats: seats,
    engineSize: 2.0,
    pricePerDay: pricePerDay,
    description: const LocalizedText(),
    photos: const [],
    active: true,
  );
}

void main() {
  group('SeatsFilter.matches', () {
    test('2, 4 and 5 match only their exact number', () {
      expect(SeatsFilter.two.matches(2), true);
      expect(SeatsFilter.two.matches(4), false);
      expect(SeatsFilter.four.matches(4), true);
      expect(SeatsFilter.four.matches(5), false);
      expect(SeatsFilter.five.matches(5), true);
      expect(SeatsFilter.five.matches(7), false);
    });

    test('7+ matches 7 or more seats', () {
      expect(SeatsFilter.sevenPlus.matches(7), true);
      expect(SeatsFilter.sevenPlus.matches(8), true);
      expect(SeatsFilter.sevenPlus.matches(9), true);
      expect(SeatsFilter.sevenPlus.matches(6), false);
      expect(SeatsFilter.sevenPlus.matches(5), false);
    });

    test('cars with 3 or 6 seats match only Any', () {
      for (final seats in [3, 6]) {
        expect(SeatsFilter.any.matches(seats), true);
        expect(SeatsFilter.two.matches(seats), false);
        expect(SeatsFilter.four.matches(seats), false);
        expect(SeatsFilter.five.matches(seats), false);
        expect(SeatsFilter.sevenPlus.matches(seats), false);
      }
    });

    test('Any matches every number of seats', () {
      for (final seats in [2, 3, 4, 5, 6, 7, 9]) {
        expect(SeatsFilter.any.matches(seats), true);
      }
    });
  });

  group('CarFilter.matches', () {
    test('the default filter matches every car', () {
      const filter = CarFilter();
      expect(filter.matches(car(seats: 2, fuelType: FuelType.electric)), true);
      expect(
        filter.matches(car(seats: 9, transmission: Transmission.manual)),
        true,
      );
    });

    test('fuel type matches only the same fuel type', () {
      const filter = CarFilter(fuelType: FuelType.diesel);
      expect(filter.matches(car(fuelType: FuelType.diesel)), true);
      expect(filter.matches(car(fuelType: FuelType.petrol)), false);
      expect(filter.matches(car(fuelType: FuelType.hybrid)), false);
      expect(filter.matches(car(fuelType: FuelType.electric)), false);
    });

    test('transmission matches only the same transmission', () {
      const filter = CarFilter(transmission: Transmission.manual);
      expect(filter.matches(car(transmission: Transmission.manual)), true);
      expect(filter.matches(car(transmission: Transmission.automatic)), false);
    });

    test('all three filters must match together', () {
      const filter = CarFilter(
        seats: SeatsFilter.sevenPlus,
        fuelType: FuelType.diesel,
        transmission: Transmission.automatic,
      );
      expect(filter.matches(car(seats: 7, fuelType: FuelType.diesel)), true);
      expect(filter.matches(car(seats: 5, fuelType: FuelType.diesel)), false);
      expect(filter.matches(car(seats: 7, fuelType: FuelType.petrol)), false);
      expect(
        filter.matches(
          car(
            seats: 7,
            fuelType: FuelType.diesel,
            transmission: Transmission.manual,
          ),
        ),
        false,
      );
    });
  });

  group('CarFilter.activeCount', () {
    test('counts the filters that are set', () {
      expect(const CarFilter().activeCount, 0);
      expect(const CarFilter(seats: SeatsFilter.five).activeCount, 1);
      expect(
        const CarFilter(
          seats: SeatsFilter.five,
          fuelType: FuelType.petrol,
        ).activeCount,
        2,
      );
      expect(
        const CarFilter(
          seats: SeatsFilter.two,
          fuelType: FuelType.electric,
          transmission: Transmission.automatic,
        ).activeCount,
        3,
      );
    });
  });

  group('CarFilter equality', () {
    test('filters with the same choices are equal', () {
      const a = CarFilter(seats: SeatsFilter.four, fuelType: FuelType.hybrid);
      const b = CarFilter(seats: SeatsFilter.four, fuelType: FuelType.hybrid);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const CarFilter(seats: SeatsFilter.four), false);
    });
  });

  group('applyCarFilter', () {
    final cars = [
      car(id: 'a', seats: 5, fuelType: FuelType.petrol),
      car(id: 'b', seats: 7, fuelType: FuelType.diesel),
      car(id: 'c', seats: 5, fuelType: FuelType.diesel),
    ];

    test('the default filter returns every car', () {
      expect(applyCarFilter(cars, const CarFilter()), cars);
    });

    test('returns only matching cars, in the original order', () {
      final result = applyCarFilter(
        cars,
        const CarFilter(fuelType: FuelType.diesel),
      );
      expect(result.map((car) => car.id), ['b', 'c']);
    });

    test('returns an empty list when nothing matches', () {
      final result = applyCarFilter(
        cars,
        const CarFilter(fuelType: FuelType.electric),
      );
      expect(result, isEmpty);
    });

    test('an empty list stays empty', () {
      expect(applyCarFilter([], const CarFilter()), isEmpty);
    });
  });

  group('sortCarsByPrice', () {
    test('puts the cheapest car first', () {
      final sorted = sortCarsByPrice([
        car(id: 'mid', pricePerDay: 60),
        car(id: 'high', pricePerDay: 120.5),
        car(id: 'low', pricePerDay: 35),
      ]);
      expect(sorted.map((car) => car.id), ['low', 'mid', 'high']);
    });

    test('orders equal prices by brand, then model', () {
      final sorted = sortCarsByPrice([
        car(id: '3', brand: 'Toyota', model: 'Prius'),
        car(id: '1', brand: 'Honda', model: 'Fit'),
        car(id: '2', brand: 'Toyota', model: 'Camry'),
      ]);
      expect(sorted.map((car) => car.id), ['1', '2', '3']);
    });

    test('ignores letter case when ordering equal prices', () {
      final sorted = sortCarsByPrice([
        car(id: 'toyota', brand: 'Toyota'),
        car(id: 'bmw', brand: 'bmw'),
        car(id: 'audi', brand: 'Audi'),
      ]);
      expect(sorted.map((car) => car.id), ['audi', 'bmw', 'toyota']);

      final sameBrand = sortCarsByPrice([
        car(id: 'x5', brand: 'BMW', model: 'x5'),
        car(id: 'i3', brand: 'bmw', model: 'I3'),
      ]);
      expect(sameBrand.map((car) => car.id), ['i3', 'x5']);
    });

    test('does not change the original list', () {
      final cars = [
        car(id: 'b', pricePerDay: 80),
        car(id: 'a', pricePerDay: 40),
      ];
      sortCarsByPrice(cars);
      expect(cars.map((car) => car.id), ['b', 'a']);
    });

    test('an empty list stays empty', () {
      expect(sortCarsByPrice([]), isEmpty);
    });
  });

  group('CarFilter with... methods', () {
    const full = CarFilter(
      seats: SeatsFilter.five,
      fuelType: FuelType.diesel,
      transmission: Transmission.manual,
    );

    test('withSeats changes only the seats', () {
      expect(
        full.withSeats(SeatsFilter.two),
        const CarFilter(
          seats: SeatsFilter.two,
          fuelType: FuelType.diesel,
          transmission: Transmission.manual,
        ),
      );
    });

    test('withFuelType changes only the fuel type', () {
      expect(
        full.withFuelType(FuelType.electric),
        const CarFilter(
          seats: SeatsFilter.five,
          fuelType: FuelType.electric,
          transmission: Transmission.manual,
        ),
      );
    });

    test('withTransmission changes only the transmission', () {
      expect(
        full.withTransmission(Transmission.automatic),
        const CarFilter(
          seats: SeatsFilter.five,
          fuelType: FuelType.diesel,
          transmission: Transmission.automatic,
        ),
      );
    });

    test('fuel type and transmission can be set back to Any', () {
      expect(
        full.withFuelType(null),
        const CarFilter(
          seats: SeatsFilter.five,
          transmission: Transmission.manual,
        ),
      );
      expect(
        full.withTransmission(null),
        const CarFilter(seats: SeatsFilter.five, fuelType: FuelType.diesel),
      );
    });

    test('the original filter is not changed', () {
      full.withSeats(SeatsFilter.two).withFuelType(null);
      expect(full.seats, SeatsFilter.five);
      expect(full.fuelType, FuelType.diesel);
    });
  });
}
