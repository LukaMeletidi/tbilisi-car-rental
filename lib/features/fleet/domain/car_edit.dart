/// Editing one car in the admin area: reading the live answer, the dirty
/// check, when Save can be pressed, the photo list of the form, and what
/// the screen says after a write. Pure Dart; nothing here talks to
/// Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// One answer of the live read of a single car, before it is read.
class RawCarAnswer {
  const RawCarAnswer({required this.document, required this.fromCache});

  /// The document, or null when there is none with that ID.
  final FleetRawDocument? document;

  /// True when this answer did not come from the server.
  final bool fromCache;
}

/// What an answer of the live read means.
enum CarReadState {
  /// The car was read.
  found,

  /// The server says there is no such car.
  missing,

  /// There is a document, but Car.fromMap cannot read it.
  unreadable,

  /// Nothing can be said yet: the saved copy has no such document and the
  /// server has not answered. This is NOT "missing".
  notKnownYet,
}

/// The result of [readCarAnswer].
class CarRead {
  const CarRead(this.state, {this.car, this.data});

  final CarReadState state;

  /// Set only for [CarReadState.found].
  final Car? car;

  /// The stored fields; set only for [CarReadState.found]. Needed for
  /// "needs repair", which compares the raw document.
  final Map<String, dynamic>? data;
}

/// Reads one answer of the live read. A missing document counts as
/// "missing" only when the server said so.
CarRead readCarAnswer(RawCarAnswer answer) {
  final document = answer.document;
  if (document == null) {
    final meaning = answerMeaning(isEmpty: true, fromCache: answer.fromCache);
    return CarRead(
      meaning == AnswerMeaning.notKnownYet
          ? CarReadState.notKnownYet
          : CarReadState.missing,
    );
  }
  try {
    final car = Car.fromMap(document.id, document.data);
    return CarRead(CarReadState.found, car: car, data: document.data);
  } on FormatException {
    return const CarRead(CarReadState.unreadable);
  }
}

/// Whether the form [draft] differs from the car it started from.
bool carDraftChanged(Car base, CarDraft draft) =>
    draft != CarDraft.fromCar(base);

/// Whether the Save button can be pressed.
///
/// The form must be shown, no save may run, the fields must not be locked
/// after "No answer", and the form must have a change OR the stored car
/// must need repair: a car whose only problem cannot be seen in the form
/// (a year stored as 2019.0, an unknown field, no photos field) has no
/// change to make, and is repaired by a save as it is. Errors of the
/// fields do not disable Save: pressing it shows them.
bool carEditCanSave({
  required bool editing,
  required bool saving,
  required bool locked,
  required bool dirty,
  required bool needsRepair,
}) => editing && !saving && !locked && (dirty || needsRepair);

/// The photo list with one more, empty row at the end; unchanged at
/// carMaxPhotos rows.
List<String> addPhotoRow(List<String> photos) =>
    photos.length >= carMaxPhotos ? photos : List.unmodifiable([...photos, '']);

/// The photo list without the row [index].
List<String> removePhotoAt(List<String> photos, int index) =>
    List.unmodifiable([...photos]..removeAt(index));

/// The photo list with the row [index] set to [address].
List<String> setPhotoAt(List<String> photos, int index, String address) =>
    List.unmodifiable([...photos]..[index] = address);

/// The photo list with the row [index] moved one place up (towards the
/// first photo) or down. Unchanged at the ends.
List<String> movePhoto(List<String> photos, int index, {required bool up}) {
  final other = up ? index - 1 : index + 1;
  if (other < 0 || other >= photos.length) return photos;
  final moved = [...photos];
  moved[index] = photos[other];
  moved[other] = photos[index];
  return List.unmodifiable(moved);
}

/// What the edit form tells the admin after an attempt to save.
enum CarSaveNotice {
  /// The server confirmed it (or it was already stored exactly so).
  saved,

  /// No answer in time: the car may or may not be saved.
  noAnswer,

  noConnection,
  refused,
  carMissing,
  changedElsewhere,
  unknown,
}

/// The notice for a write that certainly did not happen.
CarSaveNotice noticeForCarWriteFailure(CarWriteFailure failure) {
  switch (failure) {
    case CarWriteFailure.noConnection:
      return CarSaveNotice.noConnection;
    case CarWriteFailure.refused:
      return CarSaveNotice.refused;
    case CarWriteFailure.carMissing:
      return CarSaveNotice.carMissing;
    case CarWriteFailure.changedElsewhere:
      return CarSaveNotice.changedElsewhere;
    case CarWriteFailure.unknown:
      return CarSaveNotice.unknown;
  }
}

/// What the list tells the admin after hiding or showing a car.
enum CarActiveNotice {
  hidden,
  shown,

  /// No answer in time: the change may or may not have arrived. The live
  /// list shows the real state when the server answers.
  noAnswer,

  noConnection,
  refused,
  carMissing,
  unknown,
}

/// The notice for a hide or show that certainly did not happen.
CarActiveNotice activeNoticeForFailure(CarWriteFailure failure) {
  switch (failure) {
    case CarWriteFailure.noConnection:
      return CarActiveNotice.noConnection;
    case CarWriteFailure.refused:
      return CarActiveNotice.refused;
    case CarWriteFailure.carMissing:
      return CarActiveNotice.carMissing;
    case CarWriteFailure.changedElsewhere:
    case CarWriteFailure.unknown:
      return CarActiveNotice.unknown;
  }
}
