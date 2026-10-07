import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';

void main() {
  test('the offset is 4 hours', () {
    expect(tbilisiUtcOffset, const Duration(hours: 4));
  });

  group('TbilisiDateTime.fromUtc', () {
    test('adds 4 hours in winter', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 1, 10, 14)),
        TbilisiDateTime(2026, 1, 10, 18),
      );
    });

    test('adds the same 4 hours in summer (no daylight saving)', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 7, 10, 14)),
        TbilisiDateTime(2026, 7, 10, 18),
      );
    });

    test('crosses midnight: 21:30 UTC is 01:30 the next day', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 1, 10, 21, 30)),
        TbilisiDateTime(2026, 1, 11, 1, 30),
      );
    });

    test('crosses the end of a month', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 1, 31, 22)),
        TbilisiDateTime(2026, 2, 1, 2),
      );
    });

    test('crosses the end of a year', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 12, 31, 20)),
        TbilisiDateTime(2027, 1, 1),
      );
    });

    test('lands on 29 February in a leap year', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2028, 2, 28, 21)),
        TbilisiDateTime(2028, 2, 29, 1),
      );
    });

    test('goes to 1 March in a year without a leap day', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 2, 28, 21)),
        TbilisiDateTime(2026, 3, 1, 1),
      );
    });

    test('drops seconds', () {
      expect(
        TbilisiDateTime.fromUtc(DateTime.utc(2026, 1, 10, 14, 5, 59)),
        TbilisiDateTime(2026, 1, 10, 18, 5),
      );
    });

    test('throws for a date that is not UTC', () {
      expect(
        () => TbilisiDateTime.fromUtc(DateTime(2026, 1, 10, 14)),
        throwsArgumentError,
      );
    });
  });

  group('TbilisiDateTime.toUtc', () {
    test('subtracts 4 hours in winter and in summer', () {
      expect(
        TbilisiDateTime(2026, 1, 10, 18).toUtc(),
        DateTime.utc(2026, 1, 10, 14),
      );
      expect(
        TbilisiDateTime(2026, 7, 10, 18).toUtc(),
        DateTime.utc(2026, 7, 10, 14),
      );
    });

    test('returns a UTC date', () {
      expect(TbilisiDateTime(2026, 1, 10, 18).toUtc().isUtc, true);
    });

    test('crosses midnight: 00:30 is 20:30 UTC the day before', () {
      expect(
        TbilisiDateTime(2026, 1, 11, 0, 30).toUtc(),
        DateTime.utc(2026, 1, 10, 20, 30),
      );
    });

    test('crosses the start of a month', () {
      expect(
        TbilisiDateTime(2026, 3, 1, 1).toUtc(),
        DateTime.utc(2026, 2, 28, 21),
      );
    });

    test('crosses the start of a year', () {
      expect(
        TbilisiDateTime(2027, 1, 1, 3, 59).toUtc(),
        DateTime.utc(2026, 12, 31, 23, 59),
      );
    });

    test('goes back to 29 February in a leap year', () {
      expect(
        TbilisiDateTime(2028, 3, 1, 2).toUtc(),
        DateTime.utc(2028, 2, 29, 22),
      );
    });
  });

  group('round trips', () {
    test('UTC to Tbilisi and back gives the same moment', () {
      // 60 whole-minute moments spread over about six years.
      var moment = DateTime.utc(2024, 1, 1);
      for (var i = 0; i < 60; i++) {
        expect(
          TbilisiDateTime.fromUtc(moment).toUtc(),
          moment,
          reason: 'moment $moment',
        );
        moment = moment.add(const Duration(days: 37, hours: 5, minutes: 17));
      }
    });

    test('Tbilisi to UTC and back gives the same date and time', () {
      final samples = [
        TbilisiDateTime(2026, 1, 1),
        TbilisiDateTime(2026, 1, 1, 3, 59),
        TbilisiDateTime(2026, 6, 15, 12, 30),
        TbilisiDateTime(2026, 12, 31, 23, 59),
        TbilisiDateTime(2028, 2, 29, 0, 1),
      ];
      for (final sample in samples) {
        expect(TbilisiDateTime.fromUtc(sample.toUtc()), sample);
      }
    });
  });

  group('TbilisiDateTime, the picked values', () {
    test('keeps the values as given', () {
      final picked = TbilisiDateTime(2026, 5, 9, 7, 45);
      expect(picked.year, 2026);
      expect(picked.month, 5);
      expect(picked.day, 9);
      expect(picked.hour, 7);
      expect(picked.minute, 45);
    });

    test('hour and minute default to 00:00', () {
      expect(TbilisiDateTime(2026, 5, 9), TbilisiDateTime(2026, 5, 9, 0, 0));
    });

    test('throws for a date or time that does not exist', () {
      expect(() => TbilisiDateTime(2026, 2, 30), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 2, 29), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 13, 1), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 0, 1), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 1, 10, 24), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 1, 10, 12, 60), throwsArgumentError);
      expect(() => TbilisiDateTime(2026, 1, 10, -1), throwsArgumentError);
    });

    test('accepts 29 February in a leap year', () {
      expect(TbilisiDateTime(2028, 2, 29).day, 29);
    });

    test('equal values are equal and have the same hash code', () {
      final a = TbilisiDateTime(2026, 1, 11, 1, 30);
      final b = TbilisiDateTime(2026, 1, 11, 1, 30);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == TbilisiDateTime(2026, 1, 11, 1, 31), false);
    });

    test('compareTo orders by time', () {
      final earlier = TbilisiDateTime(2026, 1, 10, 23, 59);
      final later = TbilisiDateTime(2026, 1, 11);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(earlier), greaterThan(0));
      expect(earlier.compareTo(earlier), 0);
    });

    test('toString is readable', () {
      expect(
        TbilisiDateTime(2026, 1, 11, 1, 30).toString(),
        '2026-01-11 01:30 (Tbilisi)',
      );
    });
  });
}
