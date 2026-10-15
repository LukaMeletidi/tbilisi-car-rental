import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

void main() {
  test('"permission denied" is its own failure', () {
    expect(
      mapFleetLoadError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      const FleetLoadException(FleetLoadFailure.permissionDenied),
    );
  });

  test('every other Firestore code is "other"', () {
    for (final code in ['unavailable', 'internal', 'aborted']) {
      expect(
        mapFleetLoadError(
          FirebaseException(plugin: 'cloud_firestore', code: code),
        ),
        const FleetLoadException(FleetLoadFailure.other),
        reason: code,
      );
    }
  });

  test('a fleet exception stays; anything else is "other"', () {
    const noConnection = FleetLoadException(FleetLoadFailure.noConnection);
    expect(mapFleetLoadError(noConnection), same(noConnection));
    expect(
      mapFleetLoadError(StateError('broken')),
      const FleetLoadException(FleetLoadFailure.other),
    );
  });
}
