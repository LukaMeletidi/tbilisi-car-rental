import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// The UTC moment of a Tbilisi date and time.
DateTime tb(int month, int day, [int hour = 0, int minute = 0]) =>
    TbilisiDateTime(2026, month, day, hour, minute).toUtc();

/// A made-up confirmed booking (unless [status] says otherwise).
Booking booking(
  String id,
  DateTime pickup,
  DateTime dropoff, {
  String carId = 'car-1',
  String status = 'confirmed',
}) => Booking.fromMap(
  id,
  rawBooking(
    id,
    carId: carId,
    pickup: pickup,
    dropoff: dropoff,
    status: status,
  ).data,
);

/// A made-up car.
Car car(
  String id, {
  bool active = true,
  String brand = 'Toyota',
  String model = 'Prius',
  int year = 2019,
}) => Car(
  id: id,
  brand: brand,
  model: model,
  year: year,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.hybrid,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: const LocalizedText(),
  photos: const [],
  active: active,
);

/// The window of 16 Oct 2026 to 29 Oct 2026.
final window = CalendarWindow(CalendarDay(2026, 10, 16));

void main() {
  group('CalendarDay', () {
    test('19:59 UTC is still the same Tbilisi date, 20:00 UTC the next', () {
      expect(
        CalendarDay.ofUtc(DateTime.utc(2026, 10, 15, 19, 59)),
        CalendarDay(2026, 10, 15),
      );
      expect(
        CalendarDay.ofUtc(DateTime.utc(2026, 10, 15, 20)),
        CalendarDay(2026, 10, 16),
      );
    });

    test('a day starts at 20:00 UTC of the day before', () {
      expect(
        CalendarDay(2026, 10, 16).startUtc,
        DateTime.utc(2026, 10, 15, 20),
      );
      expect(CalendarDay(2027, 1, 1).startUtc, DateTime.utc(2026, 12, 31, 20));
    });

    test('plusDays crosses months, years and a leap day, also backwards', () {
      expect(CalendarDay(2026, 10, 30).plusDays(3), CalendarDay(2026, 11, 2));
      expect(CalendarDay(2026, 12, 28).plusDays(7), CalendarDay(2027, 1, 4));
      expect(CalendarDay(2028, 2, 28).plusDays(1), CalendarDay(2028, 2, 29));
      expect(CalendarDay(2027, 2, 28).plusDays(1), CalendarDay(2027, 3, 1));
      expect(CalendarDay(2027, 1, 3).plusDays(-7), CalendarDay(2026, 12, 27));
    });

    test('the weekday, 1 is Monday', () {
      expect(CalendarDay(2026, 10, 16).weekday, DateTime.friday);
      expect(CalendarDay(2026, 10, 19).weekday, DateTime.monday);
    });

    test('a date that does not exist throws', () {
      expect(() => CalendarDay(2026, 2, 30), throwsArgumentError);
    });

    test('a time that is not UTC throws', () {
      expect(
        () => CalendarDay.ofUtc(DateTime(2026, 10, 16, 12)),
        throwsArgumentError,
      );
    });

    test('equality, order and the test text', () {
      expect(CalendarDay(2026, 10, 16), CalendarDay(2026, 10, 16));
      expect(
        CalendarDay(2026, 10, 16).compareTo(CalendarDay(2026, 10, 17)),
        lessThan(0),
      );
      expect(CalendarDay(2026, 1, 5).toString(), '2026-01-05');
    });
  });

  group('CalendarWindow', () {
    test('starting today: the Tbilisi date of the moment', () {
      expect(
        CalendarWindow.startingToday(DateTime.utc(2026, 10, 15, 21)).first,
        CalendarDay(2026, 10, 16),
      );
      expect(
        CalendarWindow.startingToday(DateTime.utc(2026, 10, 15, 19)).first,
        CalendarDay(2026, 10, 15),
      );
    });

    test('14 days, from 00:00 of the first to 00:00 after the last', () {
      expect(window.days, hasLength(calendarDayCount));
      expect(window.days.first, CalendarDay(2026, 10, 16));
      expect(window.days.last, CalendarDay(2026, 10, 29));
      expect(window.last, CalendarDay(2026, 10, 29));
      expect(window.startUtc, DateTime.utc(2026, 10, 15, 20));
      expect(window.endUtc, DateTime.utc(2026, 10, 29, 20));
    });

    test('previous and next move it by 7 days, also across a year', () {
      expect(window.next().first, CalendarDay(2026, 10, 23));
      expect(window.previous().first, CalendarDay(2026, 10, 9));
      final december = CalendarWindow(CalendarDay(2026, 12, 28));
      expect(december.next().first, CalendarDay(2027, 1, 4));
      expect(december.next().previous(), december);
    });
  });

  group('bookingTouchesWindow', () {
    test('a return at exactly 00:00 of the first day is not in it', () {
      expect(
        bookingTouchesWindow(booking('b', tb(10, 14), tb(10, 16)), window),
        isFalse,
      );
      expect(
        bookingTouchesWindow(
          booking('b', tb(10, 14), tb(10, 16, 0, 1)),
          window,
        ),
        isTrue,
      );
    });

    test('a pickup at exactly 00:00 after the last day is not in it', () {
      expect(
        bookingTouchesWindow(booking('b', tb(10, 30), tb(11, 2)), window),
        isFalse,
      );
      expect(
        bookingTouchesWindow(
          booking('b', tb(10, 29, 23, 59), tb(11, 2)),
          window,
        ),
        isTrue,
      );
    });

    test('a booking longer than the window is in it', () {
      expect(
        bookingTouchesWindow(booking('b', tb(10, 1), tb(11, 20)), window),
        isTrue,
      );
    });

    test('a time that is not UTC throws', () {
      final utc = booking('b', tb(10, 16, 10), tb(10, 17, 10));
      final local = Booking(
        id: 'b',
        customer: utc.customer,
        carId: utc.carId,
        pickup: DateTime(2026, 10, 16, 10),
        dropoff: utc.dropoff,
        pickupLocation: utc.pickupLocation,
        dropoffLocation: utc.dropoffLocation,
        extras: utc.extras,
        notes: utc.notes,
        totalPrice: utc.totalPrice,
        language: utc.language,
        status: utc.status,
      );
      expect(() => bookingTouchesWindow(local, window), throwsArgumentError);
    });
  });

  group('placeBooking', () {
    CalendarBar place(Booking b) => placeBooking(b, window, tooClose: false);

    test('partial days: from 10:00 of the first day to 18:00 of the third', () {
      final bar = place(booking('b', tb(10, 16, 10), tb(10, 18, 18)));
      expect(bar.start, closeTo(10 / 24, 1e-9));
      expect(bar.end, closeTo(2.75, 1e-9));
      expect(bar.firstDay, 0);
      expect(bar.lastDay, 2);
      expect(bar.startsBefore, isFalse);
      expect(bar.endsAfter, isFalse);
    });

    test('a booking within one day covers part of one cell', () {
      final bar = place(booking('b', tb(10, 20, 12), tb(10, 20, 20)));
      expect(bar.start, closeTo(4.5, 1e-9));
      expect(bar.end, closeTo(4 + 20 / 24, 1e-9));
      expect(bar.firstDay, 4);
      expect(bar.lastDay, 4);
    });

    test('a return at 00:00 does not reach into that day', () {
      final bar = place(booking('b', tb(10, 17, 9), tb(10, 19)));
      expect(bar.end, 3.0);
      expect(bar.firstDay, 1);
      expect(bar.lastDay, 2);
    });

    test('a pickup at 00:00 starts at the left edge of its cell', () {
      final bar = place(booking('b', tb(10, 18), tb(10, 18, 6)));
      expect(bar.start, 2.0);
      expect(bar.firstDay, 2);
      expect(bar.lastDay, 2);
    });

    test('a booking that starts before the window is cut on the left', () {
      final bar = place(booking('b', tb(10, 12, 9), tb(10, 17, 12)));
      expect(bar.start, 0.0);
      expect(bar.end, closeTo(1.5, 1e-9));
      expect(bar.firstDay, 0);
      expect(bar.lastDay, 1);
      expect(bar.startsBefore, isTrue);
      expect(bar.endsAfter, isFalse);
    });

    test('a booking that ends after the window is cut on the right', () {
      final bar = place(booking('b', tb(10, 28, 14), tb(11, 1, 11)));
      expect(bar.start, closeTo(12 + 14 / 24, 1e-9));
      expect(bar.end, 14.0);
      expect(bar.firstDay, 12);
      expect(bar.lastDay, 13);
      expect(bar.startsBefore, isFalse);
      expect(bar.endsAfter, isTrue);
    });

    test('a return at exactly the end of the window is not "after" it', () {
      final bar = place(booking('b', tb(10, 28, 14), tb(10, 30)));
      expect(bar.end, 14.0);
      expect(bar.lastDay, 13);
      expect(bar.endsAfter, isFalse);
    });

    test('a booking longer than the window fills it and is cut twice', () {
      final bar = place(booking('b', tb(10, 1), tb(11, 20)));
      expect(bar.start, 0.0);
      expect(bar.end, 14.0);
      expect(bar.firstDay, 0);
      expect(bar.lastDay, 13);
      expect(bar.startsBefore, isTrue);
      expect(bar.endsAfter, isTrue);
    });

    test('tooClose is passed on', () {
      final b = booking('b', tb(10, 16, 10), tb(10, 17, 10));
      expect(placeBooking(b, window, tooClose: true).tooClose, isTrue);
    });

    test('a booking outside the window throws', () {
      expect(
        () => place(booking('b', tb(11, 2), tb(11, 3))),
        throwsArgumentError,
      );
    });
  });

  group('calendarLanes', () {
    CalendarBar bar(String id, DateTime pickup, DateTime dropoff) =>
        placeBooking(booking(id, pickup, dropoff), window, tooClose: false);

    List<List<String?>> ids(List<List<CalendarBar>> lanes) => [
      for (final lane in lanes) [for (final bar in lane) bar.booking.id],
    ];

    test('no bars, no lanes', () {
      expect(calendarLanes(const []), isEmpty);
    });

    test('a return at 10:00 and a pickup at 18:00 of the same day: two', () {
      final lanes = calendarLanes([
        bar('a', tb(10, 16, 10), tb(10, 18, 10)),
        bar('b', tb(10, 18, 18), tb(10, 20, 10)),
      ]);
      expect(ids(lanes), [
        ['a'],
        ['b'],
      ]);
    });

    test('the next pickup on the following day: one lane', () {
      final lanes = calendarLanes([
        bar('b', tb(10, 19, 9), tb(10, 20, 10)),
        bar('a', tb(10, 16, 10), tb(10, 18, 10)),
      ]);
      expect(ids(lanes), [
        ['a', 'b'],
      ]);
    });

    test('a return at 00:00 and a pickup later that day: one lane', () {
      final lanes = calendarLanes([
        bar('a', tb(10, 16, 10), tb(10, 18)),
        bar('b', tb(10, 18, 9), tb(10, 19, 10)),
      ]);
      expect(ids(lanes), [
        ['a', 'b'],
      ]);
    });

    test('three overlapping bookings: three lanes', () {
      final lanes = calendarLanes([
        bar('a', tb(10, 16, 10), tb(10, 20, 10)),
        bar('b', tb(10, 17, 10), tb(10, 21, 10)),
        bar('c', tb(10, 18, 10), tb(10, 22, 10)),
      ]);
      expect(ids(lanes), [
        ['a'],
        ['b'],
        ['c'],
      ]);
    });

    test('a later bar takes the first lane that is free', () {
      final lanes = calendarLanes([
        bar('a', tb(10, 16, 10), tb(10, 17, 10)),
        bar('b', tb(10, 17, 18), tb(10, 22, 10)),
        bar('c', tb(10, 19, 10), tb(10, 20, 10)),
      ]);
      expect(ids(lanes), [
        ['a', 'c'],
        ['b'],
      ]);
    });

    test('the same pickup: by booking ID', () {
      final lanes = calendarLanes([
        bar('y', tb(10, 16, 10), tb(10, 17, 10)),
        bar('x', tb(10, 16, 10), tb(10, 17, 10)),
      ]);
      expect(ids(lanes), [
        ['x'],
        ['y'],
      ]);
    });
  });

  group('calendarRows', () {
    List<CalendarBar> barsOf(CalendarRow row) => [
      for (final lane in row.lanes) ...lane,
    ];

    CalendarBar barOf(List<CalendarRow> rows, String id) => [
      for (final row in rows) ...barsOf(row),
    ].singleWhere((bar) => bar.booking.id == id);

    test('every visible car, in the order of the Cars list, also empty', () {
      final rows = calendarRows(
        cars: [
          car('c3', brand: 'kia'),
          car('c2', brand: 'Audi', model: 'B'),
          car('c1', brand: 'audi', model: 'a'),
          car('c0', brand: 'Audi', model: 'A', year: 2018),
          car('c5', brand: 'Audi', model: 'A', year: 2018),
        ],
        bookings: const [],
        window: window,
      );
      expect(rows.map((row) => row.carId), ['c0', 'c5', 'c1', 'c2', 'c3']);
      for (final row in rows) {
        expect(row.lanes, [isEmpty]);
        expect(row.hasBars, isFalse);
        expect(row.hidden, isFalse);
      }
      expect(calendarHasBars(rows), isFalse);
    });

    test('a hidden car only with a booking in the window, after the '
        'visible cars and marked', () {
      final rows = calendarRows(
        cars: [
          car('h1', active: false, brand: 'Audi'),
          car('h2', active: false),
          car('v1', brand: 'Toyota'),
        ],
        bookings: [
          booking('in', tb(10, 20, 10), tb(10, 21, 10), carId: 'h1'),
          booking('out', tb(11, 20, 10), tb(11, 21, 10), carId: 'h2'),
        ],
        window: window,
      );
      expect(rows.map((row) => row.carId), ['v1', 'h1']);
      expect(rows[1].hidden, isTrue);
      expect(rows[1].hasBars, isTrue);
      expect(calendarHasBars(rows), isTrue);
    });

    test('a booking of a car that is not there: an unknown row, last, by '
        'ID; none without a booking in the window', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('b1', tb(10, 20, 10), tb(10, 21, 10), carId: 'zz'),
          booking('b2', tb(10, 20, 10), tb(10, 21, 10), carId: 'aa'),
          booking('b3', tb(12, 20, 10), tb(12, 21, 10), carId: 'mm'),
        ],
        window: window,
      );
      expect(rows.map((row) => row.carId), ['v1', 'aa', 'zz']);
      expect(rows[1].car, isNull);
      expect(rows[1].hidden, isFalse);
    });

    test('only confirmed bookings are drawn', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          for (final status in ['new', 'pending', 'cancelled', 'confirmed'])
            booking(
              status,
              tb(10, 20, 10),
              tb(10, 21, 10),
              carId: 'v1',
              status: status,
            ),
        ],
        window: window,
      );
      expect(barsOf(rows.single).map((bar) => bar.booking.id), ['confirmed']);
    });

    test('a booking outside the window is not drawn', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('old', tb(10, 1, 10), tb(10, 16), carId: 'v1'),
          booking('later', tb(10, 30), tb(10, 31), carId: 'v1'),
        ],
        window: window,
      );
      expect(rows.single.hasBars, isFalse);
    });

    test('4 h 59 min apart: both too close, in two lanes', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 18), carId: 'v1'),
          booking('b', tb(10, 18, 22, 59), tb(10, 20, 12), carId: 'v1'),
        ],
        window: window,
      );
      expect(barOf(rows, 'a').tooClose, isTrue);
      expect(barOf(rows, 'b').tooClose, isTrue);
      expect(rows.single.lanes, hasLength(2));
    });

    test('exactly 5 hours apart: not too close', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 10), carId: 'v1'),
          booking('b', tb(10, 18, 15), tb(10, 20, 12), carId: 'v1'),
        ],
        window: window,
      );
      expect(barOf(rows, 'a').tooClose, isFalse);
      expect(barOf(rows, 'b').tooClose, isFalse);
    });

    test('too close to a booking outside the window: the bar inside is '
        'marked', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('before', tb(10, 10, 10), tb(10, 16, 1), carId: 'v1'),
          booking('inside', tb(10, 16, 3), tb(10, 17, 10), carId: 'v1'),
        ],
        window: window,
      );
      // "before" ends at 01:00 of the first day, so it is drawn too.
      expect(barOf(rows, 'inside').tooClose, isTrue);

      final later = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('outside', tb(10, 30, 2), tb(10, 31), carId: 'v1'),
          booking('inside', tb(10, 28, 10), tb(10, 29, 22), carId: 'v1'),
        ],
        window: window,
      );
      expect(barsOf(later.single), hasLength(1));
      expect(barOf(later, 'inside').tooClose, isTrue);
    });

    test('bookings of another car are never too close', () {
      final rows = calendarRows(
        cars: [car('v1'), car('v2')],
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 10), carId: 'v1'),
          booking('b', tb(10, 18, 11), tb(10, 20, 12), carId: 'v2'),
        ],
        window: window,
      );
      expect(barOf(rows, 'a').tooClose, isFalse);
      expect(barOf(rows, 'b').tooClose, isFalse);
    });

    test('a pending booking next to a confirmed one does not mark it', () {
      final rows = calendarRows(
        cars: [car('v1')],
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 10), carId: 'v1'),
          booking(
            'p',
            tb(10, 18, 11),
            tb(10, 20, 12),
            carId: 'v1',
            status: 'pending',
          ),
        ],
        window: window,
      );
      expect(barOf(rows, 'a').tooClose, isFalse);
    });

    test('no cars and no bookings: no rows', () {
      expect(
        calendarRows(cars: const [], bookings: const [], window: window),
        isEmpty,
      );
    });
  });

  group('texts', () {
    test('the first cell and every 1st of a month name the month', () {
      final october = CalendarWindow(CalendarDay(2026, 10, 25));
      final shown = [
        for (var i = 0; i < calendarDayCount; i++)
          if (calendarCellShowsMonth(october, i)) i,
      ];
      expect(shown, [0, 7]);
      expect(calendarDateText(october, 0), '25 Oct');
      expect(calendarDateText(october, 1), '26');
      expect(calendarDateText(october, 7), '1 Nov');
    });

    test('across a year end', () {
      final december = CalendarWindow(CalendarDay(2026, 12, 25));
      final shown = [
        for (var i = 0; i < calendarDayCount; i++)
          if (calendarCellShowsMonth(december, i)) i,
      ];
      expect(shown, [0, 7]);
      expect(calendarDateText(december, 7), '1 Jan');
      expect(calendarDateText(december, 8), '2');
    });

    test('a window that starts on the 1st names the month once', () {
      final november = CalendarWindow(CalendarDay(2026, 11, 1));
      final shown = [
        for (var i = 0; i < calendarDayCount; i++)
          if (calendarCellShowsMonth(november, i)) i,
      ];
      expect(shown, [0]);
      expect(calendarDateText(november, 0), '1 Nov');
    });

    test('the weekday and the full date', () {
      expect(calendarWeekdayText(CalendarDay(2026, 10, 16)), 'Fri');
      expect(calendarWeekdayText(CalendarDay(2026, 10, 18)), 'Sun');
      expect(
        calendarFullDateText(CalendarDay(2026, 10, 16)),
        'Friday 16 Oct 2026',
      );
      expect(
        calendarFullDateText(CalendarDay(2027, 1, 4)),
        'Monday 4 Jan 2027',
      );
    });

    test('the range, also across a year end', () {
      expect(calendarRangeText(window), '16 Oct – 29 Oct 2026');
      expect(
        calendarRangeText(CalendarWindow(CalendarDay(2026, 12, 28))),
        '28 Dec 2026 – 10 Jan 2027',
      );
    });
  });
}
