import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';

/// A made-up UTC moment on 1 June 2026 (day 2 is the next day).
DateTime at(int hour, [int minute = 0, int day = 1]) =>
    DateTime.utc(2026, 6, day, hour, minute);

/// A booking with made-up values; only what a test names matters.
Booking booking({
  String? id,
  String carId = 'car-a',
  required DateTime pickup,
  required DateTime dropoff,
  BookingStatus status = BookingStatus.confirmed,
  String fullName = 'Test Customer',
  String notes = '',
  Set<Extra> extras = const {},
  double totalPrice = 100,
  String pickupPlace = 'airport',
}) {
  return Booking(
    id: id,
    customer: BookingCustomer(
      fullName: fullName,
      phone: '+995555000001',
      whatsapp: false,
      telegram: false,
      email: 'customer@example.com',
    ),
    carId: carId,
    pickup: pickup,
    dropoff: dropoff,
    pickupLocation: BookingLocation.fixed(pickupPlace),
    dropoffLocation: const BookingLocation.fixed('airport'),
    extras: extras,
    notes: notes,
    totalPrice: totalPrice,
    language: AppLanguage.en,
    status: status,
  );
}

/// The other booking of most time tests: 10:00 to 12:00 UTC on car-a.
final other = booking(id: 'other', pickup: at(10), dropoff: at(12));

/// Both directions must agree; the result of one is returned.
bool conflictBothWays(Booking a, Booking b) {
  final ab = bookingsConflict(a, b);
  expect(bookingsConflict(b, a), ab, reason: 'reversed order');
  return ab;
}

