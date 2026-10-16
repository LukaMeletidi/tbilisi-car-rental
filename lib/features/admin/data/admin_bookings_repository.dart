import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_document.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_firestore_mapping.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

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

  /// Every confirmed booking of every car, of all time, live: for the
  /// calendar, which cuts its days out in Dart. One equality filter, so no
  /// composite index is needed. The documents come in no particular order.
  ///
  /// Metadata changes are included, as in [watchNewestBookings];
  /// [RawBookingsResult.fromCache] says whether an answer came from the
  /// server. The dates are turned into UTC DateTime values here. An error
  /// is reported as an [AdminBookingsException].
  Stream<RawBookingsResult> watchConfirmedBookings() {
    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: BookingStatus.confirmed.storedName)
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
  /// Without a connection Firestore answers a read like this one from
  /// what it holds in memory; an empty answer of that kind is "no
  /// connection" and never "there are no cars".
  Future<List<Car>> readAllCars() async {
    try {
      final snapshot = await _firestore.collection('cars').get();
      _requireServerAnswer(
        isEmpty: snapshot.docs.isEmpty,
        fromCache: snapshot.metadata.isFromCache,
      );
      return parseCars([
        for (final document in snapshot.docs)
          (id: document.id, data: document.data()),
      ], onSkipped: _logSkippedCar);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapAdminBookingsError(error), stackTrace);
    }
  }

  /// One booking, live: a new answer comes whenever the document changes or
  /// is deleted. [RawBookingAnswer.document] is null when there is no
  /// document with [id].
  ///
  /// Metadata changes are included, so that an answer from the copy saved
  /// on the device is followed by one from the server;
  /// [RawBookingAnswer.fromCache] says which of the two an answer is. A
  /// missing document in the saved copy does not mean the booking does not
  /// exist; readBookingAnswer makes that difference.
  ///
  /// The dates are turned into UTC DateTime values here. An error is
  /// reported as an [AdminBookingsException].
  Stream<RawBookingAnswer> watchBooking(String id) {
    return _firestore
        .collection('bookings')
        .doc(id)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final data = snapshot.data();
          return RawBookingAnswer(
            document: data == null
                ? null
                : (id: snapshot.id, data: bookingMapFromFirestore(data)),
            fromCache: snapshot.metadata.isFromCache,
          );
        })
        .handleError((Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(mapAdminBookingsError(error), stackTrace);
        });
  }

  /// One car by its ID, also a hidden one. Null when no car has that ID or
  /// when its document cannot be read as a car (that is logged).
  ///
  /// Throws an [AdminBookingsException] when the car cannot be loaded;
  /// also when the document is missing only in an answer that did not
  /// come from the server.
  Future<Car?> readCar(String id) async {
    try {
      final snapshot = await _firestore.collection('cars').doc(id).get();
      final data = snapshot.data();
      _requireServerAnswer(
        isEmpty: data == null,
        fromCache: snapshot.metadata.isFromCache,
      );
      if (data == null) return null;
      final cars = parseCars([
        (id: snapshot.id, data: data),
      ], onSkipped: _logSkippedCar);
      return cars.isEmpty ? null : cars.single;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapAdminBookingsError(error), stackTrace);
    }
  }

  /// The confirmed bookings of the car [carId], read once from the SERVER
  /// (never from memory), for a conflict or hide check. Equality filters
  /// only, so no composite index is needed.
  ///
  /// Never throws: a missing connection, an answer from memory, the
  /// [timeout], a refusal and any other error, also of the app itself,
  /// are a [ConfirmedBookingsUnchecked]. Only the kind of failure is
  /// printed, in debug builds; never a value of a booking.
  Future<ConfirmedBookingsRead> readConfirmedBookingsOfCar(
    String carId, {
    Duration timeout = conflictCheckTimeout,
  }) async {
    // The car IDs the cars rules allow; anything else is never asked for.
    if (!isPlausibleCarId(carId)) {
      return const ConfirmedBookingsUnchecked(ConflictCheckFailure.other);
    }
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('carId', isEqualTo: carId)
          .where('status', isEqualTo: BookingStatus.confirmed.storedName)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      return readConfirmedBookings(
        [
          for (final document in snapshot.docs)
            (id: document.id, data: bookingMapFromFirestore(document.data())),
        ],
        fromCache: snapshot.metadata.isFromCache,
        carId: carId,
      );
    } catch (error) {
      final failure = conflictCheckFailureOf(error);
      if (kDebugMode) {
        debugPrint(
          'A conflict check could not read the bookings: ${failure.name} '
          '(${conflictCheckErrorKind(error)})',
        );
      }
      return ConfirmedBookingsUnchecked(failure);
    }
  }

  /// Changes the status of the booking [id] to [status] and returns once
  /// the server has confirmed it.
  ///
  /// Only the field "status" is written. The Firestore rules accept that
  /// from an admin; any other field (for example an "updatedAt") would be
  /// refused by them.
  ///
  /// The rules check the whole document on every update. A stored document
  /// with a field they do not know, or without createdAt, would be refused
  /// with a bare "permission denied"; the transaction finds that first and
  /// reports it by name. The same goes for a stored value in a form the
  /// rules refuse (a phone, a name, an e-mail or the text of a place
  /// written by hand with spaces).
  ///
  /// It runs in a transaction, tried once. A transaction is never kept in
  /// the offline queue and never changes the saved copy first: without a
  /// connection it fails instead of being sent later. The transaction
  /// reads the booking first, so a booking that was deleted meanwhile is
  /// noticed.
  ///
  /// Throws an [AdminStatusChangeException] when the change was certainly
  /// not saved, and an [AdminStatusChangeNoAnswer] when the server did not
  /// answer within [timeout]; then the change may still have arrived.
  Future<void> changeStatus(
    String id,
    BookingStatus status, {
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    final document = _firestore.collection('bookings').doc(id);
    final _Refusal? refusal;
    try {
      refusal = await _firestore
          .runTransaction<_Refusal?>(
            (transaction) async {
              final snapshot = await transaction.get(document);
              final stored = _readStored(snapshot.data());
              if (stored.refusal != null) return stored.refusal;
              // A status change sends none of the customer's values or
              // places, so one of them stored in a form the rules refuse
              // would end in a bare "permission denied". Name it instead.
              final unclean = storedFormatErrorsOfDocument(id, stored.data!);
              if (unclean.isNotEmpty) {
                return _Refusal(AdminBookingSaveFailure.storedFormat, [
                  for (final error in AdminBookingError.values)
                    if (unclean.contains(error)) error.name,
                ]);
              }
              transaction.update(document, {'status': status.storedName});
              return null;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          // The plugin's own timeout does not cover every platform and
          // every stage of the transaction, so the wait is limited here too.
          .timeout(timeout);
    } on TimeoutException {
      throw const AdminStatusChangeNoAnswer();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapStatusChangeError(error), stackTrace);
    }
    if (refusal != null) {
      throw AdminStatusChangeException(
        _statusFailure(refusal.failure),
        fields: refusal.fields,
      );
    }
  }

  /// Saves an edit of the booking [id] and returns once the server has
  /// confirmed it.
  ///
  /// Only the changed top-level fields are written ([changes]); status,
  /// createdAt and createdBy are never among them, so createdAt stays as
  /// stored, which the rules require.
  ///
  /// It runs in a transaction, tried once, like [changeStatus]: nothing is
  /// kept in the offline queue. Before it writes, the transaction
  /// - reads the booking: a deleted one is noticed;
  /// - checks the stored document for what the rules refuse on every
  ///   update (unknown fields, no createdAt);
  /// - compares every edited part with the value the edit started from
  ///   ([base]): when it was changed elsewhere meanwhile, nothing is
  ///   written;
  /// - reads the car the booking will have: it must exist (it may be
  ///   hidden), as the rules require.
  ///
  /// Throws an [AdminBookingSaveException] when the edit was certainly not
  /// saved, and an [AdminBookingSaveNoAnswer] when the server did not
  /// answer within [timeout]; then the change may still have arrived.
  Future<void> updateBooking(
    String id, {
    required Booking base,
    required AdminBookingChanges changes,
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    if (changes.isEmpty) {
      throw ArgumentError.value(changes, 'changes', 'nothing changed');
    }
    final document = _firestore.collection('bookings').doc(id);
    final update = bookingUpdateToFirestore(changes.values);
    final _Refusal? refusal;
    try {
      refusal = await _firestore
          .runTransaction<_Refusal?>(
            (transaction) async {
              final snapshot = await transaction.get(document);
              final stored = _readStored(snapshot.data());
              if (stored.refusal != null) return stored.refusal;
              final current = stored.data!;

              final conflicts = conflictingFields(
                base: base,
                current: current,
                edited: changes.fields,
              );
              if (conflicts.isNotEmpty) {
                return _Refusal(AdminBookingSaveFailure.conflict, [
                  for (final field in conflicts) field.storedKey,
                ]);
              }

              // The car the booking has after the write. The rules allow
              // the same characters in its ID as in a booking ID.
              final carId = changes.values['carId'] ?? current['carId'];
              if (carId is! String || !isPlausibleBookingId(carId)) {
                return const _Refusal(AdminBookingSaveFailure.carMissing);
              }
              final car = await transaction.get(
                _firestore.collection('cars').doc(carId),
              );
              if (!car.exists) {
                return const _Refusal(AdminBookingSaveFailure.carMissing);
              }

              transaction.update(document, update);
              return null;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AdminBookingSaveNoAnswer();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapBookingSaveError(error), stackTrace);
    }
    if (refusal != null) {
      throw AdminBookingSaveException(refusal.failure, fields: refusal.fields);
    }
  }

  /// A new, unused ID for a booking. Firestore makes it on the device; no
  /// request is sent. The "new booking" form asks for one when it opens and
  /// uses it for every attempt to save, so that a repeated attempt can
  /// never create a second booking.
  String newBookingId() => _firestore.collection('bookings').doc().id;

  /// Creates [booking] as the document [id] and returns once the server
  /// has confirmed it.
  ///
  /// It runs in a transaction, tried once, like [changeStatus]: nothing is
  /// kept in the offline queue. The transaction
  /// - reads the document [id] first. When it exists, nothing is written
  ///   and [AdminBookingCreateResult.alreadyCreated] is returned: an
  ///   earlier attempt with this ID, whose answer never arrived, did
  ///   create it. So a booking is never created twice;
  /// - reads the car: it must exist (it may be hidden), as the rules
  ///   require;
  /// - creates the document, with createdAt set by the server.
  ///
  /// Throws an [AdminBookingCreateException] when the booking was
  /// certainly not created, and an [AdminBookingCreateNoAnswer] when the
  /// server did not answer within [timeout]; then the booking may exist,
  /// and calling this again with the same [id] tells.
  Future<AdminBookingCreateResult> createBooking(
    String id,
    Booking booking, {
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    if (!isPlausibleBookingId(id) || id == adminNewBookingPathSegment) {
      throw ArgumentError.value(id, 'id', 'cannot be the ID of a booking');
    }
    final data = adminNewBookingDocument(booking);
    final document = _firestore.collection('bookings').doc(id);
    final _CreateOutcome outcome;
    try {
      outcome = await _firestore
          .runTransaction<_CreateOutcome>(
            (transaction) async {
              final existing = await transaction.get(document);
              if (existing.exists) return _CreateOutcome.alreadyCreated;

              // The rules allow the same characters in the ID of a car as
              // in a booking ID.
              final carId = booking.carId;
              if (!isPlausibleBookingId(carId)) {
                return _CreateOutcome.carMissing;
              }
              final car = await transaction.get(
                _firestore.collection('cars').doc(carId),
              );
              if (!car.exists) return _CreateOutcome.carMissing;

              transaction.set(document, data);
              return _CreateOutcome.created;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AdminBookingCreateNoAnswer();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapBookingCreateError(error), stackTrace);
    }
    switch (outcome) {
      case _CreateOutcome.created:
        return AdminBookingCreateResult.created;
      case _CreateOutcome.alreadyCreated:
        return AdminBookingCreateResult.alreadyCreated;
      case _CreateOutcome.carMissing:
        throw const AdminBookingCreateException(
          AdminBookingCreateFailure.carMissing,
        );
    }
  }

  /// Deletes the booking [id] and returns once the server has confirmed
  /// it. A delete cannot be undone.
  ///
  /// It runs in a transaction, tried once, like [changeStatus]: nothing is
  /// kept in the offline queue. The transaction reads the booking first:
  /// - there is none: nothing is written and
  ///   [AdminBookingDeleteResult.alreadyDeleted] is returned;
  /// - its status is no longer [shownStatus], the one the admin saw when
  ///   they confirmed (somebody changed it meanwhile): nothing is deleted;
  /// - otherwise the document is deleted.
  ///
  /// The rules let an admin delete any booking; unlike an update, the
  /// stored document is not checked, so a hand-made document with a field
  /// the app does not know can be deleted too.
  ///
  /// Throws an [AdminBookingDeleteException] when the booking was
  /// certainly not deleted, and an [AdminBookingDeleteNoAnswer] when the
  /// server did not answer within [timeout]; then it may be gone.
  Future<AdminBookingDeleteResult> deleteBooking(
    String id, {
    required BookingStatus shownStatus,
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    final document = _firestore.collection('bookings').doc(id);
    final _DeleteOutcome outcome;
    try {
      outcome = await _firestore
          .runTransaction<_DeleteOutcome>(
            (transaction) async {
              final snapshot = await transaction.get(document);
              final data = snapshot.data();
              if (data == null) return _DeleteOutcome.alreadyDeleted;
              if (statusChangedElsewhere(
                shown: shownStatus,
                storedStatus: data['status'],
              )) {
                return _DeleteOutcome.statusChanged;
              }
              transaction.delete(document);
              return _DeleteOutcome.deleted;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AdminBookingDeleteNoAnswer();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapBookingDeleteError(error), stackTrace);
    }
    switch (outcome) {
      case _DeleteOutcome.deleted:
        return AdminBookingDeleteResult.deleted;
      case _DeleteOutcome.alreadyDeleted:
        return AdminBookingDeleteResult.alreadyDeleted;
      case _DeleteOutcome.statusChanged:
        throw const AdminBookingDeleteException(
          AdminBookingDeleteFailure.statusChanged,
        );
    }
  }
}

/// How the transaction of a delete ended.
enum _DeleteOutcome { deleted, alreadyDeleted, statusChanged }

/// How the transaction of a create ended.
enum _CreateOutcome { created, alreadyCreated, carMissing }

/// Why a transaction did not write, decided before the write.
class _Refusal {
  const _Refusal(this.failure, [this.fields = const []]);

  final AdminBookingSaveFailure failure;
  final List<String> fields;
}

/// The stored document with its dates as UTC DateTime values, or why it
/// cannot be written to: it is gone, or the rules would refuse any update
/// of it.
({Map<String, dynamic>? data, _Refusal? refusal}) _readStored(
  Map<String, dynamic>? raw,
) {
  if (raw == null) {
    return (
      data: null,
      refusal: const _Refusal(AdminBookingSaveFailure.bookingMissing),
    );
  }
  final data = bookingMapFromFirestore(raw);
  final problem = bookingDocumentProblem(data);
  if (problem == null) return (data: data, refusal: null);
  switch (problem.kind) {
    case AdminDocumentProblemKind.unknownFields:
      return (
        data: null,
        refusal: _Refusal(
          AdminBookingSaveFailure.unknownFields,
          problem.fields,
        ),
      );
    case AdminDocumentProblemKind.noCreatedAt:
      return (
        data: null,
        refusal: const _Refusal(AdminBookingSaveFailure.noCreatedAt),
      );
  }
}

AdminStatusChangeFailure _statusFailure(AdminBookingSaveFailure failure) {
  switch (failure) {
    case AdminBookingSaveFailure.bookingMissing:
      return AdminStatusChangeFailure.bookingMissing;
    case AdminBookingSaveFailure.unknownFields:
      return AdminStatusChangeFailure.unknownFields;
    case AdminBookingSaveFailure.noCreatedAt:
      return AdminStatusChangeFailure.noCreatedAt;
    case AdminBookingSaveFailure.storedFormat:
      return AdminStatusChangeFailure.storedFormat;
    case AdminBookingSaveFailure.noConnection:
      return AdminStatusChangeFailure.noConnection;
    case AdminBookingSaveFailure.refused:
      return AdminStatusChangeFailure.refused;
    case AdminBookingSaveFailure.carMissing:
    case AdminBookingSaveFailure.conflict:
    case AdminBookingSaveFailure.unknown:
      return AdminStatusChangeFailure.unknown;
  }
}

/// Turns an error of deleting a booking into an
/// [AdminBookingDeleteException] with its reason; the same mapping of
/// Firestore codes as for a status change. Screens never see a Firestore
/// error type.
AdminBookingDeleteException mapBookingDeleteError(Object error) {
  if (error is AdminBookingDeleteException) return error;
  if (error is FirebaseException) {
    return AdminBookingDeleteException(deleteFailureFromCode(error.code));
  }
  return const AdminBookingDeleteException(AdminBookingDeleteFailure.unknown);
}

/// Turns an error of creating a booking into an
/// [AdminBookingCreateException] with its reason; the same mapping of
/// Firestore codes as for a status change. Screens never see a Firestore
/// error type.
AdminBookingCreateException mapBookingCreateError(Object error) {
  if (error is AdminBookingCreateException) return error;
  if (error is FirebaseException) {
    return AdminBookingCreateException(createFailureFromCode(error.code));
  }
  return const AdminBookingCreateException(AdminBookingCreateFailure.unknown);
}

/// Turns an error of saving an edit into an [AdminBookingSaveException]
/// with its reason; the same mapping of Firestore codes as for a status
/// change. Screens never see a Firestore error type.
AdminBookingSaveException mapBookingSaveError(Object error) {
  if (error is AdminBookingSaveException) return error;
  if (error is FirebaseException) {
    return AdminBookingSaveException(saveFailureFromCode(error.code));
  }
  return const AdminBookingSaveException(AdminBookingSaveFailure.unknown);
}

/// Turns an error of the status change into an [AdminStatusChangeException]
/// with its reason: no connection ("unavailable", "deadline-exceeded"),
/// refused by the rules ("permission-denied"), the booking is gone
/// ("not-found"), or unknown. Screens never see a Firestore error type.
AdminStatusChangeException mapStatusChangeError(Object error) {
  if (error is AdminStatusChangeException) return error;
  if (error is FirebaseException) {
    return AdminStatusChangeException(statusChangeFailureFromCode(error.code));
  }
  return const AdminStatusChangeException(AdminStatusChangeFailure.unknown);
}

/// The kind of failure of a conflict or hide check.
ConflictCheckFailure conflictCheckFailureOf(Object error) {
  if (error is TimeoutException) return ConflictCheckFailure.timeout;
  if (error is FirebaseException) {
    switch (error.code.replaceFirst('firestore/', '')) {
      case 'unavailable':
        return ConflictCheckFailure.noConnection;
      case 'deadline-exceeded':
        return ConflictCheckFailure.timeout;
      case 'permission-denied':
        return ConflictCheckFailure.refused;
    }
  }
  return ConflictCheckFailure.other;
}

/// The type of [error], and for a FirebaseException only its code: what the
/// debug line may show. Never a message or a value.
String conflictCheckErrorKind(Object error) => error is FirebaseException
    ? 'FirebaseException(code: ${error.code})'
    : '${error.runtimeType}';

/// Refuses an answer that holds nothing and did not come from the server:
/// that is "no connection", not "nothing there".
void _requireServerAnswer({required bool isEmpty, required bool fromCache}) {
  final meaning = answerMeaning(isEmpty: isEmpty, fromCache: fromCache);
  if (meaning == AnswerMeaning.notKnownYet) {
    throw const AdminBookingsException(AdminBookingsFailure.noConnection);
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
