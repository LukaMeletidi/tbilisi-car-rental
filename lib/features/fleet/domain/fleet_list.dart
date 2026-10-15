/// The fleet list of the admin area: how a stored car document becomes a
/// row, whether it needs repair, the order and the counts. Pure Dart.
library;

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// A car document reduced to plain Dart: its ID and its stored fields.
/// The same shape as the catalog's RawCarDocument (Dart records of the same
/// shape are the same type), declared here so that this domain does not
/// import the catalog's data layer.
typedef FleetRawDocument = ({String id, Map<String, dynamic> data});

/// One answer of the cars query of the admin, before it is read.
class RawCarsResult {
  const RawCarsResult({required this.documents, required this.fromCache});

  final List<FleetRawDocument> documents;

  /// True when this answer did not come from the server.
  final bool fromCache;
}

/// One row of the fleet list.
sealed class FleetEntry {
  const FleetEntry(this.id);

  /// The document ID of the car.
  final String id;
}

/// A car that could be read.
class FleetCarEntry extends FleetEntry {
  FleetCarEntry(this.car, {required this.needsRepair}) : super(car.id);

  final Car car;

  /// True when the stored document is not what the rules accept for an
  /// edit (see [carRepairReasons]). Shown as the badge "Needs repair".
  final bool needsRepair;
}

/// A document that Car.fromMap cannot read at all. Only its ID is kept;
/// nothing else of the document.
class FleetUnreadableEntry extends FleetEntry {
  const FleetUnreadableEntry(super.id);
}

/// Why a stored car needs repair before anything but hide or show can be
/// saved; empty when it does not. The reasons name fields and problems,
/// never a stored value:
/// - `error: CarError` and `photo n: CarPhotoError`: the form made
///   from the car has this error (for example a missing description);
/// - `unknown field: name`, `missing field: name` and `differs:
///   name`: the stored document is not exactly the document a save would
///   write (an unknown field, a year stored as a decimal, a text with a
///   space at an end).
///
/// The comparison is the one of the "already saved" check of a replace, so
/// the badge and a save agree. The reasons are for tests and the developer;
/// the screen shows only the badge.
List<String> carRepairReasons(
  Car car,
  Map<String, dynamic> stored, {
  required DateTime now,
}) {
  final draft = CarDraft.fromCar(car);
  final validation = validateCarDraft(draft, now: now);
  if (validation.hasErrors) {
    return List.unmodifiable([
      for (final error in validation.errors) 'error: ${error.name}',
      for (final entry in validation.photoErrors.entries)
        'photo ${entry.key}: ${entry.value.name}',
    ]);
  }
  final wanted = carDocument(carFromDraft(car.id, draft, now: now));
  return List.unmodifiable([
    for (final key in stored.keys)
      if (!wanted.containsKey(key)) 'unknown field: $key',
    for (final key in wanted.keys)
      if (!stored.containsKey(key))
        'missing field: $key'
      else if (!sameStoredValue(stored[key], wanted[key]))
        'differs: $key',
  ]);
}

/// Whether the stored car needs repair: [carRepairReasons] is not empty.
bool carNeedsRepair(
  Car car,
  Map<String, dynamic> stored, {
  required DateTime now,
}) => carRepairReasons(car, stored, now: now).isNotEmpty;

/// The row of one stored document.
FleetEntry fleetEntryOf(FleetRawDocument document, {required DateTime now}) {
  final Car car;
  try {
    car = Car.fromMap(document.id, document.data);
  } on FormatException {
    return FleetUnreadableEntry(document.id);
  }
  return FleetCarEntry(
    car,
    needsRepair: carNeedsRepair(car, document.data, now: now),
  );
}

/// The rows of all documents, sorted: visible cars first, then hidden ones;
/// within each, by brand, then model (both ignoring case), then year, then
/// ID; the unreadable documents last, by ID.
List<FleetEntry> fleetEntries(
  List<FleetRawDocument> documents, {
  required DateTime now,
}) {
  final entries = [
    for (final document in documents) fleetEntryOf(document, now: now),
  ];
  entries.sort(compareFleetEntries);
  return List.unmodifiable(entries);
}

int compareFleetEntries(FleetEntry a, FleetEntry b) {
  int group(FleetEntry entry) => switch (entry) {
    FleetCarEntry(:final car) => car.active ? 0 : 1,
    FleetUnreadableEntry() => 2,
  };
  final byGroup = group(a).compareTo(group(b));
  if (byGroup != 0) return byGroup;
  if (a is FleetCarEntry && b is FleetCarEntry) {
    for (final result in [
      a.car.brand.toLowerCase().compareTo(b.car.brand.toLowerCase()),
      a.car.model.toLowerCase().compareTo(b.car.model.toLowerCase()),
      a.car.year.compareTo(b.car.year),
    ]) {
      if (result != 0) return result;
    }
  }
  return a.id.compareTo(b.id);
}

/// The counts above the list.
class FleetCounts {
  const FleetCounts({
    required this.visible,
    required this.hidden,
    required this.needRepair,
    required this.unreadable,
  });

  final int visible;
  final int hidden;
  final int needRepair;
  final int unreadable;

  /// Every document: the readable cars and the unreadable ones.
  int get total => visible + hidden + unreadable;

  @override
  bool operator ==(Object other) =>
      other is FleetCounts &&
      other.visible == visible &&
      other.hidden == hidden &&
      other.needRepair == needRepair &&
      other.unreadable == unreadable;

  @override
  int get hashCode => Object.hash(visible, hidden, needRepair, unreadable);
}

FleetCounts fleetCounts(List<FleetEntry> entries) {
  var visible = 0;
  var hidden = 0;
  var needRepair = 0;
  var unreadable = 0;
  for (final entry in entries) {
    switch (entry) {
      case FleetCarEntry(:final car, :final needsRepair):
        if (car.active) {
          visible++;
        } else {
          hidden++;
        }
        if (needsRepair) needRepair++;
      case FleetUnreadableEntry():
        unreadable++;
    }
  }
  return FleetCounts(
    visible: visible,
    hidden: hidden,
    needRepair: needRepair,
    unreadable: unreadable,
  );
}

/// The document ID for the screen: the first 8 characters and "…" when it
/// is longer. Only for showing; never used to find the car.
String shortCarId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

/// Why the cars of the admin could not be loaded.
enum FleetLoadFailure {
  /// The rules refused: this account is not (or no longer) an admin.
  permissionDenied,

  /// The server gave no answer in time and the app has nothing of its own
  /// to show. The cars may well exist.
  noConnection,

  /// Anything else.
  other,
}

/// The failure for an error [code] of Firestore.
FleetLoadFailure fleetLoadFailureFromCode(String code) =>
    code == 'permission-denied'
    ? FleetLoadFailure.permissionDenied
    : FleetLoadFailure.other;

/// Reported when the cars could not be loaded. Only the reason; never a
/// Firestore type and never a value of a car.
class FleetLoadException implements Exception {
  const FleetLoadException(this.failure);

  final FleetLoadFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FleetLoadException && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'FleetLoadException(${failure.name})';
}
