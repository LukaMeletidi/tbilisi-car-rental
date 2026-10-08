import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';

/// Read-only access to the "settings" collection. A missing or invalid
/// document makes the stream report a [FormatException]; it never falls back
/// to default values.
class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Live per-day prices of the extras, from settings/extras.
  Stream<ExtrasPrices> watchExtrasPrices() {
    return _firestore
        .collection('settings')
        .doc('extras')
        .snapshots()
        .map((snapshot) => ExtrasPrices.fromMap(snapshot.data()));
  }

  /// Live list of the fixed pickup and drop-off places, from
  /// settings/locations, in the order of the document.
  Stream<List<PickupLocation>> watchPickupLocations() {
    return _firestore
        .collection('settings')
        .doc('locations')
        .snapshots()
        .map((snapshot) => parsePickupLocations(snapshot.data()));
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(FirebaseFirestore.instance),
);
