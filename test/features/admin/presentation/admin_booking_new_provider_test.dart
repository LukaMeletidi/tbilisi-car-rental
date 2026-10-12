import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Office'),
  ),
];

ExtrasPrices prices() => ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 3,
    'boosterSeat': 2.5,
  },
});

/// These tests build no widgets. They use testWidgets only for its clock.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;

  AdminBookingNewState get state => container.read(adminBookingNewProvider);

  AdminBookingNewNotifier get notifier =>
      container.read(adminBookingNewProvider.notifier);

  /// Lets everything that is waiting run, without time passing.
  Future<void> flush() => tester.pump(Duration.zero);

  /// Changes the fields the form shares with the edit form.
  void edit(BookingFormInput Function(BookingFormInput input) change) {
    final draft = state.draft;
    notifier.setDraft(
      draft.copyWith(
        fields: draft.fields.copyWith(input: change(draft.fields.input)),
      ),
    );
  }

  /// Fills in a complete, valid form: 5 days with the car of 45 per day
  /// and one extra of 4 per day. Every value is made up.
  void fill({String carId = 'car-1'}) {
    edit(
      (i) => i.copyWith(
        fullName: ' Test Person ',
        phone: '+995 555 00-00-00',
        email: 'person@example.com',
        pickup: TbilisiDateTime(2026, 1, 10, 18, 0),
        dropoff: TbilisiDateTime(2026, 1, 15, 20, 0),
        pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
        dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
        extras: {Extra.childSeat},
      ),
    );
    final draft = state.draft;
    notifier.setDraft(
      draft.copyWith(fields: draft.fields.copyWith(carId: carId)),
    );
  }

  Future<void> save() async {
    await notifier.save();
    await flush();
  }

  Future<void> checkAgain() async {
    await notifier.checkAgain();
    await flush();
  }
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  List<Car>? cars,
  Object? carsError,
  bool withPrices = true,
  bool withPlaces = true,
  bool watch = true,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository()
    ..cars = cars ?? [testCar(), testCar(id: 'car-2', active: false)]
    ..carsError = carsError;
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      pickupLocationsProvider.overrideWith(
        (ref) => withPlaces
            ? Stream.value(places)
            : Stream.error(const FormatException('made up')),
      ),
      extrasPricesProvider.overrideWith(
        (ref) => withPrices
            ? Stream.value(prices())
            : Stream.error(const FormatException('made up')),
      ),
    ],
  );
  final harness = Harness(tester, container, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);

  container.read(adminSessionProvider);
  await harness.flush();
  if (watch) {
    final subscription = container.listen(adminBookingNewProvider, (_, _) {});
    addTearDown(subscription.close);
    await harness.flush();
    await harness.flush();
  }
  return harness;
}

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: no form, no ID, and '
          'nothing is asked for', (tester) async {
        final h = await start(tester, session: session);

        expect(h.state.status, AdminBookingNewStatus.inactive);
        expect(h.state.bookingId, isNull);
        expect(h.bookings.newIds, 0);
        expect(h.bookings.carReads, 0);

        await h.save();
        expect(h.bookings.creates, isEmpty);
      });
    }

    testWidgets('admin: the empty form, one ID, the cars read once, the '
        'places and prices from settings', (tester) async {
      final h = await start(tester);

      expect(h.state.status, AdminBookingNewStatus.editing);
      expect(h.state.bookingId, 'new-1');
      expect(h.bookings.newIds, 1);
      expect(h.bookings.carReads, 1);
      expect(h.state.cars!.map((car) => car.id), ['car-1', 'car-2']);
      expect(h.state.locations, places);
      expect(h.state.extrasPrices, prices());
      expect(h.state.draft.status, BookingStatus.confirmed);
      expect(h.state.isDirty, false);
      expect(h.state.canSave, false);
      expect(h.state.canEdit, true);
      expect(h.state.mayAlreadyExist, false);
      // No single booking and no list is listened to.
      expect(h.bookings.watchedBookingIds, isEmpty);
      expect(h.bookings.limits, isEmpty);
    });

    testWidgets('when the session ends the form is forgotten; a new '
        'sign-in gets an empty form with a new ID', (tester) async {
      final h = await start(tester);
      h.fill();

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminBookingNewStatus.inactive);
      expect(h.state.isDirty, false);
      expect(h.state.bookingId, isNull);

      h.auth.report(AdminSession.admin);
      await h.flush();
      await h.flush();
      expect(h.state.status, AdminBookingNewStatus.editing);
      expect(h.state.bookingId, 'new-2');
      expect(h.state.isDirty, false);
    });

    testWidgets('leaving the form forgets it: the next form has a new ID', (
      tester,
    ) async {
      final h = await start(tester, watch: false);
      final first = h.container.listen(adminBookingNewProvider, (_, _) {});
      await h.flush();
      expect(h.state.bookingId, 'new-1');

      first.close();
      await h.tester.pump(const Duration(seconds: 1));
      final second = h.container.listen(adminBookingNewProvider, (_, _) {});
      addTearDown(second.close);
      await h.flush();

      expect(h.state.bookingId, 'new-2');
    });
  });

  group('the drafts and the total', () {
    testWidgets('setDraft replaces the fields; the total follows', (
      tester,
    ) async {
      final h = await start(tester);
      expect(h.state.total.state, AdminNewTotalState.incomplete);

      h.fill();

      expect(h.state.isDirty, true);
      expect(h.state.car!.id, 'car-1');
      expect(h.state.total.state, AdminNewTotalState.ready);
      // 5 x (45 + 4)
      expect(h.state.total.totalToSave, 245);
      expect(h.state.errors, isEmpty);
      expect(h.state.canSave, true);
    });

    testWidgets('errors are known at once, but shown only after Save', (
      tester,
    ) async {
      final h = await start(tester);
      h.edit((i) => i.copyWith(fullName: 'Test Person'));

      expect(h.state.errors, isNotEmpty);
      expect(h.state.showErrors, false);
      expect(h.state.canSave, true);
    });

    testWidgets('prices not loaded: no total and Save cannot be pressed', (
      tester,
    ) async {
      final h = await start(tester, withPrices: false);
      h.fill();

      expect(h.state.total.state, AdminNewTotalState.pricesNotLoaded);
      expect(h.state.errors, {AdminBookingError.newTotalUnavailable});
      expect(h.state.canSave, false);

      await h.save();
      expect(h.bookings.creates, isEmpty);
    });

    testWidgets('cars not loaded: said so; no car can be chosen, so '
        'nothing can be saved; reloadCars tries again', (tester) async {
      final h = await start(
        tester,
        carsError: const AdminBookingsException(AdminBookingsFailure.other),
      );
      expect(h.state.cars, isNull);
      expect(h.state.carsFailed, true);

      h.fill();
      expect(h.state.car, isNull);
      expect(h.state.total.state, AdminNewTotalState.incomplete);
      expect(h.state.errors, {AdminBookingError.newTotalUnavailable});
      await h.save();
      expect(h.bookings.creates, isEmpty);

      h.bookings.carsError = null;
      h.notifier.reloadCars();
      await h.flush();
      expect(h.state.cars, isNotNull);
      expect(h.state.carsFailed, false);
      expect(h.state.errors, isEmpty);
      expect(h.bookings.carReads, 2);
    });

    testWidgets('a half-filled form never throws', (tester) async {
      final h = await start(tester);
      h.edit(
        (i) => i.copyWith(
          phone: 'x',
          pickup: TbilisiDateTime(2026, 1, 10, 18, 0),
          dropoff: TbilisiDateTime(2026, 1, 9, 18, 0),
        ),
      );
      h.notifier.setDraft(
        h.state.draft.copyWith(
          fields: h.state.draft.fields.copyWith(carId: 'gone-car'),
          noEmail: true,
          status: BookingStatus.cancelled,
        ),
      );

      expect(h.state.car, isNull);
      expect(h.state.total.state, AdminNewTotalState.incomplete);
      expect(h.state.errors, isNotEmpty);
      await h.save();
      expect(h.bookings.creates, isEmpty);
      expect(h.state.showErrors, true);
      expect(tester.takeException(), isNull);
    });
  });

  group('saving', () {
    testWidgets('stage 1: an invalid form sends nothing and shows its '
        'errors', (tester) async {
      final h = await start(tester);
      h.edit((i) => i.copyWith(fullName: 'Test Person'));

      await h.save();

      expect(h.bookings.creates, isEmpty);
      expect(h.state.showErrors, true);
      expect(h.state.saving, false);
      expect(h.state.notice, isNull);
      expect(h.state.createdId, isNull);
    });

    testWidgets('stage 2: the booking is created under the ID of the form, '
        'cleaned, with the total, createdBy "admin" and no createdAt', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();

      await h.save();

      final create = h.bookings.creates.single;
      expect(create.id, 'new-1');
      final booking = create.booking;
      expect(booking.id, isNull);
      expect(booking.createdAt, isNull);
      expect(booking.createdBy, 'admin');
      expect(booking.customer.fullName, 'Test Person');
      expect(booking.customer.phone, '+995555000000');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.totalPrice, 245);
      expect(booking.pickup, DateTime.utc(2026, 1, 10, 14));

      expect(h.state.saving, false);
      expect(h.state.notice, AdminBookingCreateNotice.saved);
      expect(h.state.createdId, 'new-1');
      expect(h.state.isCreated, true);
      expect(h.state.hasSomethingToLose, false);
    });

    testWidgets('the chosen status and "no e-mail" are stored', (tester) async {
      final h = await start(tester);
      h.fill();
      h.notifier.setDraft(
        h.state.draft.copyWith(status: BookingStatus.pending, noEmail: true),
      );

      await h.save();

      final booking = h.bookings.creates.single.booking;
      expect(booking.status, BookingStatus.pending);
      expect(booking.customer.email, noEmailPlaceholder);
    });

    testWidgets('"saving" lasts until the server has answered; the form is '
        'locked meanwhile; "saved" comes only then', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createPending = Completer<void>();

      final save = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.canEdit, false);
      expect(h.state.canSave, false);
      expect(h.state.notice, isNull);
      expect(h.state.createdId, isNull);

      h.edit((i) => i.copyWith(notes: 'Typed while saving.'));
      expect(h.state.draft.fields.input.notes, '');

      await tester.pump(const Duration(seconds: 5));
      expect(h.state.saving, true);

      h.bookings.createPending!.complete();
      await save;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.createdId, 'new-1');
    });

    testWidgets('a second call while one is running does nothing', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createPending = Completer<void>();

      final first = h.notifier.save();
      await h.flush();
      await h.notifier.save();
      await h.notifier.checkAgain();
      expect(h.bookings.creates, hasLength(1));

      h.bookings.createPending!.complete();
      await first;
      await h.flush();
      expect(h.bookings.creates, hasLength(1));
    });

    testWidgets('two calls in the same moment create one booking', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();

      await Future.wait([h.notifier.save(), h.notifier.save()]);
      await h.flush();

      expect(h.bookings.creates, hasLength(1));
    });

    testWidgets('after "saved" nothing more can be sent or edited', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      await h.save();

      await h.save();
      await h.checkAgain();
      h.edit((i) => i.copyWith(notes: 'Typed afterwards.'));

      expect(h.bookings.creates, hasLength(1));
      expect(h.state.draft.fields.input.notes, '');
      expect(h.state.canSave, false);
    });

    const failures = {
      AdminBookingCreateFailure.noConnection:
          AdminBookingCreateNotice.noConnection,
      AdminBookingCreateFailure.refused: AdminBookingCreateNotice.refused,
      AdminBookingCreateFailure.carMissing: AdminBookingCreateNotice.carMissing,
      AdminBookingCreateFailure.unknown: AdminBookingCreateNotice.unknown,
    };
    for (final entry in failures.entries) {
      testWidgets('${entry.key.name}: certainly not created; the form keeps '
          'its values, is not locked, and can be saved again with the same '
          'ID', (tester) async {
        final h = await start(tester);
        h.fill();
        h.bookings.createError = AdminBookingCreateException(entry.key);

        await h.save();

        expect(h.state.saving, false);
        expect(h.state.notice, entry.value);
        expect(h.state.mayAlreadyExist, false);
        expect(h.state.createdId, isNull);
        expect(h.state.canEdit, true);
        expect(h.state.draft.fields.input.fullName, ' Test Person ');

        h.bookings.createError = null;
        await h.save();
        expect(h.bookings.creates.map((create) => create.id), [
          'new-1',
          'new-1',
        ]);
        expect(h.state.createdId, 'new-1');
      });
    }

    testWidgets('a message about a failure stays while the admin edits, '
        'and can be hidden', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateException(
        AdminBookingCreateFailure.noConnection,
      );
      await h.save();

      h.edit((i) => i.copyWith(notes: 'A note.'));
      expect(h.state.notice, AdminBookingCreateNotice.noConnection);

      h.notifier.dismissNotice();
      expect(h.state.notice, isNull);
    });

    testWidgets('an error of an unexpected type is "please try again"', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = StateError('made up');

      await h.save();

      expect(h.state.notice, AdminBookingCreateNotice.unknown);
      expect(h.state.mayAlreadyExist, false);
    });

    testWidgets('the session ends during the save: nothing is reported and '
        'nothing breaks', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createPending = Completer<void>();
      final save = h.notifier.save();
      await h.flush();

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.createPending!.complete();
      await save;
      await h.flush();

      expect(h.state.status, AdminBookingNewStatus.inactive);
      expect(h.state.notice, isNull);
      expect(h.state.createdId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the form is left during the save: nothing breaks', (
      tester,
    ) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(
        adminBookingNewProvider,
        (_, _) {},
      );
      await h.flush();
      await h.flush();
      h.fill();
      h.bookings.createPending = Completer<void>();
      final save = h.notifier.save();
      await h.flush();

      subscription.close();
      await tester.pump(const Duration(seconds: 1));
      h.bookings.createPending!.complete();
      await save;
      await h.flush();

      expect(tester.takeException(), isNull);
    });
  });

  group('no answer from the server', () {
    testWidgets('the booking may exist: the form is locked, the values that '
        'were sent are kept, and only "Check again" is possible', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateNoAnswer();

      await h.save();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminBookingCreateNotice.noAnswer);
      expect(h.state.mayAlreadyExist, true);
      expect(h.state.pending!.customer.fullName, 'Test Person');
      expect(h.state.createdId, isNull);
      expect(h.state.canEdit, false);
      expect(h.state.canSave, false);
      expect(h.state.canCheckAgain, true);
      expect(h.state.hasSomethingToLose, true);

      // Locked: no edit, no second save, and the message cannot be hidden.
      h.edit((i) => i.copyWith(fullName: 'Other Person'));
      h.notifier.setDraft(
        h.state.draft.copyWith(status: BookingStatus.cancelled),
      );
      h.notifier.dismissNotice();
      await h.save();

      expect(h.state.draft.fields.input.fullName, ' Test Person ');
      expect(h.state.draft.status, BookingStatus.confirmed);
      expect(h.state.notice, AdminBookingCreateNotice.noAnswer);
      expect(h.bookings.creates, hasLength(1));
    });

    testWidgets('"Check again" when the first attempt DID arrive: nothing '
        'is written a second time, and the booking counts as saved', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      h.bookings
        ..createError = const AdminBookingCreateNoAnswer()
        ..createLandsAnyway = true;
      await h.save();
      expect(h.bookings.existingIds, {'new-1'});

      h.bookings.createError = null;
      await h.checkAgain();

      // The same ID and the same booking were asked about.
      expect(h.bookings.creates.map((create) => create.id), ['new-1', 'new-1']);
      expect(
        identical(h.bookings.creates[0].booking, h.bookings.creates[1].booking),
        true,
      );
      // One booking exists, not two.
      expect(h.bookings.existingIds, {'new-1'});
      expect(h.state.notice, AdminBookingCreateNotice.saved);
      expect(h.state.createdId, 'new-1');
      expect(h.state.mayAlreadyExist, false);
    });

    testWidgets('"Check again" when the first attempt did NOT arrive: the '
        'booking is created now, once', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateNoAnswer();
      await h.save();
      expect(h.bookings.existingIds, isEmpty);

      h.bookings.createError = null;
      await h.checkAgain();

      expect(h.bookings.existingIds, {'new-1'});
      expect(h.state.createdId, 'new-1');
      expect(h.state.notice, AdminBookingCreateNotice.saved);
    });

    testWidgets('"Check again" without an answer again: still locked, and '
        'it says so; it can be pressed again', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateNoAnswer();
      await h.save();

      await h.checkAgain();
      expect(h.state.notice, AdminBookingCreateNotice.stillUnknown);
      expect(h.state.mayAlreadyExist, true);
      expect(h.state.canCheckAgain, true);

      h.bookings.createError = null;
      await h.checkAgain();
      expect(h.state.createdId, 'new-1');
      expect(h.bookings.creates, hasLength(3));
    });

    for (final failure in [
      AdminBookingCreateFailure.noConnection,
      AdminBookingCreateFailure.refused,
      AdminBookingCreateFailure.unknown,
    ]) {
      testWidgets('"Check again" fails with ${failure.name}: that says '
          'nothing about the first attempt, so the form stays locked', (
        tester,
      ) async {
        final h = await start(tester);
        h.fill();
        h.bookings.createError = const AdminBookingCreateNoAnswer();
        await h.save();

        h.bookings.createError = AdminBookingCreateException(failure);
        await h.checkAgain();

        expect(h.state.notice, AdminBookingCreateNotice.stillUnknown);
        expect(h.state.mayAlreadyExist, true);
        expect(h.state.canEdit, false);
        expect(h.state.canCheckAgain, true);
        expect(h.state.createdId, isNull);
      });
    }

    testWidgets('"Check again" finds that the car is gone: the transaction '
        'looked, the booking does not exist, and the form is open again', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateNoAnswer();
      await h.save();

      h.bookings.createError = const AdminBookingCreateException(
        AdminBookingCreateFailure.carMissing,
      );
      await h.checkAgain();

      expect(h.state.notice, AdminBookingCreateNotice.carMissing);
      expect(h.state.mayAlreadyExist, false);
      expect(h.state.canEdit, true);
      expect(h.state.canCheckAgain, false);
    });

    testWidgets('"Check again" is "saving" while it runs and cannot run '
        'twice', (tester) async {
      final h = await start(tester);
      h.fill();
      h.bookings.createError = const AdminBookingCreateNoAnswer();
      await h.save();
      h.bookings
        ..createError = null
        ..createPending = Completer<void>();

      final check = h.notifier.checkAgain();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.canCheckAgain, false);
      await h.notifier.checkAgain();
      expect(h.bookings.creates, hasLength(2));

      h.bookings.createPending!.complete();
      await check;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.createdId, 'new-1');
    });

    testWidgets('"Check again" does nothing when no attempt is open', (
      tester,
    ) async {
      final h = await start(tester);
      h.fill();

      await h.checkAgain();

      expect(h.bookings.creates, isEmpty);
      expect(h.state.canCheckAgain, false);
    });
  });
}
