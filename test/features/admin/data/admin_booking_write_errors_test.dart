import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';

/// These tests only turn made-up errors into the app's own failures. They
/// do not contact Firebase.
FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('an error of the status change', () {
    test('"unavailable" and "deadline exceeded" become noConnection', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          mapStatusChangeError(firestoreError(code)).failure,
          AdminStatusChangeFailure.noConnection,
          reason: code,
        );
      }
    });

    test('"permission denied" becomes refused', () {
      expect(
        mapStatusChangeError(firestoreError('permission-denied')).failure,
        AdminStatusChangeFailure.refused,
      );
    });

    test('"not found" becomes bookingMissing', () {
      expect(
        mapStatusChangeError(firestoreError('not-found')).failure,
        AdminStatusChangeFailure.bookingMissing,
      );
    });

    test('any other code, and any other error, becomes unknown', () {
      expect(
        mapStatusChangeError(firestoreError('aborted')).failure,
        AdminStatusChangeFailure.unknown,
      );
      expect(
        mapStatusChangeError(StateError('made up')).failure,
        AdminStatusChangeFailure.unknown,
      );
    });

    test('an error that is already the app\'s own is passed on', () {
      const own = AdminStatusChangeException(
        AdminStatusChangeFailure.unknownFields,
        fields: ['zzTest'],
      );
      expect(mapStatusChangeError(own), same(own));
    });
  });

  group('an error of saving an edit', () {
    test('"unavailable" and "deadline exceeded" become noConnection', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          mapBookingSaveError(firestoreError(code)).failure,
          AdminBookingSaveFailure.noConnection,
          reason: code,
        );
      }
    });

    test('"permission denied" becomes refused', () {
      expect(
        mapBookingSaveError(firestoreError('permission-denied')).failure,
        AdminBookingSaveFailure.refused,
      );
    });

    test('"not found" becomes bookingMissing', () {
      expect(
        mapBookingSaveError(firestoreError('not-found')).failure,
        AdminBookingSaveFailure.bookingMissing,
      );
    });

    test('any other code, and any other error, becomes unknown', () {
      expect(
        mapBookingSaveError(firestoreError('aborted')).failure,
        AdminBookingSaveFailure.unknown,
      );
      expect(
        mapBookingSaveError(StateError('made up')).failure,
        AdminBookingSaveFailure.unknown,
      );
    });

    test('an error that is already the app\'s own is passed on', () {
      const own = AdminBookingSaveException(
        AdminBookingSaveFailure.conflict,
        fields: ['carId'],
      );
      expect(mapBookingSaveError(own), same(own));
    });

    test('a Firestore error carries no field names', () {
      expect(
        mapBookingSaveError(firestoreError('permission-denied')).fields,
        isEmpty,
      );
    });
  });

  group('an error of creating a booking', () {
    test('"unavailable" and "deadline exceeded" become noConnection', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          mapBookingCreateError(firestoreError(code)).failure,
          AdminBookingCreateFailure.noConnection,
          reason: code,
        );
      }
    });

    test('"permission denied" becomes refused', () {
      expect(
        mapBookingCreateError(firestoreError('permission-denied')).failure,
        AdminBookingCreateFailure.refused,
      );
    });

    test('any other code, and any other error, becomes unknown', () {
      for (final code in ['not-found', 'already-exists', 'aborted', '']) {
        expect(
          mapBookingCreateError(firestoreError(code)).failure,
          AdminBookingCreateFailure.unknown,
          reason: code,
        );
      }
      expect(
        mapBookingCreateError(StateError('made up')).failure,
        AdminBookingCreateFailure.unknown,
      );
    });

    test('an error that is already the app\'s own is passed on', () {
      const own = AdminBookingCreateException(
        AdminBookingCreateFailure.carMissing,
      );
      expect(mapBookingCreateError(own), same(own));
    });

    test('the codes for "no connection" and "refused" are mapped exactly '
        'as for a status change', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'permission-denied',
      ]) {
        expect(
          mapBookingCreateError(firestoreError(code)).failure.name,
          mapStatusChangeError(firestoreError(code)).failure.name,
          reason: code,
        );
      }
    });
  });

  group('an error of deleting a booking', () {
    test('"unavailable" and "deadline exceeded" become noConnection', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          mapBookingDeleteError(firestoreError(code)).failure,
          AdminBookingDeleteFailure.noConnection,
          reason: code,
        );
      }
    });

    test('"permission denied" becomes refused', () {
      expect(
        mapBookingDeleteError(firestoreError('permission-denied')).failure,
        AdminBookingDeleteFailure.refused,
      );
    });

    test('any other code, and any other error, becomes unknown', () {
      for (final code in ['not-found', 'aborted', 'failed-precondition', '']) {
        expect(
          mapBookingDeleteError(firestoreError(code)).failure,
          AdminBookingDeleteFailure.unknown,
          reason: code,
        );
      }
      expect(
        mapBookingDeleteError(StateError('made up')).failure,
        AdminBookingDeleteFailure.unknown,
      );
    });

    test('an error that is already the app\'s own is passed on', () {
      const own = AdminBookingDeleteException(
        AdminBookingDeleteFailure.statusChanged,
      );
      expect(mapBookingDeleteError(own), same(own));
    });

    test('the codes for "no connection" and "refused" are mapped exactly '
        'as for a status change', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'permission-denied',
      ]) {
        expect(
          mapBookingDeleteError(firestoreError(code)).failure.name,
          mapStatusChangeError(firestoreError(code)).failure.name,
          reason: code,
        );
      }
    });
  });

  test('every Firestore code is mapped for an edit exactly as for a status '
      'change', () {
    for (final code in [
      'unavailable',
      'deadline-exceeded',
      'permission-denied',
      'not-found',
      'aborted',
      'cancelled',
      'internal',
      'failed-precondition',
      'resource-exhausted',
      'unauthenticated',
      'unknown',
      '',
    ]) {
      final status = mapStatusChangeError(firestoreError(code)).failure;
      final save = mapBookingSaveError(firestoreError(code)).failure;
      expect(save.name, status.name, reason: code);
    }
  });
}
