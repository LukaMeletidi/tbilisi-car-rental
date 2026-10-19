/// Saving settings/extras and settings/company: the reasons for a failure,
/// and the pure decision of the save transaction. Nothing here talks to
/// Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';

/// How long the app waits for the server to confirm a settings save. The
/// same 20 seconds as for every admin write.
const settingsWriteTimeout = Duration(seconds: 20);

/// Why a settings save certainly did NOT happen.
enum SettingsWriteFailure {
  /// The server could not be reached.
  noConnection,

  /// The rules refused (not an admin any more, or a value they refuse).
  refused,

  /// The stored document is no longer what the form loaded: somebody
  /// changed it meanwhile. Nothing was written; the form must reload.
  changedElsewhere,

  /// Anything else, also the raw offline error of Chrome.
  unknown,
}

/// The failure for an error [code] of Firestore: the mapping of the car
/// writes without "not-found" (a set creates the document). A prefix
/// "firestore/" (web) is ignored.
SettingsWriteFailure settingsWriteFailureFromCode(String code) {
  switch (code.replaceFirst('firestore/', '')) {
    case 'unavailable':
    case 'deadline-exceeded':
      return SettingsWriteFailure.noConnection;
    case 'permission-denied':
      return SettingsWriteFailure.refused;
    default:
      return SettingsWriteFailure.unknown;
  }
}

/// Reported when a settings save certainly did not happen. It carries only
/// the reason, never a Firestore type and never a value.
class SettingsWriteException implements Exception {
  const SettingsWriteException(this.failure);

  final SettingsWriteFailure failure;

  @override
  bool operator ==(Object other) =>
      other is SettingsWriteException && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'SettingsWriteException(${failure.name})';
}

/// Reported when the server did not answer within [settingsWriteTimeout].
/// This does NOT mean "not saved": only a new read tells.
class SettingsWriteNoAnswer implements Exception {
  const SettingsWriteNoAnswer();

  @override
  String toString() => 'SettingsWriteNoAnswer';
}

/// What the save transaction does, decided from what it read.
enum SettingsSaveDecision {
  write,

  /// The stored document already is the value to save: a retry after a
  /// lost answer, or a save without a change. Nothing is written; the save
  /// counts as done.
  alreadySaved,

  /// The stored document is not what the form loaded. Nothing is written.
  changedElsewhere,
}

/// Decides a save. [storedExists] says whether the document exists;
/// [stored] is it read as a value (null when it does not exist or cannot
/// be read); [base] is what the form loaded (null: the form started from
/// "does not exist"); [target] is the value to save.
///
/// The values are compared with ==, so a stored 5 and a typed 5.0 are the
/// same price. The order matters: already exactly [target]; no document
/// (expected only when [base] is null); exists but unreadable; created
/// meanwhile; changed since [base]; otherwise write.
SettingsSaveDecision decideSettingsSave<T extends Object>({
  required bool storedExists,
  required T? stored,
  required T? base,
  required T target,
}) {
  if (stored != null && stored == target) {
    return SettingsSaveDecision.alreadySaved;
  }
  if (!storedExists) {
    return base == null
        ? SettingsSaveDecision.write
        : SettingsSaveDecision.changedElsewhere;
  }
  if (stored == null || base == null) {
    return SettingsSaveDecision.changedElsewhere;
  }
  return stored == base
      ? SettingsSaveDecision.write
      : SettingsSaveDecision.changedElsewhere;
}

/// The whole settings/extras document for [prices], exactly in the shape
/// of PLAN Section 3.5: { pricesPerDay: { the four extras } }.
Map<String, dynamic> extrasDocument(ExtrasPrices prices) => {
  'pricesPerDay': {
    for (final extra in Extra.values) extra.name: prices.priceOf(extra),
  },
};
