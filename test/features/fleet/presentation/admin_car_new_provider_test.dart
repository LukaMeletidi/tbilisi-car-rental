import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// A complete, made-up car as the admin would type it: hidden.
final validDraft = CarDraft.fromCar(
  Car.fromMap('x', rawCar(active: false)),
).copyWith(model: ' Civic ');

class Harness {
  Harness(this.tester, this.container, this.fleet, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeFleetRepository fleet;
  final FakeAdminAuthRepository auth;

  AdminCarNewState get state => container.read(adminCarNewProvider);

  AdminCarNewNotifier get notifier =>
      container.read(adminCarNewProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final fleet = FakeFleetRepository();
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      fleetRepositoryProvider.overrideWithValue(fleet),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 14, 12)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await tester.pump(Duration.zero);
  final subscription = container.listen(adminCarNewProvider, (_, _) {});
  addTearDown(subscription.close);
  await tester.pump(Duration.zero);
  return Harness(tester, container, fleet, auth);
}

/// A started harness whose form holds [validDraft].
Future<Harness> filled(WidgetTester tester) async {
  final h = await start(tester);
  h.notifier.setDraft(validDraft);
  return h;
}

void main() {
  group('the form', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: no form and no ID', (
        tester,
      ) async {
        final h = await start(tester, session: session);
        expect(h.state.carId, isNull);
        expect(h.fleet.newIdCalls, 0);
        h.notifier.setDraft(validDraft);
        await h.notifier.save();
        expect(h.fleet.created, isEmpty);
      });
    }

    testWidgets('admin: one ID, an empty and hidden draft, no errors '
        'shown, Save enabled', (tester) async {
      final h = await start(tester);
      expect(h.state.carId, 'new-1');
      expect(h.fleet.newIdCalls, 1);
      expect(h.state.draft, newCarDraft);
      expect(h.state.draft.active, false);
      expect(h.state.showErrors, false);
      expect(h.state.canSave, true);
      expect(h.state.hasSomethingToLose, false);
    });

    testWidgets('typing: something to lose', (tester) async {
      final h = await start(tester);
      h.notifier.setDraft(newCarDraft.copyWith(brand: 'Kia'));
      expect(h.state.hasSomethingToLose, true);
    });

    testWidgets('Save on the empty form shows every error; nothing is '
        'sent', (tester) async {
      final h = await start(tester);
      await h.notifier.save();
      expect(h.state.showErrors, true);
      expect(h.state.validation.errors, contains(CarError.brandRequired));
      expect(
        h.state.validation.errors,
        contains(CarError.descriptionEnRequired),
      );
      expect(h.fleet.created, isEmpty);
    });

    testWidgets('a session that ends leaves no form', (tester) async {
      final h = await filled(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.carId, isNull);
      expect(h.state.draft, newCarDraft);
    });
  });

  group('save', () {
    testWidgets('creates the car with the form ID: trimmed, hidden, whole '
        'numbers', (tester) async {
      final h = await filled(tester);
      await h.notifier.save();
      final car = h.fleet.created.single;
      expect(car.id, 'new-1');
      expect(car.model, 'Civic');
      expect(car.active, false);
      expect(carDocument(car)['year'], isA<int>());
      expect(carDocument(car)['seats'], isA<int>());
      expect(h.state.created, true);
      expect(h.state.notice, CarCreateNotice.saved);
      expect(h.state.hasSomethingToLose, false);
    });

    testWidgets('already created by an earlier attempt: saved too', (
      tester,
    ) async {
      final h = await filled(tester);
      h.fleet.createResult = CarCreateResult.alreadyCreated;
      await h.notifier.save();
      expect(h.state.created, true);
    });

    testWidgets('while it runs: locked, and a second press does nothing', (
      tester,
    ) async {
      final h = await filled(tester);
      h.fleet.writeGate = Completer<void>();
      final first = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.canSave, false);
      await h.notifier.save();
      h.notifier.setDraft(validDraft.copyWith(brand: 'Kia'));
      expect(h.state.draft.brand, 'Honda');

      h.fleet.writeGate!.complete();
      await first;
      expect(h.fleet.created, hasLength(1));
    });

    for (final (failure, notice) in [
      (CarWriteFailure.noConnection, CarCreateNotice.noConnection),
      (CarWriteFailure.refused, CarCreateNotice.refused),
    ]) {
      testWidgets('${failure.name}: certainly not created; the fields stay '
          'editable and Save works again', (tester) async {
        final h = await filled(tester);
        h.fleet.createError = CarWriteException(failure);
        await h.notifier.save();
        expect(h.state.notice, notice);
        expect(h.state.mayAlreadyExist, false);
        expect(h.state.pending, isNull);
        expect(h.state.canSave, true);
        h.notifier.setDraft(validDraft.copyWith(seats: '4'));
        expect(h.state.draft.seats, '4');

        h.fleet.createError = null;
        await h.notifier.save();
        expect(h.fleet.created.map((car) => car.id), ['new-1', 'new-1']);
        expect(h.state.created, true);
      });
    }
  });

  group('an attempt whose fate is unknown', () {
    for (final (name, error, notice) in [
      ('no answer', const CarWriteNoAnswer(), CarCreateNotice.noAnswer),
      (
        'an unknown failure',
        const CarWriteException(CarWriteFailure.unknown),
        CarCreateNotice.unknown,
      ),
      ('an unexpected error', StateError('broken'), CarCreateNotice.unknown),
    ]) {
      testWidgets('$name: locked, the car kept; "Check again" sends the same '
          'ID and the same car', (tester) async {
        final h = await filled(tester);
        h.fleet.createError = error;
        await h.notifier.save();
        expect(h.state.notice, notice);
        expect(h.state.mayAlreadyExist, true);
        expect(h.state.pending, h.fleet.created.single);
        expect(h.state.canSave, false);
        expect(h.state.canCheckAgain, true);
        expect(h.state.hasSomethingToLose, true);

        h.notifier.setDraft(validDraft.copyWith(seats: '4'));
        expect(h.state.draft.seats, '5');
        await h.notifier.save();
        expect(h.fleet.created, hasLength(1));
        h.notifier.dismissNotice();
        expect(h.state.notice, notice);

        h.fleet.createError = null;
        h.fleet.createResult = CarCreateResult.alreadyCreated;
        await h.notifier.checkAgain();
        expect(h.fleet.created, hasLength(2));
        expect(h.fleet.created[1], h.fleet.created[0]);
        expect(h.fleet.created[1].id, 'new-1');
        expect(h.state.created, true);
        expect(h.state.pending, isNull);
        expect(h.fleet.newIdCalls, 1);
      });
    }

    testWidgets('a retry without a connection keeps it uncertain: the first '
        'attempt may have arrived', (tester) async {
      final h = await filled(tester);
      h.fleet.createError = const CarWriteNoAnswer();
      await h.notifier.save();
      h.fleet.createError = const CarWriteException(
        CarWriteFailure.noConnection,
      );
      await h.notifier.checkAgain();
      expect(h.state.notice, CarCreateNotice.noConnection);
      expect(h.state.mayAlreadyExist, true);
      expect(h.state.canCheckAgain, true);
    });
  });
}