void main() {
  group('bookingsConflict: the time rule', () {
    test('1. the buffer is 5 hours', () {
      expect(conflictBuffer, const Duration(hours: 5));
    });

    test('2. a pickup exactly 5 h after the other dropoff: no conflict', () {
      final next = booking(pickup: at(17), dropoff: at(20));
      expect(conflictBothWays(next, other), false);
    });

    test('3. 4 h 59 min after: conflict', () {
      final next = booking(pickup: at(16, 59), dropoff: at(20));
      expect(conflictBothWays(next, other), true);
    });

    test('4. 5 h 01 min after: no conflict', () {
      final next = booking(pickup: at(17, 1), dropoff: at(20));
      expect(conflictBothWays(next, other), false);
    });

    test('5. a dropoff 5 h, 4 h 59 min and 5 h 01 min before the other '
        'pickup', () {
      expect(
        conflictBothWays(booking(pickup: at(1), dropoff: at(5)), other),
        false,
      );
      expect(
        conflictBothWays(booking(pickup: at(1), dropoff: at(5, 1)), other),
        true,
      );
      expect(
        conflictBothWays(booking(pickup: at(1), dropoff: at(4, 59)), other),
        false,
      );
    });

    test('6. touching: the pickup at the other dropoff', () {
      expect(
        conflictBothWays(booking(pickup: at(12), dropoff: at(14)), other),
        true,
      );
    });

    test('7. one inside the other, both ways', () {
      final inside = booking(pickup: at(10, 30), dropoff: at(11, 30));
      final around = booking(pickup: at(8), dropoff: at(14));
      expect(conflictBothWays(inside, other), true);
      expect(conflictBothWays(around, other), true);
    });

    test('8. identical times', () {
      expect(
        conflictBothWays(booking(pickup: at(10), dropoff: at(12)), other),
        true,
      );
    });

    test('9. the order of the two never matters', () {
      // Every comparison above runs through conflictBothWays; here a few
      // more pairs, far apart and close.
      for (final candidate in [
        booking(pickup: at(0), dropoff: at(1)),
        booking(pickup: at(13), dropoff: at(15)),
        booking(pickup: at(18), dropoff: at(19)),
        booking(pickup: at(9), dropoff: at(10)),
      ]) {
        conflictBothWays(candidate, other);
      }
    });

    test('10. across midnight: 22:00 to 02:00, then 06:00 and 07:00 the '
        'next day', () {
      final night = booking(pickup: at(22), dropoff: at(2, 0, 2));
      final at6 = booking(pickup: at(6, 0, 2), dropoff: at(9, 0, 2));
      final at7 = booking(pickup: at(7, 0, 2), dropoff: at(9, 0, 2));
      expect(conflictBothWays(night, at6), true);
      expect(conflictBothWays(night, at7), false);
    });

    test('11. the same times on another car: no conflict', () {
      final otherCar = booking(carId: 'car-b', pickup: at(10), dropoff: at(12));
      expect(conflictBothWays(otherCar, other), false);
    });

    test('12. a time that is not UTC is refused', () {
      final local = booking(
        pickup: DateTime(2026, 6, 1, 10),
        dropoff: DateTime(2026, 6, 1, 12),
      );
      expect(() => bookingsConflict(local, other), throwsArgumentError);
      expect(() => bookingsConflict(other, local), throwsArgumentError);
    });

    test('13. only UTC gaps count: a pair on two Tbilisi dates with a gap of '
        'exactly 5 h is no conflict', () {
      // 18:00 UTC is 22:00 in Tbilisi; 23:00 UTC is 03:00 the next day in
      // Tbilisi. The Tbilisi dates differ, the UTC gap is 5 h.
      final late = booking(pickup: at(16), dropoff: at(18));
      final next = booking(pickup: at(23), dropoff: at(23, 30));
      expect(conflictBothWays(late, next), false);
    });
  });

  group('findConflicts', () {
    final candidate = booking(pickup: at(10), dropoff: at(12));

    test('14. the booking itself is skipped, even with the same times', () {
      final self = booking(id: 'self', pickup: at(10), dropoff: at(12));
      expect(findConflicts(candidate, [self], selfId: 'self'), isEmpty);
      expect(findConflicts(candidate, [self, other], selfId: 'self'), [other]);
    });

    test('15. a new booking (no ID yet): nothing is skipped by ID', () {
      final stored = booking(id: 'x', pickup: at(10), dropoff: at(12));
      expect(findConflicts(candidate, [stored], selfId: null), [stored]);
    });

    test('16. new, pending and cancelled bookings never conflict', () {
      final others = [
        for (final status in [
          BookingStatus.newBooking,
          BookingStatus.pending,
          BookingStatus.cancelled,
        ])
          booking(
            id: status.name,
            status: status,
            pickup: at(10),
            dropoff: at(12),
          ),
      ];
      expect(findConflicts(candidate, others, selfId: null), isEmpty);
      expect(findConflicts(candidate, [...others, other], selfId: null), [
        other,
      ]);
    });

    test('17. sorted by pickup, then by ID', () {
      final late = booking(id: 'a', pickup: at(13), dropoff: at(14));
      final early = booking(id: 'z', pickup: at(8), dropoff: at(9));
      final sameB = booking(id: 'b', pickup: at(11), dropoff: at(13));
      final sameA = booking(id: 'a2', pickup: at(11), dropoff: at(13));
      expect(
        findConflicts(candidate, [
          late,
          sameB,
          early,
          sameA,
        ], selfId: null).map((b) => b.id),
        ['z', 'a2', 'b', 'a'],
      );
    });

    test('18. only bookings of the same car', () {
      final otherCar = booking(
        id: 'b1',
        carId: 'car-b',
        pickup: at(10),
        dropoff: at(12),
      );
      expect(findConflicts(candidate, [otherCar, other], selfId: null), [
        other,
      ]);
    });

    test('19. the result cannot be changed; the input is not changed', () {
      final input = [
        booking(id: 'late', pickup: at(13), dropoff: at(14)),
        other,
      ];
      final result = findConflicts(candidate, input, selfId: null);
      expect(() => result.add(other), throwsUnsupportedError);
      expect(input.map((b) => b.id), ['late', 'other']);
    });
  });

  group('needsConflictCheck', () {
    Booking stored(BookingStatus status) =>
        booking(id: 'b', status: status, pickup: at(10), dropoff: at(12));

    test('20. a new booking: checked only when saved as confirmed', () {
      for (final status in BookingStatus.values) {
        expect(
          needsConflictCheck(base: null, edited: stored(status)),
          status == BookingStatus.confirmed,
          reason: status.name,
        );
      }
    });

    test('21. any status to confirmed: checked', () {
      for (final from in [
        BookingStatus.cancelled,
        BookingStatus.newBooking,
        BookingStatus.pending,
      ]) {
        expect(
          needsConflictCheck(
            base: stored(from),
            edited: stored(BookingStatus.confirmed),
          ),
          true,
          reason: from.name,
        );
      }
    });

    test('22. away from confirmed, or a status that stays not confirmed: not '
        'checked', () {
      final confirmed = stored(BookingStatus.confirmed);
      expect(
        needsConflictCheck(
          base: confirmed,
          edited: stored(BookingStatus.cancelled),
        ),
        false,
      );
      expect(
        needsConflictCheck(
          base: confirmed,
          edited: stored(BookingStatus.pending),
        ),
        false,
      );
      expect(
        needsConflictCheck(
          base: stored(BookingStatus.pending),
          edited: stored(BookingStatus.pending),
        ),
        false,
      );
    });

    test('23. confirmed stays confirmed, only notes, customer, extras, total '
        'or places changed: not checked', () {
      final base = stored(BookingStatus.confirmed);
      for (final edited in [
        booking(id: 'b', pickup: at(10), dropoff: at(12), notes: 'A note.'),
        booking(id: 'b', pickup: at(10), dropoff: at(12), fullName: 'Other'),
        booking(
          id: 'b',
          pickup: at(10),
          dropoff: at(12),
          extras: {Extra.values.first},
        ),
        booking(id: 'b', pickup: at(10), dropoff: at(12), totalPrice: 250),
        booking(id: 'b', pickup: at(10), dropoff: at(12), pickupPlace: 'city'),
      ]) {
        expect(needsConflictCheck(base: base, edited: edited), false);
      }
    });

    test('24. confirmed stays confirmed, the car, pickup or dropoff changed: '
        'checked', () {
      final base = stored(BookingStatus.confirmed);
      for (final edited in [
        booking(id: 'b', carId: 'car-b', pickup: at(10), dropoff: at(12)),
        booking(id: 'b', pickup: at(9), dropoff: at(12)),
        booking(id: 'b', pickup: at(10), dropoff: at(13)),
      ]) {
        expect(needsConflictCheck(base: base, edited: edited), true);
      }
    });
  });

  group('futureConfirmed', () {
    final now = at(12);

    test('25. a dropoff exactly now is over', () {
      final ends = booking(id: 'e', pickup: at(10), dropoff: at(12));
      expect(futureConfirmed([ends], carId: 'car-a', now: now), isEmpty);
    });

    test('26. a dropoff in the past is over', () {
      final past = booking(id: 'p', pickup: at(8), dropoff: at(9));
      expect(futureConfirmed([past], carId: 'car-a', now: now), isEmpty);
    });

    test('27. a later booking and a rental in progress count', () {
      final later = booking(id: 'l', pickup: at(14), dropoff: at(16));
      final running = booking(id: 'r', pickup: at(11), dropoff: at(13));
      expect(
        futureConfirmed(
          [later, running],
          carId: 'car-a',
          now: now,
        ).map((b) => b.id),
        ['r', 'l'],
      );
    });

    test('28. only confirmed bookings of that car', () {
      final otherCar = booking(
        id: 'c',
        carId: 'car-b',
        pickup: at(14),
        dropoff: at(16),
      );
      final pending = booking(
        id: 'p',
        status: BookingStatus.pending,
        pickup: at(14),
        dropoff: at(16),
      );
      final mine = booking(id: 'm', pickup: at(14), dropoff: at(16));
      expect(
        futureConfirmed([otherCar, pending, mine], carId: 'car-a', now: now),
        [mine],
      );
    });

    test('29. sorted by pickup, then by ID', () {
      final c = booking(id: 'c', pickup: at(18), dropoff: at(19));
      final b = booking(id: 'b', pickup: at(14), dropoff: at(15));
      final a = booking(id: 'a', pickup: at(14), dropoff: at(15));
      expect(
        futureConfirmed([c, b, a], carId: 'car-a', now: now).map((x) => x.id),
        ['a', 'b', 'c'],
      );
    });

    test('30. a "now" that is not UTC is refused', () {
      expect(
        () => futureConfirmed(
          const [],
          carId: 'car-a',
          now: DateTime(2026, 6, 1, 12),
        ),
        throwsArgumentError,
      );
    });
  });
}
