/// Writing a car: the results, the reasons for a failure, and the pure
/// decisions that the transactions of FleetRepository take from what they
/// read. Nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';

/// How long the app waits for the server to confirm a car write. The same
/// 20 seconds as for every admin write of bookings.
const carWriteTimeout = Duration(seconds: 20);

final _carId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Whether [id] can be the ID of a car: the same pattern as the create rule
/// in firestore.rules.
bool isPlausibleCarId(String id) => _carId.hasMatch(id);

/// What a create returns when the server confirmed it.
enum CarCreateResult {
  /// The car was created now.
  created,

  /// A car with this ID already existed: an earlier attempt, whose answer
  /// never arrived, created it. Nothing was written now.
  alreadyCreated,
}

/// Why a car write certainly did NOT happen.
enum CarWriteFailure {
  /// The server could not be reached.
  noConnection,

  /// The rules refused (not an admin any more, or a value they refuse).
  refused,

  /// The car does not exist (any more).
  carMissing,

  /// The stored car is no longer the one the form started from: somebody
  /// changed it meanwhile. Nothing was written; the form must reload.
  changedElsewhere,

  /// Anything else.
  unknown,
}

/// The failure for an error [code] of Firestore. The same mapping as the
/// admin bookings writes (statusChangeFailureFromCode): every other code,
/// "aborted" too, is unknown.
CarWriteFailure carWriteFailureFromCode(String code) {
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
      return CarWriteFailure.noConnection;
    case 'permission-denied':
      return CarWriteFailure.refused;
    case 'not-found':
      return CarWriteFailure.carMissing;
    default:
      return CarWriteFailure.unknown;
  }
}

/// Reported when a car write certainly did not happen. It carries only the
/// reason, never a Firestore type and never a value of the car.
class CarWriteException implements Exception {
  const CarWriteException(this.failure);

  final CarWriteFailure failure;

  @override
  bool operator ==(Object other) =>
      other is CarWriteException && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'CarWriteException(${failure.name})';
}

/// Reported when the server did not answer within [carWriteTimeout]. This
/// does NOT mean "not saved": the write may have arrived. Only a new read
/// of the car tells.
class CarWriteNoAnswer implements Exception {
  const CarWriteNoAnswer();

  @override
  String toString() => 'CarWriteNoAnswer';
}

/// What the replace transaction does, decided from what it read.
enum CarReplaceDecision {
  write,

  /// There is no such car (any more). Nothing is written.
  carMissing,

  /// The stored document is already exactly the car to be written: a
  /// retry after a lost answer, or a save without a change. Nothing is
  /// written; the save counts as done.
  alreadySaved,

  /// The stored car is not the one the form started from. Nothing is
  /// written.
  changedElsewhere,
}

/// Decides a replace. [storedData] is the stored document as read inside
/// the transaction (null when there is none); [base] is the car the form
/// started from; [target] is the car to be written.
///
/// The order matters: missing; already exactly [target]; changed since
/// [base]; otherwise write.
///
/// "Already exactly" compares the raw document with carDocument([target]):
/// the same keys, and the same values with whole numbers stored as whole
/// numbers. So a stored car with an unknown field, or with a year stored as
/// 2019.0, is NOT "already saved" and gets the write that repairs it, even
/// though it reads as the same Car.
CarReplaceDecision decideReplace({
  required Map<String, dynamic>? storedData,
  required Car base,
  required Car target,
}) {
  if (storedData == null) return CarReplaceDecision.carMissing;
  if (sameCarDocument(storedData, carDocument(target))) {
    return CarReplaceDecision.alreadySaved;
  }
  Car? stored;
  try {
    stored = Car.fromMap(target.id, storedData);
  } on FormatException {
    stored = null;
  }
  if (stored == null || stored != base) {
    return CarReplaceDecision.changedElsewhere;
  }
  return CarReplaceDecision.write;
}

/// Whether the stored fields [stored] are exactly [document]: the same keys,
/// and equal values. Where [document] has a whole number (int), the stored
/// value must be an int too; Dart's 2019.0 == 2019 is not enough here.
bool sameCarDocument(
  Map<String, dynamic> stored,
  Map<String, dynamic> document,
) {
  if (stored.length != document.length) return false;
  for (final entry in document.entries) {
    if (!stored.containsKey(entry.key)) return false;
    if (!_sameValue(stored[entry.key], entry.value)) return false;
  }
  return true;
}

bool _sameValue(Object? stored, Object? wanted) {
  if (wanted is int) return stored is int && stored == wanted;
  if (wanted is double) return stored is num && stored.toDouble() == wanted;
  if (wanted is List) {
    if (stored is! List || stored.length != wanted.length) return false;
    for (var i = 0; i < wanted.length; i++) {
      if (!_sameValue(stored[i], wanted[i])) return false;
    }
    return true;
  }
  if (wanted is Map) {
    if (stored is! Map || stored.length != wanted.length) return false;
    for (final key in wanted.keys) {
      if (!stored.containsKey(key)) return false;
      if (!_sameValue(stored[key], wanted[key])) return false;
    }
    return true;
  }
  return stored == wanted;
}

/// What the hide-or-show transaction does.
enum CarActiveDecision {
  write,

  /// There is no such car. Nothing is written.
  carMissing,

  /// The stored "active" is already a bool with the asked value. Nothing is
  /// written; the call counts as done.
  alreadySet,
}

/// Decides a hide or show from the RAW stored document, not from a parsed
/// Car, because it must work for every stored car. Only a stored "active"
/// that is a bool equal to [active] skips the write; a car without the
/// field, or with another type in it, gets the write.
CarActiveDecision decideSetActive({
  required Map<String, dynamic>? storedData,
  required bool active,
}) {
  if (storedData == null) return CarActiveDecision.carMissing;
  final stored = storedData['active'];
  if (stored is bool && stored == active) return CarActiveDecision.alreadySet;
  return CarActiveDecision.write;
}
