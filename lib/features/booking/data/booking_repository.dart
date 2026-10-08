import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_firestore_mapping.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

/// Access to the "bookings" collection. The public app can only create a
/// booking; the Firestore rules refuse reading, changing and deleting.
class BookingRepository {
  BookingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Sends [booking] and returns the ID of the new document once the server
  /// has confirmed it.
  ///
  /// The write runs in a transaction, because a transaction is never kept
  /// in the offline queue: without a connection it fails instead of being
  /// sent later. It is tried once. Every call uses a new document ID, so
  /// calling again after a failure can create a second request; that is
  /// accepted.
  ///
  /// Throws a [BookingCreateException] when the server refuses the request,
  /// does not confirm within [timeout], or anything else goes wrong.
  Future<String> createBooking(
    Booking booking, {
    Duration timeout = bookingCreateTimeout,
  }) async {
    final data = newBookingDocument(booking);
    final document = _firestore.collection('bookings').doc();
    try {
      await _firestore
          .runTransaction<void>(
            (transaction) async => transaction.set(document, data),
            timeout: timeout,
            maxAttempts: 1,
          )
          // The plugin's own timeout does not cover every platform and
          // every stage of the transaction, so the wait is limited here too.
          .timeout(timeout);
      return document.id;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapBookingCreateError(error), stackTrace);
    }
  }
}

/// Turns an error of [BookingRepository.createBooking] into a
/// [BookingCreateException], so screens never see a Firestore error type.
BookingCreateException mapBookingCreateError(Object error) {
  if (error is BookingCreateException) return error;
  if (error is TimeoutException) {
    return const BookingCreateException(BookingCreateFailure.noConnection);
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const BookingCreateException(BookingCreateFailure.rejected);
      case 'unavailable':
      case 'deadline-exceeded':
        return const BookingCreateException(BookingCreateFailure.noConnection);
    }
  }
  return const BookingCreateException(BookingCreateFailure.unknown);
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(FirebaseFirestore.instance),
);
