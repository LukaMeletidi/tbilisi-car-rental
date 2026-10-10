import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_firestore_mapping.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';

/// What the admin area reads from Firestore: the bookings and all cars.
/// Only an account with the admin claim may read them; the Firestore rules
/// refuse everybody else.
///
/// This is the only file of the admin area that talks to Firestore. It
/// hands on plain Dart values and never a Firestore type.
class AdminBookingsRepository {
  AdminBookingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// The newest [limit] bookings, newest first, live: a new answer comes
  /// whenever a booking is added, changed or removed.
  ///
  /// The query orders by createdAt, so a document without createdAt is not
  /// returned at all. Every booking made through the app has it.
  ///
  /// Metadata changes are included, so that a new answer also comes when
  /// the same data is confirmed by the server after it was first shown
  /// from the copy saved on the device. [RawBookingsResult.fromCache] says
  /// which of the two an answer is. On web there is no saved copy and it is
  /// always false.
  ///
  /// The dates of each document are turned into UTC DateTime values here.
  /// Reading a document as a booking, and skipping one that cannot be read,
  /// is done by parseBookings.
  ///
  /// An error is reported as an [AdminBookingsException].
  Stream<RawBookingsResult> watchNewestBookings({required int limit}) {
    return _firestore
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => RawBookingsResult(
            documents: [
              for (final document in snapshot.docs)
                (
                  id: document.id,
                  data: bookingMapFromFirestore(document.data()),
                ),
            ],
            fromCache: snapshot.metadata.isFromCache,
          ),
        )
        .handleError((Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(mapAdminBookingsError(error), stackTrace);
        });
  }

  /// Every car once, also the hidden ones, so that a row can show the car
  /// of an old booking. A car document that cannot be read is skipped and
  /// logged, as in the catalog.
  ///
  /// Throws an [AdminBookingsException] when the cars cannot be loaded.
  Future<List<Car>> readAllCars() async {
    try {
      final snapshot = await _firestore.collection('cars').get();
      return parseCars([
        for (final document in snapshot.docs)
          (id: document.id, data: document.data()),
      ], onSkipped: _logSkippedCar);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapAdminBookingsError(error), stackTrace);
    }
  }
}

/// Turns an error of Firestore into an [AdminBookingsException], so screens
/// never see a Firestore error type.
AdminBookingsException mapAdminBookingsError(Object error) {
  if (error is AdminBookingsException) return error;
  if (error is FirebaseException) {
    return AdminBookingsException(adminBookingsFailureFromCode(error.code));
  }
  return const AdminBookingsException(AdminBookingsFailure.other);
}

void _logSkippedCar(String id, Object error, StackTrace stackTrace) {
  developer.log(
    'Skipped car document "$id": $error',
    name: 'AdminBookingsRepository',
    level: 900, // warning
    error: error,
    stackTrace: stackTrace,
  );
}

final adminBookingsRepositoryProvider = Provider<AdminBookingsRepository>(
  (ref) => AdminBookingsRepository(FirebaseFirestore.instance),
);
