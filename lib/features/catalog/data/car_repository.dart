import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';

class CarRepository {
  CarRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Live list of the cars with active == true.
  ///
  /// The Firestore rules allow reading active cars only, so this query must
  /// keep the `active` filter or Firestore rejects it.
  Stream<List<Car>> watchActiveCars() {
    return _firestore
        .collection('cars')
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => parseCars([
            for (final doc in snapshot.docs) (id: doc.id, data: doc.data()),
          ], onSkipped: _logSkippedCar),
        );
  }

  /// Live data of one car, for the detail screen.
  ///
  /// Reports a [CarNotAvailableException] when the car does not exist, is
  /// not active, or cannot be read as a car. The Firestore rules refuse
  /// reading such a car with "permission denied"; that refusal is translated
  /// here, so screens never see a Firestore error type.
  Stream<Car> watchCar(String id) {
    return _firestore
        .collection('cars')
        .doc(id)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) throw const CarNotAvailableException();
          final Car car;
          try {
            car = Car.fromMap(snapshot.id, data);
          } catch (error, stackTrace) {
            _logSkippedCar(snapshot.id, error, stackTrace);
            throw const CarNotAvailableException();
          }
          if (!car.active) throw const CarNotAvailableException();
          return car;
        })
        .handleError((Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(mapCarReadError(error), stackTrace);
        });
  }
}

/// Turns Firestore's "permission denied" into a [CarNotAvailableException].
/// Every other error is returned unchanged.
Object mapCarReadError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return const CarNotAvailableException();
  }
  return error;
}

void _logSkippedCar(String id, Object error, StackTrace stackTrace) {
  developer.log(
    'Skipped car document "$id": $error',
    name: 'CarRepository',
    level: 900, // warning
    error: error,
    stackTrace: stackTrace,
  );
}

final carRepositoryProvider = Provider<CarRepository>(
  (ref) => CarRepository(FirebaseFirestore.instance),
);
