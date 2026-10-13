import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
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
  ///
  /// Metadata changes are included, so that an answer of the server comes
  /// also when it only confirms what was known. What an empty answer means
  /// is decided by [activeCarsFrom].
  Stream<List<Car>> watchActiveCars() {
    return activeCarsFrom(
      _firestore
          .collection('cars')
          .where('active', isEqualTo: true)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => (
              documents: [
                for (final doc in snapshot.docs) (id: doc.id, data: doc.data()),
              ],
              fromCache: snapshot.metadata.isFromCache,
            ),
          ),
    );
  }

  /// Live data of one car, for the detail screen.
  ///
  /// Reports a [CarNotAvailableException] when the car does not exist, is
  /// not active, or cannot be read as a car. The Firestore rules refuse
  /// reading such a car with "permission denied"; that refusal is translated
  /// here, so screens never see a Firestore error type.
  ///
  /// A car that is missing only because the server has not answered yet is
  /// NOT "not available"; see [carFrom].
  Stream<Car> watchCar(String id) {
    return carFrom(
      id,
      _firestore
          .collection('cars')
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => (
              data: snapshot.data(),
              fromCache: snapshot.metadata.isFromCache,
            ),
          ),
    );
  }
}

/// One answer of the cars query, reduced to plain Dart.
typedef CarsAnswer = ({List<RawCarDocument> documents, bool fromCache});

/// The active cars for each answer of the query.
///
/// An empty answer that did not come from the server is not "no cars": it
/// is waited out, and after [serverAnswerWait] the stream reports a
/// [NoServerAnswerException] (see [waitForServerAnswer]). An empty answer
/// of the server is an empty list.
Stream<List<Car>> activeCarsFrom(
  Stream<CarsAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.documents.isEmpty,
    fromCache: (answer) => answer.fromCache,
    read: (answer) => parseCars(answer.documents, onSkipped: _logSkippedCar),
    wait: wait,
  );
}

/// The car [id] for each answer of the live read of its document.
///
/// Reports a [CarNotAvailableException] when the SERVER says there is no
/// such car, when the car is not active, when it cannot be read as a car,
/// and when the rules refuse the read. A document that is missing in an
/// answer that did not come from the server is waited out instead, and
/// after [serverAnswerWait] reported as a [NoServerAnswerException].
Stream<Car> carFrom(
  String id,
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) {
      final data = answer.data;
      if (data == null) throw const CarNotAvailableException();
      final Car car;
      try {
        car = Car.fromMap(id, data);
      } catch (error, stackTrace) {
        _logSkippedCar(id, error, stackTrace);
        throw const CarNotAvailableException();
      }
      if (!car.active) throw const CarNotAvailableException();
      return car;
    },
    wait: wait,
  ).handleError((Object error, StackTrace stackTrace) {
    Error.throwWithStackTrace(mapCarReadError(error), stackTrace);
  });
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
