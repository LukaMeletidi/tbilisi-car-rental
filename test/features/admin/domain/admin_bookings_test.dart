import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';

import '../../../support/fake_admin_bookings_repository.dart';

void main() {
  group('parseBookings', () {
    test('reads the documents as bookings, in their order', () {
      final parsed = parseBookings([
        rawBooking('b', fullName: 'Second Person', status: 'confirmed'),
        rawBooking('a', fullName: 'First Person'),
      ]);

      expect(parsed.unreadable, isEmpty);
      expect(parsed.bookings.map((b) => b.id), ['b', 'a']);
      expect(parsed.bookings.first.customer.fullName, 'Second Person');
      expect(parsed.bookings.first.status, BookingStatus.confirmed);
      expect(parsed.bookings.first.pickup, DateTime.utc(2026, 1, 10, 14));
      expect(
        parsed.bookings.first.createdAt,
        DateTime.utc(2026, 10, 9, 13, 34),
      );
    });

    test('no documents: nothing read, nothing skipped', () {
      final parsed = parseBookings(const []);
      expect(parsed.bookings, isEmpty);
      expect(parsed.unreadable, isEmpty);
    });

    test('a document that cannot be read is skipped and counted; the others '
        'are kept', () {
      final parsed = parseBookings([
        rawBooking('good-1'),
        rawBooking('bad-status', status: 'completed'),
        rawBooking('good-2'),
        rawBooking('bad-date', changes: {'pickupDateTime': '2026-01-10'}),
        rawBooking('no-customer', changes: {'customer': null}),
      ]);

      expect(parsed.bookings.map((b) => b.id), ['good-1', 'good-2']);
      expect(parsed.unreadable.map((u) => u.id), [
        'bad-status',
        'bad-date',
        'no-customer',
      ]);
    });

    test('the reason names the problem and never holds the customer', () {
      final parsed = parseBookings([
        rawBooking(
          'bad',
          fullName: 'Very Secret Name',
          phone: '+995555123123',
          changes: {'dropoffDateTime': DateTime.utc(2026, 1, 1)},
        ),
      ]);

      final reason = parsed.unreadable.single.reason;
      expect(reason, contains('dropoffDateTime'));
      expect(reason.contains('Very Secret Name'), false);
      expect(reason.contains('+995555123123'), false);
      expect(reason.contains('person@example.com'), false);
    });

    test('a date that is not UTC is refused', () {
      final parsed = parseBookings([
        rawBooking('local', pickup: DateTime(2026, 1, 10, 14)),
      ]);
      expect(parsed.bookings, isEmpty);
      expect(parsed.unreadable.single.id, 'local');
    });

    test('a booking without createdAt is still read', () {
      final document = rawBooking('fresh');
      document.data.remove('createdAt');
      final parsed = parseBookings([document]);
      expect(parsed.bookings.single.createdAt, isNull);
    });

    test('onSkipped is called for each skipped document', () {
      final skipped = <String>[];
      parseBookings([
        rawBooking('good'),
        rawBooking('bad-1', status: 'x'),
        rawBooking('bad-2', totalPrice: -1),
      ], onSkipped: (id, error, stackTrace) => skipped.add(id));
      expect(skipped, ['bad-1', 'bad-2']);
    });

    test('the results cannot be changed', () {
      final parsed = parseBookings([rawBooking('a')]);
      expect(() => parsed.bookings.clear(), throwsUnsupportedError);
      expect(() => parsed.unreadable.clear(), throwsUnsupportedError);
    });
  });

  group('adminCarLabel', () {
    final cars = {
      'car-1': testCar(),
      'car-2': testCar(id: 'car-2', active: false),
    };

    test('a car in the catalog', () {
      expect(
        adminCarLabel('car-1', cars),
        const AdminCarLabel(AdminCarState.active, 'Toyota Prius, 2019'),
      );
    });

    test('a hidden car keeps its title', () {
      expect(
        adminCarLabel('car-2', cars),
        const AdminCarLabel(AdminCarState.hidden, 'Toyota Prius, 2019'),
      );
    });

    test('a car that no longer exists', () {
      expect(
        adminCarLabel('gone', cars),
        const AdminCarLabel(AdminCarState.notFound),
      );
      expect(
        adminCarLabel('car-1', const {}),
        const AdminCarLabel(AdminCarState.notFound),
      );
    });

    test('cars not loaded: nothing is claimed about the car', () {
      expect(
        adminCarLabel('car-1', null),
        const AdminCarLabel(AdminCarState.notLoaded),
      );
    });
  });

  group('the offline note', () {
    final start = DateTime.utc(2026, 10, 9, 12);

    test('the streak starts with the first answer from the saved copy', () {
      expect(
        fromCacheSinceAfter(previous: null, fromCache: true, now: start),
        start,
      );
    });

    test(
      'the streak keeps its start while answers stay from the saved copy',
      () {
        final later = start.add(const Duration(seconds: 2));
        expect(
          fromCacheSinceAfter(previous: start, fromCache: true, now: later),
          start,
        );
      },
    );

    test('an answer from the server ends the streak', () {
      expect(
        fromCacheSinceAfter(previous: start, fromCache: false, now: start),
        isNull,
      );
      expect(
        fromCacheSinceAfter(previous: null, fromCache: false, now: start),
        isNull,
      );
    });

    test('not shown without a streak', () {
      expect(shouldShowOfflineNote(fromCacheSince: null, now: start), false);
    });

    test('not shown for the first answer, nor before 3 seconds', () {
      expect(offlineNoteDelay, const Duration(seconds: 3));
      expect(shouldShowOfflineNote(fromCacheSince: start, now: start), false);
      expect(
        shouldShowOfflineNote(
          fromCacheSince: start,
          now: start.add(const Duration(milliseconds: 2999)),
        ),
        false,
      );
    });

    test('shown from 3 seconds on', () {
      expect(
        shouldShowOfflineNote(
          fromCacheSince: start,
          now: start.add(const Duration(seconds: 3)),
        ),
        true,
      );
      expect(
        shouldShowOfflineNote(
          fromCacheSince: start,
          now: start.add(const Duration(minutes: 10)),
        ),
        true,
      );
    });
  });

  group('failures', () {
    test(
      'permission-denied is its own failure; everything else is "other"',
      () {
        expect(
          adminBookingsFailureFromCode('permission-denied'),
          AdminBookingsFailure.permissionDenied,
        );
        for (final code in ['unavailable', 'unauthenticated', '', 'internal']) {
          expect(
            adminBookingsFailureFromCode(code),
            AdminBookingsFailure.other,
            reason: code,
          );
        }
      },
    );
  });

  group('formatAdminDateTime', () {
    test('day, English month, year, 24-hour time', () {
      expect(
        formatAdminDateTime(TbilisiDateTime(2026, 1, 10, 18)),
        '10 Jan 2026 18:00',
      );
    });

    test('no leading zero for the day; two digits for the time', () {
      expect(
        formatAdminDateTime(TbilisiDateTime(2026, 10, 9, 7, 5)),
        '9 Oct 2026 07:05',
      );
    });

    test('every month has its three-letter name', () {
      const names = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (var month = 1; month <= 12; month++) {
        expect(
          formatAdminDateTime(TbilisiDateTime(2026, month, 1)),
          '1 ${names[month - 1]} 2026 00:00',
        );
      }
    });

    test('a stored UTC moment is shown as Tbilisi time', () {
      // 13:34 UTC is 17:34 in Tbilisi.
      expect(
        formatAdminUtc(DateTime.utc(2026, 10, 9, 13, 34)),
        '9 Oct 2026 17:34',
      );
      // 21:00 UTC on the 31st is already 01:00 on 1 January in Tbilisi.
      expect(
        formatAdminUtc(DateTime.utc(2026, 12, 31, 21)),
        '1 Jan 2027 01:00',
      );
    });
  });
}
