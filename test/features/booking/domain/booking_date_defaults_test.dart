import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_date_defaults.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

void main() {
  /// 14:20 in Tbilisi on 10 January 2026.
  final afternoon = DateTime.utc(2026, 1, 10, 10, 20);

  group('today in Tbilisi', () {
    test('is the UTC date during most of the day', () {
      expect(tbilisiNow(afternoon), TbilisiDateTime(2026, 1, 10, 14, 20));
      expect(tbilisiToday(afternoon), TbilisiDateTime(2026, 1, 10));
    });

    test('is already the next day from 20:00 UTC', () {
      expect(
        tbilisiToday(DateTime.utc(2026, 1, 10, 19, 59)),
        TbilisiDateTime(2026, 1, 10),
      );
      expect(
        tbilisiToday(DateTime.utc(2026, 1, 10, 20)),
        TbilisiDateTime(2026, 1, 11),
      );
      expect(
        tbilisiToday(DateTime.utc(2026, 1, 10, 20, 30)),
        TbilisiDateTime(2026, 1, 11),
      );
    });

    test('crosses the end of a year', () {
      expect(
        tbilisiToday(DateTime.utc(2025, 12, 31, 21)),
        TbilisiDateTime(2026, 1, 1),
      );
    });

    test('refuses a moment that is not UTC', () {
      expect(() => tbilisiToday(DateTime(2026, 1, 10)), throwsArgumentError);
    });
  });

  group('the pickup picker', () {
    test('the earliest day is today in Tbilisi', () {
      expect(earliestPickupDay(afternoon), TbilisiDateTime(2026, 1, 10));
      expect(
        earliestPickupDay(DateTime.utc(2026, 1, 10, 20, 30)),
        TbilisiDateTime(2026, 1, 11),
      );
    });

    test('the latest day is the same date two years later', () {
      expect(bookingPickupPickerYearsAhead, 2);
      expect(latestPickupDay(afternoon), TbilisiDateTime(2028, 1, 10));
    });

    test('29 February becomes 1 March of a year without it', () {
      expect(
        latestPickupDay(DateTime.utc(2028, 2, 29, 10)),
        TbilisiDateTime(2030, 3, 1),
      );
    });

    test('opens on the next full hour', () {
      expect(defaultPickup(afternoon), TbilisiDateTime(2026, 1, 10, 15));
    });

    test('at a full hour it opens on the hour after it', () {
      expect(
        defaultPickup(DateTime.utc(2026, 1, 10, 10)),
        TbilisiDateTime(2026, 1, 10, 15),
      );
    });

    test('late in the evening it opens on the next day at 00:00', () {
      // 23:30 in Tbilisi.
      expect(
        defaultPickup(DateTime.utc(2026, 1, 10, 19, 30)),
        TbilisiDateTime(2026, 1, 11),
      );
    });
  });

  group('the dropoff picker', () {
    final pickup = TbilisiDateTime(2026, 3, 5, 18, 30);

    test('the earliest day is the pickup day', () {
      expect(
        earliestDropoffDay(afternoon, pickup: pickup),
        TbilisiDateTime(2026, 3, 5),
      );
    });

    test('without a pickup the earliest day is today', () {
      expect(earliestDropoffDay(afternoon), TbilisiDateTime(2026, 1, 10));
    });

    test('the latest day is 365 days after the pickup day', () {
      expect(bookingMaxRentalDays, 365);
      expect(
        latestDropoffDay(afternoon, pickup: pickup),
        TbilisiDateTime(2027, 3, 5),
      );
    });

    test('365 days across a leap day ends one date earlier', () {
      expect(
        latestDropoffDay(afternoon, pickup: TbilisiDateTime(2027, 6, 1, 9)),
        TbilisiDateTime(2028, 5, 31),
      );
    });

    test('without a pickup the latest day follows the last pickup day', () {
      expect(latestDropoffDay(afternoon), TbilisiDateTime(2029, 1, 9));
    });

    test('opens one day after the pickup at the same time', () {
      expect(
        defaultDropoff(afternoon, pickup: pickup),
        TbilisiDateTime(2026, 3, 6, 18, 30),
      );
    });

    test('without a pickup it opens one day after the pickup default', () {
      expect(defaultDropoff(afternoon), TbilisiDateTime(2026, 1, 11, 15));
    });
  });
}
