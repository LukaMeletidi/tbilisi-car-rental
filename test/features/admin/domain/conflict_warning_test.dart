import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// A made-up UTC moment on 1 June 2026.
DateTime at(int hour) => DateTime.utc(2026, 6, 1, hour);

/// A made-up booking of car-1 with [status].
Booking booking(
  String id,
  DateTime pickup,
  DateTime dropoff, {
  String status = 'confirmed',
}) => Booking.fromMap(
  id,
  rawBooking(id, status: status, pickup: pickup, dropoff: dropoff).data,
);

ConflictCheckOutcome outcome(
  List<Booking> stored, {
  int unreadable = 0,
  String? selfId = 'self',
}) => conflictCheckOutcome(
  read: ConfirmedBookingsChecked(bookings: stored, unreadable: unreadable),
  candidate: booking('self', at(10), at(12)),
  selfId: selfId,
);

void main() {
  group('conflictCheckOutcome', () {
    test('nothing found and everything read: clear', () {
      expect(outcome(const []), isA<ConflictCheckClear>());
      expect(
        outcome([booking('far', at(20), at(22))]),
        isA<ConflictCheckClear>(),
      );
    });

    test('a conflict: a warning that lists it', () {
      final result = outcome([booking('a', at(11), at(13))]);
      final warning = result as ConflictCheckWarning;
      expect(warning.conflicts.map((b) => b.id), ['a']);
      expect(warning.unreadable, 0);
    });

    test('only unreadable documents: still a warning, never a silent pass', () {
      final warning = outcome(const [], unreadable: 2) as ConflictCheckWarning;
      expect(warning.conflicts, isEmpty);
      expect(warning.unreadable, 2);
    });

    test('the booking itself is never its own conflict', () {
      expect(
        outcome([booking('self', at(10), at(12))]),
        isA<ConflictCheckClear>(),
      );
    });

    test('could not be read: failed, with its kind', () {
      for (final failure in ConflictCheckFailure.values) {
        final result = conflictCheckOutcome(
          read: ConfirmedBookingsUnchecked(failure),
          candidate: booking('self', at(10), at(12)),
          selfId: 'self',
        );
        expect((result as ConflictCheckFailed).failure, failure);
      }
    });

    test('a time that is not UTC: failed (other), never a crash', () {
      final local = Booking.fromMap(
        'self',
        rawBooking('self', status: 'confirmed').data,
      );
      final notUtc = Booking(
        id: local.id,
        customer: local.customer,
        carId: local.carId,
        pickup: DateTime(2026, 6, 1, 10),
        dropoff: DateTime(2026, 6, 1, 12),
        pickupLocation: local.pickupLocation,
        dropoffLocation: local.dropoffLocation,
        extras: local.extras,
        notes: local.notes,
        totalPrice: local.totalPrice,
        language: local.language,
        status: local.status,
      );
      final result = conflictCheckOutcome(
        read: ConfirmedBookingsChecked(
          bookings: [booking('a', at(11), at(13))],
          unreadable: 0,
        ),
        candidate: notUtc,
        selfId: 'self',
      );
      expect(
        (result as ConflictCheckFailed).failure,
        ConflictCheckFailure.other,
      );
    });
  });

  group('conflictWarningLines', () {
    ConflictWarningLines lines(int count, {int unreadable = 0}) {
      final conflicts = [
        // Added in reverse order; findConflicts sorts them by pickup.
        for (var i = count - 1; i >= 0; i--) booking('c$i', at(6 + i), at(12)),
      ];
      final warning =
          outcome(conflicts, unreadable: unreadable) as ConflictCheckWarning;
      return conflictWarningLines(warning);
    }

    test('at most 3 periods, then "and N more"', () {
      expect(conflictWarningMaxListed, 3);
      for (final (count, listed, more) in [
        (1, 1, 0),
        (3, 3, 0),
        (4, 3, 1),
        (5, 3, 2),
      ]) {
        final result = lines(count);
        expect(result.periods, hasLength(listed), reason: '$count');
        expect(result.more, more, reason: '$count');
      }
    });

    test('the periods are the stored times, sorted by pickup', () {
      final result = lines(3);
      expect(result.periods.map((p) => p.pickup), [at(6), at(7), at(8)]);
      expect(result.periods.first.dropoff, at(12));
      expect(() => result.periods.clear(), throwsUnsupportedError);
    });

    test('the unreadable count is carried over', () {
      expect(lines(1, unreadable: 2).unreadable, 2);
    });
  });

  test('bookingWithStatus changes only the status', () {
    final stored = booking('b', at(10), at(12), status: 'pending');
    final confirmed = bookingWithStatus(stored, BookingStatus.confirmed);
    expect(confirmed.status, BookingStatus.confirmed);
    expect(bookingWithStatus(confirmed, BookingStatus.pending), stored);
    expect(confirmed.id, 'b');
    expect(confirmed.totalPrice, stored.totalPrice);
    expect(confirmed.createdAt, stored.createdAt);
  });
}
