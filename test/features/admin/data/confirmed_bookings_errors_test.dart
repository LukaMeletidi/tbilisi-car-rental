import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// These tests only turn made-up errors into failures and check the ID
/// guard. They do not contact Firebase.
FirebaseException firestoreError(String code, {String? message}) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

/// Records whether Firestore was touched at all, and then fails.
class _RecordingFirestore implements FirebaseFirestore {
  var touched = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    touched = true;
    throw StateError('no Firestore in this test');
  }
}

void main() {
  group('conflictCheckFailureOf', () {
    test('no answer in time: timeout', () {
      expect(
        conflictCheckFailureOf(TimeoutException('late')),
        ConflictCheckFailure.timeout,
      );
    });

    test('Firestore codes, also with the web prefix', () {
      final expected = {
        'unavailable': ConflictCheckFailure.noConnection,
        'firestore/unavailable': ConflictCheckFailure.noConnection,
        'deadline-exceeded': ConflictCheckFailure.timeout,
        'permission-denied': ConflictCheckFailure.refused,
        'aborted': ConflictCheckFailure.other,
        'failed-precondition': ConflictCheckFailure.other,
      };
      for (final entry in expected.entries) {
        expect(
          conflictCheckFailureOf(firestoreError(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('any other error, also of the app itself: other', () {
      expect(
        conflictCheckFailureOf(StateError('broken')),
        ConflictCheckFailure.other,
      );
      expect(
        conflictCheckFailureOf(ArgumentError('bad')),
        ConflictCheckFailure.other,
      );
    });
  });

  test('the debug line shows a type or a code, never a message', () {
    expect(
      conflictCheckErrorKind(
        firestoreError('aborted', message: 'Secret message'),
      ),
      'FirebaseException(code: aborted)',
    );
    final kind = conflictCheckErrorKind(StateError('Secret value'));
    expect(kind, 'StateError');
    expect(kind, isNot(contains('Secret')));
  });

  group('the car ID guard: exactly the IDs the cars rules allow', () {
    final accepted = [
      'car-a',
      'a_b-c',
      // 20 characters, mixed case and digits, like an automatic ID (built
      // here, so it is plainly made up).
      'aB3d' * 5,
      'x' * 128,
    ];
    final refused = ['', 'x' * 129, 'cars/a', 'car a'];

    test('the pattern', () {
      for (final id in accepted) {
        expect(isPlausibleCarId(id), true, reason: id);
      }
      for (final id in refused) {
        expect(isPlausibleCarId(id), false, reason: id);
      }
    });

    test('a refused ID: could not be checked, Firestore not touched', () async {
      for (final id in refused) {
        final firestore = _RecordingFirestore();
        final read = await AdminBookingsRepository(
          firestore,
        ).readConfirmedBookingsOfCar(id);
        expect(
          (read as ConfirmedBookingsUnchecked).failure,
          ConflictCheckFailure.other,
          reason: id,
        );
        expect(firestore.touched, false, reason: id);
      }
    });

    test('an accepted ID does ask Firestore (and a failure there is "could '
        'not be checked", never a crash)', () async {
      for (final id in accepted) {
        final firestore = _RecordingFirestore();
        final read = await AdminBookingsRepository(
          firestore,
        ).readConfirmedBookingsOfCar(id);
        expect(firestore.touched, true, reason: id);
        expect(read, isA<ConfirmedBookingsUnchecked>(), reason: id);
      }
    });
  });
}
