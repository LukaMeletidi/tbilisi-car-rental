import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// Pickup on the 10th at 18:00 (UTC), as in the plan's examples.
final pickup = DateTime.utc(2026, 1, 10, 18);

DateTime day(int dayOfMonth, int hour, [int minute = 0, int second = 0]) =>
    DateTime.utc(2026, 1, dayOfMonth, hour, minute, second);

void main() {
  group('rentalDays, the cases from the plan', () {
    test('return on the 15th at 20:00 gives 5 days', () {
      expect(rentalDays(pickup: pickup, dropoff: day(15, 20)), 5);
    });

    test('return on the 15th at 20:01 gives 6 days', () {
      expect(rentalDays(pickup: pickup, dropoff: day(15, 20, 1)), 6);
    });

    test('return on the 16th at 20:01 gives 7 days', () {
      expect(rentalDays(pickup: pickup, dropoff: day(16, 20, 1)), 7);
    });
  });

  group('rentalDays, minimum and boundaries', () {
    test('a short rental is charged as 1 day', () {
      expect(rentalDays(pickup: pickup, dropoff: day(10, 18, 30)), 1);
      expect(rentalDays(pickup: pickup, dropoff: day(10, 21)), 1);
    });

    test('exactly the 2 hour grace period is 1 day', () {
      expect(rentalDays(pickup: pickup, dropoff: day(10, 20)), 1);
    });

    test('24 hours is 1 day', () {
      expect(rentalDays(pickup: pickup, dropoff: day(11, 18)), 1);
    });

    test('24 hours plus exactly 2 hours is still 1 day', () {
      expect(rentalDays(pickup: pickup, dropoff: day(11, 20)), 1);
    });

    test('one minute over the grace period starts the next day', () {
      expect(rentalDays(pickup: pickup, dropoff: day(11, 20, 1)), 2);
    });

    test('seconds are ignored', () {
      expect(rentalDays(pickup: pickup, dropoff: day(11, 20, 0, 30)), 1);
    });
  });

  group('rentalDays, invalid dates', () {
    test('throws when dropoff is not after pickup', () {
      expect(
        () => rentalDays(pickup: pickup, dropoff: pickup),
        throwsArgumentError,
      );
      expect(
        () => rentalDays(pickup: pickup, dropoff: day(10, 17)),
        throwsArgumentError,
      );
    });

    test('throws when a date is not UTC', () {
      final localPickup = DateTime(2026, 1, 10, 18);
      final localDropoff = DateTime(2026, 1, 15, 20);
      expect(
        () => rentalDays(pickup: localPickup, dropoff: day(15, 20)),
        throwsArgumentError,
      );
      expect(
        () => rentalDays(pickup: pickup, dropoff: localDropoff),
        throwsArgumentError,
      );
    });
  });

  group('calculateRentalPrice', () {
    const extraPrices = {
      Extra.snowChains: 5.0,
      Extra.childSeat: 4.0,
      Extra.infantSeat: 4.5,
      Extra.boosterSeat: 3.0,
    };

    test('total is days times the car price', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(15, 20),
        carPricePerDay: 45,
      );
      expect(price.days, 5);
      expect(price.totalCents, 22500);
      expect(price.total, 225.0);
    });

    test('selected extras are added per day', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(15, 20),
        carPricePerDay: 45,
        selectedExtras: {Extra.snowChains, Extra.infantSeat},
        extraPricesPerDay: extraPrices,
      );
      // 5 days * (45 + 5 + 4.50) = 272.50
      expect(price.totalCents, 27250);
      expect(price.total, 272.5);
    });

    test('extras that are not selected do not change the total', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(15, 20),
        carPricePerDay: 45,
        extraPricesPerDay: extraPrices,
      );
      expect(price.totalCents, 22500);
    });

    test('works in whole cents: 3 * 19.99 is exactly 59.97', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(13, 18),
        carPricePerDay: 19.99,
      );
      expect(price.days, 3);
      expect(price.totalCents, 5997);
      expect(price.total, 59.97);
    });

    test('works in whole cents: 0.10 + 0.20 is exactly 0.30', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(10, 20),
        carPricePerDay: 0.10,
        selectedExtras: {Extra.childSeat},
        extraPricesPerDay: {Extra.childSeat: 0.20},
      );
      expect(price.totalCents, 30);
      expect(price.total, 0.3);
    });

    test('7 days is a normal price', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(17, 18),
        carPricePerDay: 45,
      );
      expect(price.days, 7);
      expect(price.isIndividualPrice, false);
      expect(price.totalCents, 31500);
    });

    test('8 days is flagged as an individual price, with an estimate', () {
      final price = calculateRentalPrice(
        pickup: pickup,
        dropoff: day(18, 18),
        carPricePerDay: 45,
      );
      expect(price.days, 8);
      expect(price.isIndividualPrice, true);
      expect(price.totalCents, 36000);
    });

    test('throws when the dates are invalid', () {
      expect(
        () => calculateRentalPrice(
          pickup: pickup,
          dropoff: pickup,
          carPricePerDay: 45,
        ),
        throwsArgumentError,
      );
    });

    test('throws when a selected extra has no price', () {
      expect(
        () => calculateRentalPrice(
          pickup: pickup,
          dropoff: day(15, 20),
          carPricePerDay: 45,
          selectedExtras: {Extra.boosterSeat},
          extraPricesPerDay: {Extra.childSeat: 4.0},
        ),
        throwsArgumentError,
      );
    });

    test('throws when a price is negative or not a number', () {
      expect(
        () => calculateRentalPrice(
          pickup: pickup,
          dropoff: day(15, 20),
          carPricePerDay: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateRentalPrice(
          pickup: pickup,
          dropoff: day(15, 20),
          carPricePerDay: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateRentalPrice(
          pickup: pickup,
          dropoff: day(15, 20),
          carPricePerDay: 45,
          selectedExtras: {Extra.childSeat},
          extraPricesPerDay: {Extra.childSeat: -4.0},
        ),
        throwsArgumentError,
      );
    });
  });

  test('RentalPrice values with the same numbers are equal', () {
    const a = RentalPrice(days: 3, totalCents: 5997);
    const b = RentalPrice(days: 3, totalCents: 5997);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const RentalPrice(days: 4, totalCents: 5997), false);
  });
}
