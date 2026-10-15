import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

const carId = 'car-1';

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

  AdminCarEditState get state => container.read(adminCarEditProvider(carId));

  AdminCarEditNotifier get notifier =>
      container.read(adminCarEditProvider(carId).notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> elapse(Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
  }

  Future<void> emit(
    Map<String, dynamic>? data, {
    bool fromCache = false,
  }) async {
    fleet.emitCar(carId, data, fromCache: fromCache);
    await flush();
  }

  void edit(CarDraft Function(CarDraft draft) change) =>
      notifier.setDraft(change(state.draft!));
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
  final subscription = container.listen(adminCarEditProvider(carId), (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

/// A started harness with the complete car [data] in the form.
Future<Harness> editing(
  WidgetTester tester, {
  Map<String, dynamic>? data,
}) async {
  final h = await start(tester);
  await h.emit(data ?? rawCar());
  expect(h.state.status, AdminCarEditStatus.editing);
  return h;
}

void main() {
  group('loading', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, no read', (
        tester,
      ) async {
        final h = await start(tester, session: session);
        expect(h.state.status, AdminCarEditStatus.inactive);
        expect(h.fleet.carReads, isEmpty);
      });
    }

    testWidgets('admin: loading, then the form of the stored car', (
      tester,
    ) async {
      final h = await start(tester);
      expect(h.state.status, AdminCarEditStatus.loading);
      expect(h.fleet.carReads, [carId]);

      await h.emit(rawCar());
      expect(h.state.status, AdminCarEditStatus.editing);
      expect(h.state.draft!.brand, 'Honda');
      expect(h.state.needsRepair, false);
      expect(h.state.showErrors, false);
      expect(h.state.isDirty, false);
      expect(h.state.canSave, false);
    });

    testWidgets('not from the server: loading; after 3 s "no connection" '
        'with the read open; the form appears by itself later', (tester) async {
      final h = await start(tester);
      await h.emit(null, fromCache: true);
      expect(h.state.status, AdminCarEditStatus.loading);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCarEditStatus.failed);
      expect(h.state.failure, FleetLoadFailure.noConnection);
      expect(h.fleet.activeCarListeners, 1);

      await h.emit(rawCar());
      expect(h.state.status, AdminCarEditStatus.editing);
    });

    testWidgets('missing, said by the server', (tester) async {
      final h = await start(tester);
      await h.emit(null);
      expect(h.state.status, AdminCarEditStatus.missing);
    });

    testWidgets('unreadable', (tester) async {
      final h = await start(tester);
      await h.emit({'brand': 5});
      expect(h.state.status, AdminCarEditStatus.unreadable);
    });

    testWidgets('refused: a failure; Try again reads anew', (tester) async {
      final h = await start(tester);
      h.fleet.failCar(
        const FleetLoadException(FleetLoadFailure.permissionDenied),
      );
      await h.flush();
      expect(h.state.status, AdminCarEditStatus.failed);
      expect(h.state.failure, FleetLoadFailure.permissionDenied);
      expect(h.fleet.activeCarListeners, 0);

      h.notifier.retry();
      await h.flush();
      expect(h.fleet.carReads, hasLength(2));
      await h.emit(rawCar());
      expect(h.state.status, AdminCarEditStatus.editing);
    });

    testWidgets('a sign-out closes the read', (tester) async {
      final h = await editing(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminCarEditStatus.inactive);
      expect(h.fleet.activeCarListeners, 0);
    });
  });

  group('a car that needs repair', () {
    testWidgets('no description: the errors show at once, and Save can be '
        'pressed', (tester) async {
      final h = await editing(
        tester,
        data: rawCar(change: (d) => d.remove('description')),
      );
      expect(h.state.needsRepair, true);
      expect(h.state.showErrors, true);
      expect(
        h.state.validation.errors,
        contains(CarError.descriptionKaRequired),
      );
      expect(h.state.draft!.descriptionKa, '');
      expect(h.state.canSave, true);
    });

    testWidgets('a problem the form cannot show (year 2019.0): Save without '
        'a change writes the repaired car', (tester) async {
      final h = await editing(
        tester,
        data: rawCar(change: (d) => d['year'] = 2019.0),
      );
      expect(h.state.isDirty, false);
      expect(h.state.canSave, true);
      await h.notifier.save();
      final written = h.fleet.replaced.single.car;
      expect(carDocument(written)['year'], isA<int>());
      expect(h.state.notice, CarSaveNotice.saved);
    });
  });

  group('the fields', () {
    testWidgets('a change makes the form dirty; errors wait for Save', (
      tester,
    ) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(brand: ''));
      expect(h.state.isDirty, true);
      expect(h.state.canSave, true);
      expect(h.state.validation.errors, contains(CarError.brandRequired));
      expect(h.state.showErrors, false);
    });

    testWidgets('changing it back: not dirty any more', (tester) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(seats: '4'));
      h.edit((d) => d.copyWith(seats: '5'));
      expect(h.state.isDirty, false);
      expect(h.state.canSave, false);
    });
  });

  group('save', () {
    testWidgets('with errors: they show, nothing is sent', (tester) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(brand: ''));
      await h.notifier.save();
      expect(h.state.showErrors, true);
      expect(h.fleet.replaced, isEmpty);
    });

    testWidgets('without a change on a complete car: nothing is sent', (
      tester,
    ) async {
      final h = await editing(tester);
      await h.notifier.save();
      expect(h.fleet.replaced, isEmpty);
    });

    testWidgets('writes the whole car, trimmed, with whole numbers, against '
        'its base; then "saved"', (tester) async {
      final h = await editing(tester);
      final base = h.state.base!;
      h.edit((d) => d.copyWith(model: ' Accord ', seats: '4'));
      await h.notifier.save();

      final call = h.fleet.replaced.single;
      expect(call.base, base);
      expect(call.car.model, 'Accord');
      expect(call.car.seats, 4);
      expect(carDocument(call.car)['seats'], isA<int>());
      expect(carDocument(call.car)['year'], isA<int>());
      expect(h.state.notice, CarSaveNotice.saved);
      expect(h.state.saving, false);
    });

    testWidgets('while it runs: locked, and a second press does nothing', (
      tester,
    ) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(seats: '4'));
      h.fleet.writeGate = Completer<void>();
      final first = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.canSave, false);
      await h.notifier.save();
      h.edit((d) => d.copyWith(seats: '3'));
      expect(h.state.draft!.seats, '4');

      h.fleet.writeGate!.complete();
      await first;
      expect(h.fleet.replaced, hasLength(1));
    });

    for (final (failure, notice) in [
      (CarWriteFailure.noConnection, CarSaveNotice.noConnection),
      (CarWriteFailure.refused, CarSaveNotice.refused),
      (CarWriteFailure.carMissing, CarSaveNotice.carMissing),
      (CarWriteFailure.unknown, CarSaveNotice.unknown),
    ]) {
      testWidgets('${failure.name}: its notice, and the fields stay', (
        tester,
      ) async {
        final h = await editing(tester);
        h.edit((d) => d.copyWith(seats: '4'));
        h.fleet.replaceError = CarWriteException(failure);
        await h.notifier.save();
        expect(h.state.notice, notice);
        expect(h.state.draft!.seats, '4');
        expect(h.state.locked, false);
        expect(h.state.canSave, true);
      });
    }
  });

  group('no answer', () {
    Future<Harness> noAnswer(WidgetTester tester) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(seats: '4'));
      h.fleet.replaceError = const CarWriteNoAnswer();
      await h.notifier.save();
      expect(h.state.notice, CarSaveNotice.noAnswer);
      return h;
    }

    testWidgets('locks the fields: no typing, no plain Save', (tester) async {
      final h = await noAnswer(tester);
      expect(h.state.locked, true);
      expect(h.state.canSave, false);
      h.edit((d) => d.copyWith(seats: '3'));
      expect(h.state.draft!.seats, '4');
      h.notifier.dismissNotice();
      expect(h.state.notice, CarSaveNotice.noAnswer);
    });

    testWidgets('"Save again" sends the same car; the repository finds it '
        'already saved and returns normally: saved', (tester) async {
      final h = await noAnswer(tester);
      h.fleet.replaceError = null;
      await h.notifier.save();
      expect(h.fleet.replaced, hasLength(2));
      expect(h.fleet.replaced[1].car, h.fleet.replaced[0].car);
      expect(h.fleet.replaced[1].base, h.fleet.replaced[0].base);
      expect(h.state.notice, CarSaveNotice.saved);
    });

    testWidgets('the server then shows the car as it was written: saved at '
        'once, without a second write', (tester) async {
      final h = await noAnswer(tester);
      final written = carDocument(h.fleet.replaced.single.car);
      await h.emit(written);
      expect(h.state.notice, CarSaveNotice.saved);
      expect(h.fleet.replaced, hasLength(1));
    });

    testWidgets('the same car from memory only, or another car: still no '
        'answer', (tester) async {
      final h = await noAnswer(tester);
      final written = carDocument(h.fleet.replaced.single.car);
      await h.emit(written, fromCache: true);
      expect(h.state.notice, CarSaveNotice.noAnswer);
      await h.emit(rawCar(change: (d) => d['seats'] = 3));
      expect(h.state.notice, CarSaveNotice.noAnswer);
    });

    testWidgets('"Load the current car" shows what is stored and unlocks', (
      tester,
    ) async {
      final h = await noAnswer(tester);
      await h.emit(rawCar(change: (d) => d['seats'] = 3));
      final version = h.state.formVersion;
      h.notifier.loadCurrent();
      expect(h.state.locked, false);
      expect(h.state.notice, isNull);
      expect(h.state.draft!.seats, '3');
      expect(h.state.isDirty, false);
      expect(h.state.formVersion, version + 1);
    });
  });

  group('changed elsewhere', () {
    testWidgets('while the form has no change, it follows the stored car', (
      tester,
    ) async {
      final h = await editing(tester);
      final version = h.state.formVersion;
      await h.emit(rawCar(change: (d) => d['seats'] = 3));
      expect(h.state.draft!.seats, '3');
      expect(h.state.base!.seats, 3);
      expect(h.state.changedElsewhere, false);
      expect(h.state.formVersion, version + 1);
    });

    testWidgets('the same car again: the fields are not rebuilt', (
      tester,
    ) async {
      final h = await editing(tester);
      final version = h.state.formVersion;
      await h.emit(rawCar());
      expect(h.state.formVersion, version);
    });

    testWidgets('with changes, the form keeps them and warns', (tester) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(model: 'Accord'));
      await h.emit(rawCar(change: (d) => d['seats'] = 3));
      expect(h.state.draft!.model, 'Accord');
      expect(h.state.draft!.seats, '5');
      expect(h.state.changedElsewhere, true);
    });

    testWidgets('a refused save, then "Load the current car"', (tester) async {
      final h = await editing(tester);
      h.edit((d) => d.copyWith(model: 'Accord'));
      await h.emit(rawCar(change: (d) => d['seats'] = 3));
      h.fleet.replaceError = const CarWriteException(
        CarWriteFailure.changedElsewhere,
      );
      await h.notifier.save();
      expect(h.state.notice, CarSaveNotice.changedElsewhere);
      expect(h.state.draft!.model, 'Accord');

      h.notifier.loadCurrent();
      expect(h.state.notice, isNull);
      expect(h.state.draft!.model, 'Civic');
      expect(h.state.draft!.seats, '3');
      expect(h.state.changedElsewhere, false);
    });
  });

  group('hiding through the form', () {
    testWidgets('asks first only when a visible car is hidden and the save '
        'could go ahead', (tester) async {
      final h = await editing(tester);
      expect(h.state.asksHideConfirmation, false);
      h.edit((d) => d.copyWith(active: false));
      expect(h.state.asksHideConfirmation, true);
      h.edit((d) => d.copyWith(brand: ''));
      expect(h.state.asksHideConfirmation, false);
    });

    testWidgets('a hidden car shown: no question', (tester) async {
      final h = await editing(tester, data: rawCar(active: false));
      h.edit((d) => d.copyWith(active: true));
      expect(h.state.asksHideConfirmation, false);
    });
  });

  testWidgets('an ID of another shape: missing, nothing is read', (
    tester,
  ) async {
    final h = await start(tester);
    final subscription = h.container.listen(
      adminCarEditProvider('a/b'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(subscription.read().status, AdminCarEditStatus.missing);
    expect(h.fleet.carReads, [carId]);
  });

  test('the starting car of the form is the stored car', () {
    final car = Car.fromMap(carId, rawCar());
    expect(CarDraft.fromCar(car).brand, 'Honda');
  });
}
