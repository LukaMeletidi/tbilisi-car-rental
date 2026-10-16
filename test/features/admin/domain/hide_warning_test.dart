import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/hide_warning.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// "Now" in these tests: 16 Oct 2026, 08:00 UTC.
final now = DateTime.utc(2026, 10, 16, 8);

/// A made-up booking of car-1 from day [from] to day [to] of October 2026,
/// 10:00 UTC each.
Booking booking(
  String id,
  int from,
  int to, {
  String status = 'confirmed',
  String carId = 'car-1',
}) => Booking.fromMap(
  id,
  rawBooking(
    id,
    status: status,
    carId: carId,
    pickup: DateTime.utc(2026, 10, from, 10),
    dropoff: DateTime.utc(2026, 10, to, 10),
  ).data,
);

HideCheckOutcome outcome(List<Booking> stored, {int unreadable = 0}) =>
    hideCheckOutcome(
      read: ConfirmedBookingsChecked(bookings: stored, unreadable: unreadable),
      carId: 'car-1',
      now: now,
    );

void main() {
  group('hideCheckOutcome', () {
    test('nothing ahead and everything read: clear', () {
      expect(outcome(const []), isA<HideCheckClear>());
      expect(outcome([booking('past', 1, 3)]), isA<HideCheckClear>());
    });

    test('a rental in progress and a later one are ahead, sorted', () {
      final result = outcome([
        booking('later', 20, 22),
        booking('running', 15, 25),
      ]);
      expect((result as HideCheckBookings).ahead.map((b) => b.id), [
        'running',
        'later',
      ]);
    });

    test('a dropoff exactly at now is over; one in the past too', () {
      final exactlyNow = Booking.fromMap(
        'edge',
        rawBooking(
          'edge',
          status: 'confirmed',
          pickup: DateTime.utc(2026, 10, 14, 8),
          dropoff: now,
        ).data,
      );
      expect(
        outcome([exactlyNow, booking('past', 1, 3)]),
        isA<HideCheckClear>(),
      );
    });

    test('pending, new and cancelled bookings and other cars are not '
        'listed', () {
      final result = outcome([
        booking('p', 20, 22, status: 'pending'),
        booking('n', 20, 22, status: 'new'),
        booking('c', 20, 22, status: 'cancelled'),
        booking('o', 20, 22, carId: 'car-2'),
      ]);
      expect(result, isA<HideCheckClear>());
    });

    test('only unreadable documents: still named, never a silent pass', () {
      final result = outcome(const [], unreadable: 2) as HideCheckBookings;
      expect(result.ahead, isEmpty);
      expect(result.unreadable, 2);
    });

    test('could not be read: failed, with its kind', () {
      for (final failure in ConflictCheckFailure.values) {
        final result = hideCheckOutcome(
          read: ConfirmedBookingsUnchecked(failure),
          carId: 'car-1',
          now: now,
        );
        expect((result as HideCheckFailed).failure, failure);
      }
    });

    test('a "now" that is not UTC: failed (other), never a crash', () {
      final result = hideCheckOutcome(
        read: ConfirmedBookingsChecked(
          bookings: [booking('later', 20, 22)],
          unreadable: 0,
        ),
        carId: 'car-1',
        now: DateTime(2026, 10, 16, 8),
      );
      expect((result as HideCheckFailed).failure, ConflictCheckFailure.other);
    });
  });

  group('hideWarningLines', () {
    test('at most 3 periods, then "and N more"; sorted', () {
      for (final (count, listed, more) in [
        (1, 1, 0),
        (3, 3, 0),
        (4, 3, 1),
        (5, 3, 2),
      ]) {
        final bookings = [
          for (var i = count - 1; i >= 0; i--) booking('b$i', 20 + i, 28),
        ];
        final lines = hideWarningLines(outcome(bookings) as HideCheckBookings);
        expect(lines.periods, hasLength(listed), reason: '$count');
        expect(lines.more, more, reason: '$count');
        expect(
          lines.periods.first.pickup,
          DateTime.utc(2026, 10, 20, 10),
          reason: '$count',
        );
      }
    });

    test('the unreadable count is carried over', () {
      final lines = hideWarningLines(
        outcome([booking('later', 20, 22)], unreadable: 1) as HideCheckBookings,
      );
      expect(lines.unreadable, 1);
      expect(() => lines.periods.clear(), throwsUnsupportedError);
    });
  });
}
