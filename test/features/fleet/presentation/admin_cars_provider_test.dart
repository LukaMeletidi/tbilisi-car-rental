import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// These tests build no widgets. They use testWidgets only for its clock:
/// time passes when the test says so, and a timer that is still running at
/// the end fails the test.
class Harness {
  Harness(this.tester, this.container, this.fleet, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeFleetRepository fleet;
  final FakeAdminAuthRepository auth;

  DateTime now = DateTime.utc(2026, 10, 14, 12);

  AdminCarsState get state => container.read(adminCarsProvider);

  AdminCarsNotifier get notifier => container.read(adminCarsProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> elapse(Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
  }

  Future<void> emit(
    List<FleetRawDocument> documents, {
    bool fromCache = false,
  }) async {
    fleet.emit(documents, fromCache: fromCache);
    await flush();
  }
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final fleet = FakeFleetRepository();
  late final Harness harness;
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      fleetRepositoryProvider.overrideWithValue(fleet),
      clockProvider.overrideWithValue(() => harness.now),
    ],
  );
  harness = Harness(tester, container, fleet, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await harness.flush();
  final subscription = container.listen(adminCarsProvider, (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, no query', (
        tester,
      ) async {
        final h = await start(tester, session: session);
        expect(h.state.status, AdminCarsStatus.inactive);
        expect(h.fleet.queries, 0);
      });
    }

    testWidgets('admin: loading, then the list', (tester) async {
      final h = await start(tester);
      expect(h.state.status, AdminCarsStatus.loading);
      expect(h.fleet.activeListeners, 1);

      await h.emit([
        (id: 'a', data: rawCar(brand: 'Kia')),
        (id: 'b', data: rawCar(brand: 'Audi', active: false)),
      ]);
      expect(h.state.status, AdminCarsStatus.ready);
      expect(h.state.entries.map((e) => e.id), ['a', 'b']);
      expect(h.state.counts.visible, 1);
      expect(h.state.counts.hidden, 1);
    });

    testWidgets('a sign-out closes the listener', (tester) async {
      final h = await start(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminCarsStatus.inactive);
      expect(h.fleet.activeListeners, 0);
    });

    testWidgets('stop() closes the listener and forgets the list', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([(id: 'a', data: rawCar())]);
      h.notifier.stop();
      await h.flush();
      expect(h.state.status, AdminCarsStatus.inactive);
      expect(h.fleet.activeListeners, 0);
    });
  });

  group('an empty answer that is not from the server', () {
    testWidgets('is not "no cars": the list stays loading', (tester) async {
      final h = await start(tester);
      await h.emit(const [], fromCache: true);
      expect(h.state.status, AdminCarsStatus.loading);
      await h.elapse(const Duration(milliseconds: 2900));
      expect(h.state.status, AdminCarsStatus.loading);
      await h.elapse(const Duration(milliseconds: 100));
    });

    testWidgets('after 3 seconds: "no connection", and the listener stays '
        'open', (tester) async {
      final h = await start(tester);
      await h.emit(const [], fromCache: true);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCarsStatus.failed);
      expect(h.state.failure, FleetLoadFailure.noConnection);
      expect(h.fleet.activeListeners, 1);
    });

    testWidgets('the server answers later: the list appears by itself', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(const [], fromCache: true);
      await h.elapse(serverAnswerWait);
      await h.emit([(id: 'a', data: rawCar())]);
      expect(h.state.status, AdminCarsStatus.ready);
      expect(h.state.entries, hasLength(1));
      expect(h.fleet.queries, 1);
    });

    testWidgets('the server says there are no cars: ready and empty', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(const [], fromCache: true);
      await h.emit(const []);
      await h.elapse(const Duration(seconds: 10));
      expect(h.state.status, AdminCarsStatus.ready);
      expect(h.state.entries, isEmpty);
    });

    testWidgets('a shown list is never replaced by it', (tester) async {
      final h = await start(tester);
      await h.emit([(id: 'a', data: rawCar())]);
      await h.emit(const [], fromCache: true);
      await h.elapse(const Duration(seconds: 10));
      expect(h.state.status, AdminCarsStatus.ready);
      expect(h.state.entries, hasLength(1));
    });
  });

  group('the offline note', () {
    testWidgets('after 3 seconds of data from memory, and gone when the '
        'server answers', (tester) async {
      final h = await start(tester);
      await h.emit([(id: 'a', data: rawCar())], fromCache: true);
      expect(h.state.showOfflineNote, false);
      await h.elapse(serverAnswerWait);
      expect(h.state.showOfflineNote, true);
      await h.emit([(id: 'a', data: rawCar())]);
      expect(h.state.showOfflineNote, false);
    });
  });

  group('failures', () {
    testWidgets('refused: its own failure, and the listener is closed', (
      tester,
    ) async {
      final h = await start(tester);
      h.fleet.fail(const FleetLoadException(FleetLoadFailure.permissionDenied));
      await h.flush();
      expect(h.state.status, AdminCarsStatus.failed);
      expect(h.state.failure, FleetLoadFailure.permissionDenied);
      expect(h.fleet.activeListeners, 0);
    });

    testWidgets('any other error is "other"', (tester) async {
      final h = await start(tester);
      h.fleet.fail(StateError('broken'));
      await h.flush();
      expect(h.state.failure, FleetLoadFailure.other);
    });

    testWidgets('retry starts a new query and can succeed', (tester) async {
      final h = await start(tester);
      h.fleet.fail(StateError('broken'));
      await h.flush();
      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminCarsStatus.loading);
      expect(h.fleet.queries, 2);
      await h.emit([(id: 'a', data: rawCar())]);
      expect(h.state.status, AdminCarsStatus.ready);
    });
  });

  testWidgets('a car that needs repair and an unreadable document', (
    tester,
  ) async {
    final h = await start(tester);
    await h.emit([
      (id: 'a', data: rawCar(change: (d) => d.remove('description'))),
      (id: 'b', data: {'brand': 5}),
    ]);
    final car = h.state.entries.first as FleetCarEntry;
    expect(car.needsRepair, true);
    expect(h.state.entries.last, isA<FleetUnreadableEntry>());
    expect(h.state.counts.needRepair, 1);
    expect(h.state.counts.unreadable, 1);
  });
}
