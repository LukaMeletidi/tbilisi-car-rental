import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';

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
