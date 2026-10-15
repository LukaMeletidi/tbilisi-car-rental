/// Adding a car in the admin area: when the form has something to lose,
/// when Save can be pressed, and what the screen says after a create. Pure
/// Dart; nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// The fields of a new form: everything empty, the car hidden.
const newCarDraft = CarDraft();

/// What the "new car" form tells the admin after an attempt to save.
enum CarCreateNotice {
  /// The server confirmed it: created now, or found already created by an
  /// earlier attempt with the same ID.
  saved,

  /// No answer in time: the car may or may not exist.
  noAnswer,

  /// Certainly not created: the server could not be reached.
  noConnection,

  /// Certainly not created: the rules refused.
  refused,

  /// An error the app does not know. The create may have reached the
  /// server, so it is handled like [noAnswer].
  unknown,
}

/// The notice for a create the server confirmed. Both results mean that
/// the car with this ID exists; with the fields locked after an uncertain
/// attempt, it is the car this form sent.
CarCreateNotice createNoticeOf(CarCreateResult result) => CarCreateNotice.saved;

/// The notice for a create that failed. "carMissing" and
/// "changedElsewhere" cannot come from a create; they count as unknown.
CarCreateNotice createNoticeForFailure(CarWriteFailure failure) {
  switch (failure) {
    case CarWriteFailure.noConnection:
      return CarCreateNotice.noConnection;
    case CarWriteFailure.refused:
      return CarCreateNotice.refused;
    case CarWriteFailure.carMissing:
    case CarWriteFailure.changedElsewhere:
    case CarWriteFailure.unknown:
      return CarCreateNotice.unknown;
  }
}

/// Whether after [notice] the car may already exist: "No answer" and an
/// unknown error. The form then keeps the attempted car, locks its fields
/// and offers only "Check again", which sends the same car with the same
/// ID. Only noConnection and refused are certain that nothing was created.
bool createMayHaveArrived(CarCreateNotice notice) =>
    notice == CarCreateNotice.noAnswer || notice == CarCreateNotice.unknown;

/// Whether leaving the form would lose something: a typed field, or a
/// save whose fate is unknown ([mayAlreadyExist]).
bool newCarHasSomethingToLose(
  CarDraft draft, {
  required bool mayAlreadyExist,
  required bool created,
}) => !created && (mayAlreadyExist || draft != newCarDraft);

/// Whether Save can be pressed: not while a save runs, and not after an
/// uncertain attempt (then only "Check again"). An empty or wrong form may
/// be saved: pressing Save shows every error.
bool newCarCanSave({required bool saving, required bool mayAlreadyExist}) =>
    !saving && !mayAlreadyExist;
