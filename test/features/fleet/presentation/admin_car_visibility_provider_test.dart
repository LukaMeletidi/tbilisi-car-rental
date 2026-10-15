import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_visibility_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

Future<
  ({
    ProviderSubscription<AdminCarVisibilityState> visibility,
    AdminCarVisibilityNotifier notifier,
    FakeFleetRepository fleet,
  })
>
start(WidgetTester tester, {AdminSession session = AdminSession.admin}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final fleet = FakeFleetRepository();
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      fleetRepositoryProvider.overrideWithValue(fleet),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await tester.pump(Duration.zero);
  final visibility = container.listen(adminCarVisibilityProvider, (_, _) {});
  addTearDown(visibility.close);
  return (
    visibility: visibility,
    notifier: container.read(adminCarVisibilityProvider.notifier),
    fleet: fleet,
  );
}

void main() {
  testWidgets('hide and show write "active" for that car only', (tester) async {
    final t = await start(tester);
    await t.notifier.setActive('a', active: false);
    expect(t.visibility.read().notice, CarActiveNotice.hidden);
    await t.notifier.setActive('b', active: true);
    expect(t.visibility.read().notice, CarActiveNotice.shown);
    expect(t.fleet.activeChanges, [
      (id: 'a', active: false),
      (id: 'b', active: true),
    ]);
    expect(t.visibility.read().noticeCount, 2);
  });

  testWidgets('busy while it runs; a second press for the same car does '
      'nothing', (tester) async {
    final t = await start(tester);
    t.fleet.writeGate = Completer<void>();
    final first = t.notifier.setActive('a', active: false);
    await tester.pump(Duration.zero);
    expect(t.visibility.read().busy, {'a'});
    await t.notifier.setActive('a', active: false);
    expect(t.fleet.activeChanges, hasLength(1));

    t.fleet.writeGate!.complete();
    await first;
    expect(t.visibility.read().busy, isEmpty);
  });

  for (final (error, notice) in [
    (const CarWriteNoAnswer(), CarActiveNotice.noAnswer),
    (
      const CarWriteException(CarWriteFailure.noConnection),
      CarActiveNotice.noConnection,
    ),
    (const CarWriteException(CarWriteFailure.refused), CarActiveNotice.refused),
    (
      const CarWriteException(CarWriteFailure.carMissing),
      CarActiveNotice.carMissing,
    ),
    (StateError('broken'), CarActiveNotice.unknown),
  ]) {
    testWidgets('$error: ${notice.name}', (tester) async {
      final t = await start(tester);
      t.fleet.setActiveError = error;
      await t.notifier.setActive('a', active: true);
      expect(t.visibility.read().notice, notice);
      expect(t.visibility.read().busy, isEmpty);
    });
  }

  testWidgets('not an admin: nothing is sent', (tester) async {
    final t = await start(tester, session: AdminSession.noAccess);
    await t.notifier.setActive('a', active: false);
    expect(t.fleet.activeChanges, isEmpty);
  });
}
