import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';

import '../../../support/fake_admin_bookings_repository.dart';

void main() {
  group('isPlausibleBookingId', () {
    test('accepts letters, digits, "_" and "-"', () {
      for (final id in ['a', 'abcDEF123', 'made-up_ID-1', 'A' * 128]) {
        expect(isPlausibleBookingId(id), true, reason: id);
      }
    });

    test('refuses everything else', () {
      for (final id in [
        '',
        ' ',
        'a b',
        'a/b',
        '../cars',
        'a.b',
        'a?b',
        'a#b',
        r'a\b',
        'a%20b',
        'ა',
        'A' * 129,
      ]) {
        expect(isPlausibleBookingId(id), false, reason: id);
      }
    });
  });

  group('readBookingAnswer', () {
    test('a readable document is found, from the server or saved', () {
      for (final fromCache in [false, true]) {
        final read = readBookingAnswer(
          RawBookingAnswer(
            document: rawBooking('b1', status: 'pending'),
            fromCache: fromCache,
          ),
        );

        expect(read.state, AdminBookingReadState.found);
        expect(read.booking!.id, 'b1');
        expect(read.booking!.status, BookingStatus.pending);
        expect(read.reason, isNull);
      }
    });

    test('no document, said by the server: missing', () {
      final read = readBookingAnswer(
        const RawBookingAnswer(document: null, fromCache: false),
      );

      expect(read.state, AdminBookingReadState.missing);
      expect(read.booking, isNull);
    });

    test('no document in the saved copy proves nothing: not known yet', () {
      final read = readBookingAnswer(
        const RawBookingAnswer(document: null, fromCache: true),
      );

      expect(read.state, AdminBookingReadState.notKnownYet);
      expect(read.booking, isNull);
    });

    test('a document that is not a booking is unreadable, with the reason '
        'and without the contents', () {
      final read = readBookingAnswer(
        RawBookingAnswer(
          document: rawBooking(
            'b1',
            fullName: 'Secret Person',
            changes: {'status': 'approved'},
          ),
          fromCache: false,
        ),
      );

      expect(read.state, AdminBookingReadState.unreadable);
      expect(read.booking, isNull);
      expect(read.reason, contains('status'));
      expect(read.reason, isNot(contains('Secret Person')));
    });
  });

  group('selectableStatuses', () {
    test('every status except the current one, in the fixed order', () {
      expect(selectableStatuses(BookingStatus.newBooking), [
        BookingStatus.pending,
        BookingStatus.confirmed,
        BookingStatus.cancelled,
      ]);
      expect(selectableStatuses(BookingStatus.confirmed), [
        BookingStatus.newBooking,
        BookingStatus.pending,
        BookingStatus.cancelled,
      ]);
    });

    test('any status can follow any other', () {
      for (final current in BookingStatus.values) {
        final choices = selectableStatuses(current);
        expect(choices, hasLength(BookingStatus.values.length - 1));
        expect(choices, isNot(contains(current)));
      }
    });
  });

  group('statusChangeNeedsConfirmation', () {
    bool asks(BookingStatus from, BookingStatus to) =>
        statusChangeNeedsConfirmation(from: from, to: to);

    test('asks before every change to cancelled', () {
      for (final from in [
        BookingStatus.newBooking,
        BookingStatus.pending,
        BookingStatus.confirmed,
      ]) {
        expect(asks(from, BookingStatus.cancelled), true, reason: from.name);
      }
    });

    test('asks before every change away from confirmed', () {
      for (final to in [
        BookingStatus.newBooking,
        BookingStatus.pending,
        BookingStatus.cancelled,
      ]) {
        expect(asks(BookingStatus.confirmed, to), true, reason: to.name);
      }
    });

    test('does not ask for the other changes', () {
      const quiet = [
        (BookingStatus.newBooking, BookingStatus.pending),
        (BookingStatus.newBooking, BookingStatus.confirmed),
        (BookingStatus.pending, BookingStatus.newBooking),
        (BookingStatus.pending, BookingStatus.confirmed),
        (BookingStatus.cancelled, BookingStatus.newBooking),
        (BookingStatus.cancelled, BookingStatus.pending),
        (BookingStatus.cancelled, BookingStatus.confirmed),
      ];
      for (final (from, to) in quiet) {
        expect(asks(from, to), false, reason: '${from.name} to ${to.name}');
      }
    });

    test('does not ask when nothing changes', () {
      for (final status in BookingStatus.values) {
        expect(asks(status, status), false, reason: status.name);
      }
    });
  });

  group('statusChangeFailureFromCode', () {
    test('unavailable and deadline-exceeded mean no connection', () {
      expect(
        statusChangeFailureFromCode('unavailable'),
        AdminStatusChangeFailure.noConnection,
      );
      expect(
        statusChangeFailureFromCode('deadline-exceeded'),
        AdminStatusChangeFailure.noConnection,
      );
    });

    test('permission-denied means refused', () {
      expect(
        statusChangeFailureFromCode('permission-denied'),
        AdminStatusChangeFailure.refused,
      );
    });

    test('not-found means the booking is gone', () {
      expect(
        statusChangeFailureFromCode('not-found'),
        AdminStatusChangeFailure.bookingMissing,
      );
    });

    test('anything else is unknown', () {
      for (final code in [
        'aborted',
        'internal',
        'cancelled',
        '',
        'UNAVAILABLE',
      ]) {
        expect(
          statusChangeFailureFromCode(code),
          AdminStatusChangeFailure.unknown,
          reason: code,
        );
      }
    });
  });

  group('noticeForFailure', () {
    test('each failure has its own notice, never "saved" or "no answer"', () {
      final notices = {
        for (final failure in AdminStatusChangeFailure.values)
          noticeForFailure(failure),
      };

      expect(notices, hasLength(AdminStatusChangeFailure.values.length));
      expect(notices, isNot(contains(AdminStatusChangeNotice.saved)));
      expect(notices, isNot(contains(AdminStatusChangeNotice.noAnswer)));
      expect(
        noticeForFailure(AdminStatusChangeFailure.noConnection),
        AdminStatusChangeNotice.noConnection,
      );
      expect(
        noticeForFailure(AdminStatusChangeFailure.refused),
        AdminStatusChangeNotice.refused,
      );
      expect(
        noticeForFailure(AdminStatusChangeFailure.bookingMissing),
        AdminStatusChangeNotice.bookingMissing,
      );
      expect(
        noticeForFailure(AdminStatusChangeFailure.unknown),
        AdminStatusChangeNotice.unknown,
      );
    });
  });

  test('the wait for the server is 20 seconds', () {
    expect(adminStatusChangeTimeout, const Duration(seconds: 20));
  });

  test('the exceptions carry no Firestore type and no customer data', () {
    expect(
      const AdminStatusChangeException(
        AdminStatusChangeFailure.refused,
      ).toString(),
      'AdminStatusChangeException(refused)',
    );
    expect(
      const AdminStatusChangeNoAnswer().toString(),
      'AdminStatusChangeNoAnswer',
    );
  });
}
