import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

import '../../../support/fake_admin_bookings_repository.dart';

void main() {
  group('deleteNeedsStrongWarning', () {
    test('only for a confirmed booking', () {
      for (final status in BookingStatus.values) {
        expect(
          deleteNeedsStrongWarning(status),
          status == BookingStatus.confirmed,
          reason: status.name,
        );
      }
    });
  });

  group('statusChangedElsewhere', () {
    test('false when the stored status is the one that was shown', () {
      for (final status in BookingStatus.values) {
        expect(
          statusChangedElsewhere(
            shown: status,
            storedStatus: status.storedName,
          ),
          false,
          reason: status.name,
        );
      }
    });

    test('true for every other status', () {
      for (final shown in BookingStatus.values) {
        for (final stored in BookingStatus.values) {
          if (shown == stored) continue;
          expect(
            statusChangedElsewhere(
              shown: shown,
              storedStatus: stored.storedName,
            ),
            true,
            reason: '${shown.name} shown, ${stored.name} stored',
          );
        }
      }
    });

    test('true for a status that is missing or not a known text: the '
        'booking is not what the admin saw', () {
      for (final stored in [null, '', 'New', 'approved', 1, true]) {
        expect(
          statusChangedElsewhere(
            shown: BookingStatus.newBooking,
            storedStatus: stored,
          ),
          true,
          reason: '$stored',
        );
      }
    });
  });

  group('deleteFailureFromCode', () {
    test('the Firestore codes map as for a status change', () {
      expect(
        deleteFailureFromCode('unavailable'),
        AdminBookingDeleteFailure.noConnection,
      );
      expect(
        deleteFailureFromCode('deadline-exceeded'),
        AdminBookingDeleteFailure.noConnection,
      );
      expect(
        deleteFailureFromCode('permission-denied'),
        AdminBookingDeleteFailure.refused,
      );
      for (final code in ['not-found', 'aborted', 'internal', '']) {
        expect(
          deleteFailureFromCode(code),
          AdminBookingDeleteFailure.unknown,
          reason: code,
        );
      }
    });

    test('no Firestore code means "the status changed": that is found by '
        'the transaction itself', () {
      for (final code in ['permission-denied', 'aborted', 'not-found']) {
        expect(
          deleteFailureFromCode(code),
          isNot(AdminBookingDeleteFailure.statusChanged),
        );
      }
    });
  });

  group('noticeForDeleteFailure', () {
    test('each failure has its own notice, never "no answer"', () {
      final notices = {
        for (final failure in AdminBookingDeleteFailure.values)
          noticeForDeleteFailure(failure),
      };

      expect(notices, hasLength(AdminBookingDeleteFailure.values.length));
      expect(notices, isNot(contains(AdminBookingDeleteNotice.noAnswer)));
      for (final failure in AdminBookingDeleteFailure.values) {
        expect(noticeForDeleteFailure(failure).name, failure.name);
      }
    });
  });

  group('deletedOutcome', () {
    AdminDeletedNotice? outcome({
      AdminBookingDeleteResult? result,
      AdminBookingDeleteNotice? notice,
      bool gone = false,
    }) => deletedOutcome(result: result, notice: notice, goneInLiveRead: gone);

    test('the transaction deleted it: "Booking deleted.", whether or not '
        'the live read was faster', () {
      for (final gone in [false, true]) {
        expect(
          outcome(result: AdminBookingDeleteResult.deleted, gone: gone),
          AdminDeletedNotice.deleted,
        );
      }
    });

    test('the transaction found none: "already deleted"', () {
      for (final gone in [false, true]) {
        expect(
          outcome(result: AdminBookingDeleteResult.alreadyDeleted, gone: gone),
          AdminDeletedNotice.alreadyDeleted,
        );
      }
    });

    test('no answer or a failure, and the booking is still there: it stays '
        'on screen', () {
      for (final notice in AdminBookingDeleteNotice.values) {
        expect(outcome(notice: notice), isNull, reason: notice.name);
      }
    });

    test('no answer or a failure, but the live read already said '
        '"missing": the booking is gone, "Booking deleted."', () {
      for (final notice in AdminBookingDeleteNotice.values) {
        expect(
          outcome(notice: notice, gone: true),
          AdminDeletedNotice.deleted,
          reason: notice.name,
        );
      }
    });
  });

  group('the texts', () {
    test('after a failed delete: "no answer" is not "Not deleted"; the '
        'rest say "Not deleted."', () {
      final texts = {
        for (final notice in AdminBookingDeleteNotice.values)
          notice: adminDeleteNoticeText(notice),
      };

      expect(texts.values.toSet(), hasLength(texts.length));
      expect(
        texts[AdminBookingDeleteNotice.noAnswer],
        'No answer from the server. If the booking is still shown here, '
        'it was not deleted.',
      );
      expect(
        texts[AdminBookingDeleteNotice.noConnection],
        'Not deleted. No connection.',
      );
      expect(
        texts[AdminBookingDeleteNotice.refused],
        'Not deleted. The change was refused.',
      );
      expect(
        texts[AdminBookingDeleteNotice.statusChanged],
        'Not deleted. The status of this booking was changed elsewhere. '
        'Look at it again.',
      );
      expect(
        texts[AdminBookingDeleteNotice.unknown],
        'Not deleted. Please try again.',
      );
    });

    test('on the list', () {
      expect(
        adminDeletedNoticeText(AdminDeletedNotice.deleted),
        'Booking deleted.',
      );
      expect(
        adminDeletedNoticeText(AdminDeletedNotice.alreadyDeleted),
        'This booking was already deleted.',
      );
    });

    test('the question and its words', () {
      expect(adminDeleteButton, 'Delete this booking');
      expect(adminDeleteTitle, 'Delete this booking?');
      expect(adminDeleteYes, 'Delete');
      expect(adminConfirmNo, 'Keep');
      expect(adminDeleteCannotBeUndone, contains('cannot be undone'));
      expect(adminDeleteCannotBeUndone, contains('Cancelled'));
      expect(
        adminDeleteConfirmedWarning,
        'This booking is confirmed. The customer expects the car.',
      );
    });

    test('the lines that say which booking it is: the name, the car, the '
        'pickup in Tbilisi time and the status', () {
      final booking = Booking.fromMap(
        'b1',
        rawBooking('b1', fullName: 'Delete Test One', status: 'pending').data,
      );

      expect(
        adminDeleteDialogLines(
          booking,
          const AdminCarLabel(AdminCarState.hidden, 'Toyota Prius, 2019'),
        ),
        [
          'Delete Test One',
          'Toyota Prius, 2019 (hidden)',
          // Stored 14:00 UTC.
          'Pickup: 10 Jan 2026 18:00',
          'Status: Pending',
        ],
      );
      expect(
        adminDeleteDialogLines(
          booking,
          const AdminCarLabel(AdminCarState.notFound),
        )[1],
        'Car not found',
      );
    });

    test('the lines hold no phone, e-mail or note', () {
      final booking = Booking.fromMap(
        'b1',
        rawBooking('b1', changes: {'notes': 'A made-up note.'}).data,
      );
      final lines = adminDeleteDialogLines(
        booking,
        const AdminCarLabel(AdminCarState.active, 'Toyota Prius, 2019'),
      ).join('\n');

      expect(lines.contains('+995'), false);
      expect(lines.contains('@'), false);
      expect(lines.contains('made-up note'), false);
    });
  });

  test('the exceptions carry no Firestore type and no customer data', () {
    expect(
      const AdminBookingDeleteException(
        AdminBookingDeleteFailure.statusChanged,
      ).toString(),
      'AdminBookingDeleteException(statusChanged)',
    );
    expect(
      const AdminBookingDeleteNoAnswer().toString(),
      'AdminBookingDeleteNoAnswer',
    );
  });
}
