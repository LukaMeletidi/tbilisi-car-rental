import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  test('"permission denied" becomes rejected', () {
    expect(
      mapBookingCreateError(firestoreError('permission-denied')).failure,
      BookingCreateFailure.rejected,
    );
  });

  test('"unavailable" and "deadline exceeded" become noConnection', () {
    expect(
      mapBookingCreateError(firestoreError('unavailable')).failure,
      BookingCreateFailure.noConnection,
    );
    expect(
      mapBookingCreateError(firestoreError('deadline-exceeded')).failure,
      BookingCreateFailure.noConnection,
    );
  });

  test('a timeout becomes noConnection', () {
    expect(
      mapBookingCreateError(TimeoutException('too slow')).failure,
      BookingCreateFailure.noConnection,
    );
  });

  test('any other error becomes unknown', () {
    expect(
      mapBookingCreateError(firestoreError('internal')).failure,
      BookingCreateFailure.unknown,
    );
    expect(
      mapBookingCreateError(StateError('broken')).failure,
      BookingCreateFailure.unknown,
    );
    expect(
      mapBookingCreateError(const FormatException('bad')).failure,
      BookingCreateFailure.unknown,
    );
  });

  test('a BookingCreateException stays what it is', () {
    const error = BookingCreateException(BookingCreateFailure.rejected);
    expect(mapBookingCreateError(error), same(error));
  });

  test('exceptions with the same reason are equal', () {
    expect(
      const BookingCreateException(BookingCreateFailure.unknown),
      const BookingCreateException(BookingCreateFailure.unknown),
    );
    expect(
      const BookingCreateException(BookingCreateFailure.unknown) ==
          const BookingCreateException(BookingCreateFailure.rejected),
      false,
    );
  });
}
