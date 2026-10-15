import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// The admin's access to the "cars" collection: the live list of every car,
/// and the writes. Only an account with the admin claim may read every car
/// or write one; the Firestore rules check it. This is the only file of the
/// fleet feature that talks to Firestore. It hands on plain Dart values and
/// never a Firestore type.
///
/// Every write runs in a transaction, tried once, with [carWriteTimeout]: a
/// transaction is never kept in the offline queue, so without a connection
/// it fails instead of being sent later. The caller says "Saved" only after
/// a method returned. A [CarWriteNoAnswer] does NOT mean "not saved".
/// Nothing is logged.
class FleetRepository {
  FleetRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Every car, also the hidden ones, live: a new answer comes whenever a
  /// car is added, changed or removed.
  ///
  /// Metadata changes are included, so that an answer of the server comes
  /// also when it only confirms what was known; [RawCarsResult.fromCache]
  /// says which an answer is. What an empty answer means is decided by the
  /// provider (answerMeaning), as for the bookings list.
  ///
  /// An error is reported as a [FleetLoadException].
  Stream<RawCarsResult> watchAllCars() {
    return _firestore
        .collection('cars')
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => RawCarsResult(
            documents: [
              for (final document in snapshot.docs)
                (id: document.id, data: document.data()),
            ],
            fromCache: snapshot.metadata.isFromCache,
          ),
        )
        .handleError((Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(mapFleetLoadError(error), stackTrace);
        });
  }

  /// One car, live, for the edit form: a new answer comes whenever it is
  /// changed or removed. Metadata changes are included, so that the
  /// server's answer comes also when it only confirms the saved copy;
  /// readCarAnswer decides what an answer means.
  ///
  /// [id] must pass isPlausibleCarId. An error is reported as a
  /// [FleetLoadException].
  Stream<RawCarAnswer> watchCar(String id) {
    return _document(id)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final data = snapshot.data();
          return RawCarAnswer(
            document: data == null ? null : (id: snapshot.id, data: data),
            fromCache: snapshot.metadata.isFromCache,
          );
        })
        .handleError((Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(mapFleetLoadError(error), stackTrace);
        });
  }

  /// A new, unused car ID, made on the device; no request is sent. The
  /// "new car" form asks for one when it opens and uses it for every
  /// attempt, so a repeated attempt never creates a second car.
  String newCarId() => _firestore.collection('cars').doc().id;

  /// Creates [car] as the document car.id and returns once the server has
  /// confirmed it.
  ///
  /// The transaction reads the document first. When it exists, nothing is
  /// written and [CarCreateResult.alreadyCreated] is returned: an earlier
  /// attempt with this ID, whose answer never arrived, created it. So a car
  /// is never created twice. Otherwise it writes carDocument(car).
  ///
  /// Throws a [CarWriteException] when the car was certainly not created,
  /// and a [CarWriteNoAnswer] when the server did not answer in time.
  Future<CarCreateResult> createCar(
    Car car, {
    Duration timeout = carWriteTimeout,
  }) async {
    final document = _document(car.id);
    final data = carDocument(car);
    try {
      return await _firestore
          .runTransaction<CarCreateResult>(
            (transaction) async {
              final existing = await transaction.get(document);
              if (existing.exists) return CarCreateResult.alreadyCreated;
              transaction.set(document, data);
              return CarCreateResult.created;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          // The plugin's own timeout does not cover every platform and
          // every stage of the transaction, so the wait is limited here too.
          .timeout(timeout);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapCarWriteError(error), stackTrace);
    }
  }

  /// Replaces the WHOLE stored document car.id with carDocument(car), as a
  /// set without merge: an old incomplete car is repaired in one save, and
  /// a field the rules do not know is dropped.
  ///
  /// [base] is the car the form started from. The transaction reads the
  /// stored document and decides with decideReplace: no document ->
  /// carMissing; already exactly [car] -> returns normally without a write
  /// (a retry after a lost answer, or a save without a change); changed
  /// since [base] -> changedElsewhere, without a write.
  ///
  /// Throws a [CarWriteException] when the car was certainly not saved, and
  /// a [CarWriteNoAnswer] when the server did not answer in time.
  Future<void> replaceCar(
    Car car, {
    required Car base,
    Duration timeout = carWriteTimeout,
  }) async {
    if (base.id != car.id) {
      throw ArgumentError('The base and the car have different IDs.');
    }
    final document = _document(car.id);
    final data = carDocument(car);
    final CarReplaceDecision decision;
    try {
      decision = await _firestore
          .runTransaction<CarReplaceDecision>(
            (transaction) async {
              final stored = await transaction.get(document);
              final decision = decideReplace(
                storedData: stored.data(),
                base: base,
                target: car,
              );
              if (decision == CarReplaceDecision.write) {
                transaction.set(document, data);
              }
              return decision;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          .timeout(timeout);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapCarWriteError(error), stackTrace);
    }
    switch (decision) {
      case CarReplaceDecision.write:
      case CarReplaceDecision.alreadySaved:
        return;
      case CarReplaceDecision.carMissing:
        throw const CarWriteException(CarWriteFailure.carMissing);
      case CarReplaceDecision.changedElsewhere:
        throw const CarWriteException(CarWriteFailure.changedElsewhere);
    }
  }

  /// Hides (false) or shows (true) the car [id].
  ///
  /// The write changes "active" and nothing else
  /// (transaction.update(document, {'active': active})), so the rules accept
  /// it for every stored car, also an old one that fails their full check.
  /// When the stored "active" already is that bool, nothing is written and
  /// it returns normally (decideSetActive).
  ///
  /// Throws a [CarWriteException] when it certainly did not happen, and a
  /// [CarWriteNoAnswer] when the server did not answer in time.
  Future<void> setCarActive(
    String id, {
    required bool active,
    Duration timeout = carWriteTimeout,
  }) async {
    final document = _document(id);
    final CarActiveDecision decision;
    try {
      decision = await _firestore
          .runTransaction<CarActiveDecision>(
            (transaction) async {
              final stored = await transaction.get(document);
              final decision = decideSetActive(
                storedData: stored.data(),
                active: active,
              );
              if (decision == CarActiveDecision.write) {
                transaction.update(document, {'active': active});
              }
              return decision;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          .timeout(timeout);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapCarWriteError(error), stackTrace);
    }
    if (decision == CarActiveDecision.carMissing) {
      throw const CarWriteException(CarWriteFailure.carMissing);
    }
  }

  /// The document of the car [id]. An ID of another shape than the rules
  /// allow is refused before anything is sent.
  DocumentReference<Map<String, dynamic>> _document(String id) {
    if (!isPlausibleCarId(id)) {
      throw ArgumentError('This cannot be the ID of a car.');
    }
    return _firestore.collection('cars').doc(id);
  }
}

/// Turns an error of a car write into what the caller handles, so screens
/// never see a Firestore error type: no answer in time becomes
/// [CarWriteNoAnswer]; a Firestore error becomes a [CarWriteException] with
/// the reason of its code; a [CarWriteException] or [CarWriteNoAnswer]
/// stays; anything else is an unknown failure.
Object mapCarWriteError(Object error) {
  if (error is CarWriteException || error is CarWriteNoAnswer) return error;
  if (error is TimeoutException) return const CarWriteNoAnswer();
  if (error is FirebaseException) {
    return CarWriteException(carWriteFailureFromCode(error.code));
  }
  // Only the type, never the message or a value: it tells which error
  // the web (or another platform) sends, so that it can be mapped later.
  developer.log(
    'An unexpected error type in a car write: ${error.runtimeType}',
    name: 'FleetRepository',
    level: 900, // warning
  );
  return const CarWriteException(CarWriteFailure.unknown);
}

/// Turns an error of reading the cars into a [FleetLoadException].
FleetLoadException mapFleetLoadError(Object error) {
  if (error is FleetLoadException) return error;
  if (error is FirebaseException) {
    return FleetLoadException(fleetLoadFailureFromCode(error.code));
  }
  return const FleetLoadException(FleetLoadFailure.other);
}

final fleetRepositoryProvider = Provider<FleetRepository>(
  (ref) => FleetRepository(FirebaseFirestore.instance),
);
