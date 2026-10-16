import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The "new car" form (/admin/cars/new) stays as it was in step 5.4: it
/// reads no bookings and asks no hide question, hidden or visible.
void main() {
  for (final active in [false, true]) {
    testWidgets('a new car saved ${active ? 'visible' : 'hidden'}: no '
        'bookings read', (tester) async {
      final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
      final fleet = FakeFleetRepository();
      final bookings = FakeAdminBookingsRepository();
      final container = ProviderContainer(
        overrides: [
          adminAuthRepositoryProvider.overrideWithValue(auth),
          fleetRepositoryProvider.overrideWithValue(fleet),
          adminBookingsRepositoryProvider.overrideWithValue(bookings),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 16)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container.read(adminSessionProvider);
      await tester.pump(Duration.zero);
      final subscription = container.listen(adminCarNewProvider, (_, _) {});
      addTearDown(subscription.close);

      container
          .read(adminCarNewProvider.notifier)
          .setDraft(CarDraft.fromCar(Car.fromMap('x', rawCar(active: active))));
      await container.read(adminCarNewProvider.notifier).save();

      expect(fleet.created.single.active, active);
      expect(bookings.confirmedReads, isEmpty);
    });
  }
}
