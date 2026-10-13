import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';

/// Read-only access to the "settings" collection. A document that is
/// invalid, or that the SERVER says does not exist, makes the stream report
/// a [FormatException]; it never falls back to default values.
///
/// A document that is missing only because the server has not answered yet
/// is something else: it is waited out, and after [serverAnswerWait] the
/// stream reports a [NoServerAnswerException]. Metadata changes are
/// included, so that the answer of the server always arrives.
class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Live per-day prices of the extras, from settings/extras.
  Stream<ExtrasPrices> watchExtrasPrices() {
    return extrasPricesFrom(_answers('extras'));
  }

  /// Live list of the fixed pickup and drop-off places, from
  /// settings/locations, in the order of the document.
  Stream<List<PickupLocation>> watchPickupLocations() {
    return pickupLocationsFrom(_answers('locations'));
  }

  Stream<DocumentAnswer> _answers(String document) {
    return _firestore
        .collection('settings')
        .doc(document)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) =>
              (data: snapshot.data(), fromCache: snapshot.metadata.isFromCache),
        );
  }
}

/// The prices of the extras for each answer of the live read of
/// settings/extras; see [SettingsRepository] for what a missing document
/// means.
Stream<ExtrasPrices> extrasPricesFrom(
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) => ExtrasPrices.fromMap(answer.data),
    wait: wait,
  );
}

/// The fixed places for each answer of the live read of
/// settings/locations; see [SettingsRepository] for what a missing
/// document means.
Stream<List<PickupLocation>> pickupLocationsFrom(
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) => parsePickupLocations(answer.data),
    wait: wait,
  );
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(FirebaseFirestore.instance),
);
