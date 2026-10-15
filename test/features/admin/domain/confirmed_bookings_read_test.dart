import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// A confirmed booking of car-1 from [pickup] to [dropoff] (made up).
RawBookingDocument confirmed(String id, DateTime pickup, DateTime dropoff) =>
    rawBooking(id, status: 'confirmed', pickup: pickup, dropoff: dropoff);

DateTime at(int hour) => DateTime.utc(2026, 6, 1, hour);

ConfirmedBookingsChecked checked(ConfirmedBookingsRead read) =>
    read as ConfirmedBookingsChecked;

void main() {
  group('readConfirmedBookings', () {
    test('a server answer: its confirmed bookings', () {
      final read = checked(
        readConfirmedBookings(
          [confirmed('a', at(10), at(12)), confirmed('b', at(14), at(16))],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      expect(read.bookings.map((b) => b.id), ['a', 'b']);
      expect(read.unreadable, 0);
    });

    test('an empty server answer: checked, nothing found', () {
      final read = checked(
        readConfirmedBookings(const [], fromCache: false, carId: 'car-1'),
      );
      expect(read.bookings, isEmpty);
      expect(read.unreadable, 0);
    });

    test('an answer from memory is never trusted, empty or not', () {
      for (final documents in [
        const <RawBookingDocument>[],
        [confirmed('a', at(10), at(12))],
      ]) {
        final read = readConfirmedBookings(
          documents,
          fromCache: true,
          carId: 'car-1',
        );
        expect(read, isA<ConfirmedBookingsUnchecked>());
        expect(
          (read as ConfirmedBookingsUnchecked).failure,
          ConflictCheckFailure.noConnection,
        );
      }
    });

    test('a booking of another car or another status is dropped', () {
      final read = checked(
        readConfirmedBookings(
          [
            confirmed('a', at(10), at(12)),
            rawBooking('b', carId: 'car-2', status: 'confirmed'),
            rawBooking('c', status: 'pending'),
          ],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      expect(read.bookings.map((b) => b.id), ['a']);
    });

    test('an unreadable document is counted; the others still come', () {
      final read = checked(
        readConfirmedBookings(
          [
            confirmed('a', at(10), at(12)),
            rawBooking('broken', status: 'confirmed', changes: {'status': 7}),
          ],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      expect(read.bookings.map((b) => b.id), ['a']);
      expect(read.unreadable, 1);
    });

    test('the list cannot be changed', () {
      final read = checked(
        readConfirmedBookings(
          [confirmed('a', at(10), at(12))],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      expect(() => read.bookings.clear(), throwsUnsupportedError);
    });

    test('the limit is 10 seconds', () {
      expect(conflictCheckTimeout, const Duration(seconds: 10));
    });
  });

  group('the fake repository, as 5.3 and 5.4 will use it', () {
    late FakeAdminBookingsRepository fake;

    setUp(() => fake = FakeAdminBookingsRepository());

    void expectNothingWritten() {
      expect(fake.statusChanges, isEmpty);
      expect(fake.updates, isEmpty);
      expect(fake.deletes, isEmpty);
      expect(fake.creates, isEmpty);
    }

    Booking candidate() =>
        Booking.fromMap('self', confirmed('self', at(11), at(13)).data);

    test('a server answer with a conflicting booking', () async {
      fake.confirmedAnswer = checked(
        readConfirmedBookings(
          [confirmed('other', at(10), at(12))],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      final read = checked(await fake.readConfirmedBookingsOfCar('car-1'));
      final conflicts = findConflicts(
        candidate(),
        read.bookings,
        selfId: 'self',
      );
      expect(conflicts.map((b) => b.id), ['other']);
      expect(fake.confirmedReads, ['car-1']);
      expectNothingWritten();
    });

    test('a server answer without a conflict', () async {
      fake.confirmedAnswer = checked(
        readConfirmedBookings(
          [confirmed('far', at(20), at(22))],
          fromCache: false,
          carId: 'car-1',
        ),
      );
      final read = checked(await fake.readConfirmedBookingsOfCar('car-1'));
      expect(
        findConflicts(candidate(), read.bookings, selfId: 'self'),
        isEmpty,
      );
      expectNothingWritten();
    });

    for (final failure in [
      ConflictCheckFailure.timeout,
      ConflictCheckFailure.other,
      ConflictCheckFailure.noConnection,
    ]) {
      test('could not be checked (${failure.name}) is passed on', () async {
        fake.confirmedAnswer = ConfirmedBookingsUnchecked(failure);
        final read = await fake.readConfirmedBookingsOfCar('car-1');
        expect((read as ConfirmedBookingsUnchecked).failure, failure);
        expectNothingWritten();
      });
    }
  });
}
