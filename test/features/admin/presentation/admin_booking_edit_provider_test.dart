import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_provider.dart';
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

/// A second, dearer and hidden car: 120 per day.
const dearCar = Car(
  id: 'car-2',
  brand: 'Toyota',
  model: 'Land Cruiser',
  year: 2022,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.hybrid,
  seats: 7,
  engineSize: 3.5,
  pricePerDay: 120,
  description: LocalizedText(),
  photos: [],
  active: false,
);

/// These tests build no widgets. They use testWidgets only for its clock:
/// inside it, time passes when the test says so, and a test fails by
/// itself when a timer is still running at its end.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth, this.id);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;
  final String id;

  AdminBookingEditState get state =>
      container.read(adminBookingEditProvider(id));

  AdminBookingEditNotifier get notifier =>
      container.read(adminBookingEditProvider(id).notifier);

  AdminBookingDraft get draft => state.draft!;

  /// Lets everything that is waiting run, without time passing.
  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> elapse(Duration duration) => tester.pump(duration);

  Future<void> emit(
    RawBookingDocument? document, {
    bool fromCache = false,
  }) async {
    bookings.emitBooking(document, fromCache: fromCache);
    await flush();
  }

  /// Changes the fields of the form.
  void edit(BookingFormInput Function(BookingFormInput input) change) =>
      notifier.setDraft(draft.copyWith(input: change(draft.input)));

  Future<void> save() async {
    await notifier.save();
    await flush();
  }
}

/// Starts with a signed-in admin (or [session]), the booking "b1" not yet
/// delivered. With [watch] the provider is kept alive, as the screen does.
Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  String id = 'b1',
  List<Car>? cars,
  Object? carsError,
  bool withPrices = true,
  bool withPlaces = true,
  bool watch = true,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository()
    ..cars = cars ?? [testCar(), dearCar]
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
  final harness = Harness(tester, container, bookings, auth, id);
  addTearDown(container.dispose);
  addTearDown(auth.close);

  container.read(adminSessionProvider);
  await harness.flush();
  if (watch) {
    final subscription = container.listen(
      adminBookingEditProvider(id),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await harness.flush();
    await harness.flush();
  }
  return harness;
}

/// Starts and delivers the stored booking: 5 days, car-1, total 225.
Future<Harness> startEditing(
  WidgetTester tester, {
  List<Car>? cars,
  Object? carsError,
  bool withPrices = true,
  bool withPlaces = true,
  Map<String, dynamic> changes = const {},
}) async {
  final h = await start(
    tester,
    cars: cars,
    carsError: carsError,
    withPrices: withPrices,
    withPlaces: withPlaces,
  );
  await h.emit(rawBooking('b1', changes: changes));
  return h;
}

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, and nothing is '
          'asked for', (tester) async {
        final h = await start(tester, session: session);

        expect(h.state.status, AdminBookingEditStatus.inactive);
        expect(h.bookings.watchedBookingIds, isEmpty);
        expect(h.bookings.carReads, 0);
        expect(h.bookings.activeBookingListeners, 0);
      });
    }

    testWidgets('admin: one listener for this booking, the cars read once, '
        'the places and prices from settings', (tester) async {
      final h = await start(tester);

      expect(h.state.status, AdminBookingEditStatus.loading);
      expect(h.bookings.watchedBookingIds, ['b1']);
      expect(h.bookings.activeBookingListeners, 1);
      expect(h.bookings.carReads, 1);
      expect(h.state.cars!.map((car) => car.id), ['car-1', 'car-2']);
      expect(h.state.locations, places);
      expect(h.state.extrasPrices, prices());
    });

    testWidgets('an ID of an impossible shape is "missing" and Firestore is '
        'not asked', (tester) async {
      final h = await start(tester, id: 'a b');

      expect(h.state.status, AdminBookingEditStatus.missing);
      expect(h.bookings.watchedBookingIds, isEmpty);
      expect(h.bookings.carReads, 0);
    });

    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('when the session becomes ${session.name} the listener is '
          'closed and the drafts are forgotten', (tester) async {
        final h = await startEditing(tester);
        h.edit((i) => i.copyWith(fullName: 'Other Person'));

        h.auth.report(session);
        await h.flush();

        expect(h.bookings.activeBookingListeners, 0);
        expect(h.state.status, AdminBookingEditStatus.inactive);
        expect(h.state.draft, isNull);
        expect(h.state.base, isNull);
      });
    }

    testWidgets('leaving the screen closes the listener', (tester) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(
        adminBookingEditProvider('b1'),
        (_, _) {},
      );
      await h.flush();
      expect(h.bookings.activeBookingListeners, 1);

      subscription.close();
      await h.elapse(const Duration(seconds: 1));

      expect(h.bookings.activeBookingListeners, 0);
    });

    testWidgets('an error that arrives after the sign-out is not shown', (
      tester,
    ) async {
      final h = await startEditing(tester);

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingEditStatus.inactive);
      expect(h.state.failure, isNull);
    });
  });

  group('loading the booking', () {
    testWidgets('the first answer becomes the form, unchanged', (tester) async {
      final h = await startEditing(tester);

      expect(h.state.status, AdminBookingEditStatus.editing);
      expect(h.state.base!.id, 'b1');
      expect(h.state.latest, h.state.base);
      expect(h.draft.input.fullName, 'Test Person');
      expect(h.draft.carId, 'car-1');
      expect(h.state.isDirty, false);
      expect(h.state.errors, isEmpty);
      expect(h.state.showErrors, false);
      expect(h.state.car!.id, 'car-1');
    });

    testWidgets('the server says there is no such booking: missing', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(null);

      expect(h.state.status, AdminBookingEditStatus.missing);
    });

    testWidgets('a document that is not a booking: unreadable', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', changes: {'status': 'approved'}));

      expect(h.state.status, AdminBookingEditStatus.unreadable);
      expect(h.state.draft, isNull);
    });

    testWidgets('the saved copy not having it is not "missing"; after 3 '
        'seconds without the server it is "could not load"', (tester) async {
      final h = await start(tester);
      await h.emit(null, fromCache: true);
      expect(h.state.status, AdminBookingEditStatus.loading);

      await h.elapse(const Duration(seconds: 3));

      expect(h.state.status, AdminBookingEditStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.other);
      expect(h.bookings.activeBookingListeners, 0);

      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminBookingEditStatus.loading);
      await h.emit(rawBooking('b1'));
      expect(h.state.status, AdminBookingEditStatus.editing);
      // The cars were kept; they are not read again.
      expect(h.bookings.carReads, 1);
    });

    testWidgets('the server answers in time: no failure later', (tester) async {
      final h = await start(tester);
      await h.emit(null, fromCache: true);
      await h.elapse(const Duration(seconds: 1));
      await h.emit(rawBooking('b1'));

      await h.elapse(const Duration(seconds: 5));

      expect(h.state.status, AdminBookingEditStatus.editing);
    });

    testWidgets('an error is shown as a failure', (tester) async {
      final h = await start(tester);
      h.bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingEditStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.permissionDenied);
    });

    testWidgets('cars that cannot be loaded leave the form usable', (
      tester,
    ) async {
      final h = await startEditing(
        tester,
        carsError: const AdminBookingsException(AdminBookingsFailure.other),
      );

      expect(h.state.status, AdminBookingEditStatus.editing);
      expect(h.state.cars, isNull);
      expect(h.state.car, isNull);
      expect(h.state.errors, isEmpty);
    });

    testWidgets('settings that cannot be loaded leave the form usable', (
      tester,
    ) async {
      final h = await startEditing(
        tester,
        withPrices: false,
        withPlaces: false,
      );

      expect(h.state.locations, isNull);
      expect(h.state.extrasPrices, isNull);
      // The stored places stay valid.
      expect(h.state.errors, isEmpty);
      expect(h.state.totals!.newPrice, isNull);
    });
  });

  group('the drafts', () {
    testWidgets('setDraft replaces the fields and makes the form dirty', (
      tester,
    ) async {
      final h = await startEditing(tester);

      h.edit((i) => i.copyWith(fullName: 'Other Person', notes: 'A note.'));

      expect(h.draft.input.fullName, 'Other Person');
      expect(h.state.isDirty, true);
      expect(h.state.editedFields, {
        AdminBookingField.customer,
        AdminBookingField.notes,
      });
      // The starting point is untouched.
      expect(h.state.base!.customer.fullName, 'Test Person');
    });

    testWidgets('errors are known at once, but shown only after Save', (
      tester,
    ) async {
      final h = await startEditing(tester);

      h.edit((i) => i.copyWith(fullName: ''));

      expect(h.state.errors, {AdminBookingError.nameRequired});
      expect(h.state.showErrors, false);
    });

    testWidgets('changing the car asks for a choice of the total; the '
        'choice is not made for the admin', (tester) async {
      final h = await startEditing(tester);

      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));

      final totals = h.state.totals!;
      expect(totals.storedCents, 22500);
      expect(totals.newPrice!.totalCents, 60000);
      expect(totals.choiceNeeded, true);
      expect(h.draft.totalChoice, isNull);
      expect(h.state.errors, {AdminBookingError.totalChoiceRequired});
    });

    testWidgets('chooseTotal sets the choice; a later change of car, dates '
        'or extras removes it again', (tester) async {
      final h = await startEditing(tester);
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));

      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      expect(h.draft.totalChoice, AdminTotalChoice.useNew);
      expect(h.state.errors, isEmpty);

      // A field the price does not depend on keeps the choice.
      h.edit((i) => i.copyWith(notes: 'A note.'));
      expect(h.draft.totalChoice, AdminTotalChoice.useNew);

      h.edit((i) => i.copyWith(extras: {Extra.childSeat}));
      expect(h.draft.totalChoice, isNull);
      expect(h.state.errors, {AdminBookingError.totalChoiceRequired});
    });

    testWidgets('a choice alone makes the form dirty', (tester) async {
      final h = await startEditing(tester);
      h.notifier.chooseTotal(AdminTotalChoice.keepStored);

      expect(h.state.isDirty, true);
    });

    testWidgets('nothing can be edited before the booking is there', (
      tester,
    ) async {
      final h = await start(tester);

      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      await h.save();

      expect(h.state.draft, isNull);
      expect(h.bookings.updates, isEmpty);
    });
  });

  group('the live read while editing', () {
    testWidgets('without unsaved changes the form follows the stored '
        'booking', (tester) async {
      final h = await startEditing(tester);

      await h.emit(rawBooking('b1', fullName: 'Changed Elsewhere'));

      expect(h.state.base!.customer.fullName, 'Changed Elsewhere');
      expect(h.draft.input.fullName, 'Changed Elsewhere');
      expect(h.state.isDirty, false);
    });

    testWidgets('with unsaved changes the form and its starting point stay; '
        'the change elsewhere is known', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'My note.'));
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));

      await h.emit(
        rawBooking('b1', carId: 'car-9', fullName: 'Changed Elsewhere'),
      );

      expect(h.draft.input.notes, 'My note.');
      expect(h.draft.carId, 'car-2');
      expect(h.state.base!.carId, 'car-1');
      expect(h.state.latest!.carId, 'car-9');
      // Only the car is both edited here and changed elsewhere.
      expect(h.state.changedElsewhere, {AdminBookingField.car});
    });

    testWidgets('a status change elsewhere is not a conflict', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'My note.'));

      await h.emit(rawBooking('b1', status: 'confirmed'));

      expect(h.state.changedElsewhere, isEmpty);
      expect(h.draft.input.notes, 'My note.');
    });

    testWidgets('loadCurrent drops the edits and takes the stored booking', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));
      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      await h.emit(rawBooking('b1', carId: 'car-9'));

      h.notifier.loadCurrent();

      expect(h.state.base!.carId, 'car-9');
      expect(h.draft.carId, 'car-9');
      expect(h.draft.totalChoice, isNull);
      expect(h.state.isDirty, false);
      expect(h.state.changedElsewhere, isEmpty);
      expect(h.state.notice, isNull);
    });

    testWidgets('a booking deleted while it is edited becomes missing', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'My note.'));

      await h.emit(null);

      expect(h.state.status, AdminBookingEditStatus.missing);
      expect(h.state.draft, isNull);
    });
  });

  group('changed elsewhere, with the total', () {
    testWidgets('dates edited, "use the new total", the car changed '
        'elsewhere: the car is named', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 17, 20, 0)));
      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      expect(h.state.fieldsToWrite, {
        AdminBookingField.dropoff,
        AdminBookingField.total,
      });

      await h.emit(rawBooking('b1', carId: 'car-2'));

      expect(h.state.changedElsewhere, {AdminBookingField.car});
    });

    testWidgets('the same with "keep the stored total": nothing', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 17, 20, 0)));
      h.notifier.chooseTotal(AdminTotalChoice.keepStored);
      expect(h.state.fieldsToWrite, {AdminBookingField.dropoff});

      await h.emit(rawBooking('b1', carId: 'car-2'));

      expect(h.state.changedElsewhere, isEmpty);
    });

    testWidgets('no choice yet: the total is not among the parts to write', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 17, 20, 0)));

      await h.emit(rawBooking('b1', carId: 'car-2'));

      expect(h.state.fieldsToWrite, {AdminBookingField.dropoff});
      expect(h.state.changedElsewhere, isEmpty);
    });

    testWidgets('"use the new total" with a new total equal to the stored '
        'one writes no total, so the price fields are not compared', (
      tester,
    ) async {
      final h = await startEditing(tester);
      // One hour later on both ends: still 5 days, still 225.
      h.edit(
        (i) => i.copyWith(
          pickup: TbilisiDateTime(2026, 1, 10, 19, 0),
          dropoff: TbilisiDateTime(2026, 1, 15, 21, 0),
        ),
      );
      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      expect(h.state.totals!.differs, false);

      await h.emit(
        rawBooking(
          'b1',
          changes: {
            'extras': ['snowChains'],
          },
        ),
      );

      expect(h.state.fieldsToWrite, {
        AdminBookingField.pickup,
        AdminBookingField.dropoff,
      });
      expect(h.state.changedElsewhere, isEmpty);
    });

    testWidgets('a notes-only edit: a car changed elsewhere is no conflict', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'My note.'));

      await h.emit(rawBooking('b1', carId: 'car-2', totalPrice: 600));

      expect(h.state.changedElsewhere, isEmpty);
    });

    testWidgets('the save sends the total among the edited parts, so the '
        'transaction compares the price fields too', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 17, 20, 0)));
      h.notifier.chooseTotal(AdminTotalChoice.useNew);

      await h.save();

      final changes = h.bookings.updates.single.changes;
      expect(changes.fields, {
        AdminBookingField.dropoff,
        AdminBookingField.total,
      });
      // What the repository hands to conflictingFields.
      expect(fieldsToCompare(changes.fields), {
        AdminBookingField.total,
        ...priceFields,
      });
    });
  });

  group('a stored value the rules refuse', () {
    testWidgets('a hand-made phone with spaces: the save does not start and '
        'the part is named; correcting it saves the cleaned customer', (
      tester,
    ) async {
      final h = await startEditing(
        tester,
        changes: {
          'customer': {
            'fullName': 'Test Person',
            'phone': '+995 555 00-00-00',
            'whatsapp': false,
            'telegram': false,
            'email': 'person@example.com',
          },
        },
      );
      expect(h.state.errors, {AdminBookingError.phoneStoredFormat});

      h.edit((i) => i.copyWith(notes: 'A note.'));
      await h.save();
      expect(h.bookings.updates, isEmpty);
      expect(h.state.showErrors, true);
      expect(h.state.errors, {AdminBookingError.phoneStoredFormat});

      h.edit((i) => i.copyWith(phone: '+995555000000'));
      expect(h.state.errors, isEmpty);
      await h.save();

      final values = h.bookings.updates.single.changes.values;
      expect(values.keys.toSet(), {'customer', 'notes'});
      expect((values['customer'] as Map)['phone'], '+995555000000');
    });
  });

  group('a half-filled form', () {
    testWidgets('the getters of the state never throw', (tester) async {
      final h = await startEditing(tester);
      final emptyDates = AdminBookingDraft(
        input: BookingFormInput(
          fullName: '',
          phone: 'x',
          email: '',
          pickupLocation: h.draft.input.pickupLocation,
        ),
        carId: 'gone-car',
        language: AppLanguage.en,
        totalChoice: AdminTotalChoice.useNew,
      );
      final backwards = h.draft.copyWith(
        input: h.draft.input.copyWith(
          dropoff: TbilisiDateTime(2026, 1, 9, 18, 0),
        ),
        carId: '',
      );

      for (final draft in [emptyDates, backwards]) {
        h.notifier.setDraft(draft);
        h.notifier.chooseTotal(AdminTotalChoice.useNew);

        expect(h.state.car, isNull);
        expect(h.state.totals!.newPrice, isNull);
        expect(h.state.errors, isNotEmpty);
        expect(h.state.isDirty, true);
        expect(h.state.editedFields, isNotEmpty);
        expect(h.state.fieldsToWrite, isNot(contains(AdminBookingField.total)));
        // Read before and after a change elsewhere; only "does not throw"
        // is checked here (both drafts changed the car themselves).
        expect(h.state.changedElsewhere, isNotNull);
        await h.emit(rawBooking('b1', carId: 'car-2'));
        expect(h.state.changedElsewhere, contains(AdminBookingField.car));

        // Save stops at stage 1 and sends nothing.
        await h.save();
        expect(h.bookings.updates, isEmpty);
        expect(h.state.showErrors, true);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('saving', () {
    testWidgets('stage 1: an invalid form sends nothing and shows its '
        'errors', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(phone: 'x'));

      await h.save();

      expect(h.bookings.updates, isEmpty);
      expect(h.state.showErrors, true);
      expect(h.state.saving, false);
      expect(h.state.notice, isNull);
    });

    testWidgets('stage 1: without a choice of the total nothing is sent', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));

      await h.save();

      expect(h.bookings.updates, isEmpty);
      expect(h.state.showErrors, true);
      expect(h.state.errors, {AdminBookingError.totalChoiceRequired});
    });

    testWidgets('stage 1: nothing changed, nothing is sent', (tester) async {
      final h = await startEditing(tester);

      await h.save();
      // Typing a space that the cleaning removes is no change either.
      h.edit((i) => i.copyWith(fullName: 'Test Person '));
      await h.save();

      expect(h.bookings.updates, isEmpty);
      expect(h.state.notice, isNull);
    });

    testWidgets('a changed date is sent as a UTC moment', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(pickup: TbilisiDateTime(2026, 1, 11, 18, 0)));
      // Four days instead of five: the total would change, so a choice is
      // needed.
      h.notifier.chooseTotal(AdminTotalChoice.keepStored);

      await h.save();

      expect(h.bookings.updates.single.changes.values, {
        'pickupDateTime': DateTime.utc(2026, 1, 11, 14),
      });
    });

    testWidgets('a text change only: the total is not sent', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(fullName: ' Other Person ', notes: 'A note.'));
      h.notifier.setDraft(h.draft.copyWith(language: AppLanguage.ka));

      await h.save();

      final update = h.bookings.updates.single;
      expect(update.id, 'b1');
      expect(update.base.customer.fullName, 'Test Person');
      expect(update.changes.fields, {
        AdminBookingField.customer,
        AdminBookingField.notes,
        AdminBookingField.language,
      });
      expect(update.changes.values, {
        'customer': {
          'fullName': 'Other Person',
          'phone': '+995555000000',
          'whatsapp': false,
          'telegram': false,
          'email': 'person@example.com',
        },
        'notes': 'A note.',
        'language': 'ka',
      });
      expect(h.state.notice, AdminBookingSaveNotice.saved);
    });

    testWidgets('"keep the stored total": the car is sent, the total is '
        'not', (tester) async {
      final h = await startEditing(tester);
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));
      h.notifier.chooseTotal(AdminTotalChoice.keepStored);

      await h.save();

      expect(h.bookings.updates.single.changes.values, {'carId': 'car-2'});
    });

    testWidgets('"use the new total": the car and the new total are sent', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));
      h.notifier.chooseTotal(AdminTotalChoice.useNew);

      await h.save();

      expect(h.bookings.updates.single.changes.values, {
        'carId': 'car-2',
        'totalPrice': 600.0,
      });
    });

    testWidgets('status, createdAt and createdBy are never sent', (
      tester,
    ) async {
      final h = await startEditing(
        tester,
        changes: {'status': 'confirmed', 'createdBy': 'Made-up Staff'},
      );
      h.edit(
        (i) => i.copyWith(
          fullName: 'Other Person',
          notes: 'A note.',
          extras: {Extra.snowChains},
          dropoff: TbilisiDateTime(2026, 1, 16, 20, 0),
        ),
      );
      h.notifier.setDraft(
        h.draft.copyWith(carId: 'car-2', language: AppLanguage.ru),
      );
      h.notifier.chooseTotal(AdminTotalChoice.useNew);

      await h.save();

      final keys = h.bookings.updates.single.changes.values.keys;
      for (final key in ['status', 'createdAt', 'createdBy']) {
        expect(keys, isNot(contains(key)));
      }
    });

    testWidgets('"saving" lasts until the server has answered, and "saved" '
        'comes only then; the form is locked meanwhile', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updatePending = Completer<void>();

      final save = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.notice, isNull);

      // Locked: no edit, no choice, no reload.
      h.edit((i) => i.copyWith(notes: 'Another note.'));
      h.notifier.chooseTotal(AdminTotalChoice.useNew);
      h.notifier.loadCurrent();
      expect(h.draft.input.notes, 'A note.');
      expect(h.draft.totalChoice, isNull);

      await h.elapse(const Duration(seconds: 5));
      expect(h.state.saving, true);

      h.bookings.updatePending!.complete();
      await save;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.notice, AdminBookingSaveNotice.saved);
    });

    testWidgets('after "saved" the edited booking is the new starting '
        'point and the form is clean', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: ' A note. '));

      await h.save();

      expect(h.state.base!.notes, 'A note.');
      expect(h.draft.input.notes, 'A note.');
      expect(h.state.isDirty, false);
      expect(h.state.showErrors, false);

      // A second save has nothing to send.
      await h.save();
      expect(h.bookings.updates, hasLength(1));
    });

    testWidgets('a second call while one is running does nothing', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updatePending = Completer<void>();

      final first = h.notifier.save();
      await h.flush();
      await h.notifier.save();
      await h.notifier.save();
      expect(h.bookings.updates, hasLength(1));

      h.bookings.updatePending!.complete();
      await first;
      await h.flush();
      expect(h.bookings.updates, hasLength(1));
    });

    testWidgets('two calls in the same moment write once', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));

      await Future.wait([h.notifier.save(), h.notifier.save()]);
      await h.flush();

      expect(h.bookings.updates, hasLength(1));
    });

    testWidgets('no answer within the time limit is not "not saved", and '
        'the form keeps what was typed', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updateError = const AdminBookingSaveNoAnswer();

      await h.save();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminBookingSaveNotice.noAnswer);
      expect(h.draft.input.notes, 'A note.');
      expect(h.state.base!.notes, '');
      expect(h.state.isDirty, true);
    });

    for (final failure in AdminBookingSaveFailure.values) {
      testWidgets('${failure.name}: not saved, the form keeps what was '
          'typed and can be saved again', (tester) async {
        final h = await startEditing(tester);
        h.edit((i) => i.copyWith(notes: 'A note.'));
        h.bookings.updateError = AdminBookingSaveException(failure);

        await h.save();

        expect(h.state.saving, false);
        expect(h.state.notice, noticeForSaveFailure(failure));
        expect(h.state.status, AdminBookingEditStatus.editing);
        expect(h.draft.input.notes, 'A note.');
        expect(h.state.isDirty, true);

        h.bookings.updateError = null;
        await h.save();
        expect(h.bookings.updates, hasLength(2));
        expect(h.state.notice, AdminBookingSaveNotice.saved);
      });
    }

    testWidgets('unknown fields are reported by name', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.unknownFields,
        fields: ['zzTest'],
      );

      await h.save();

      expect(h.state.notice, AdminBookingSaveNotice.unknownFields);
      expect(h.state.noticeFields, ['zzTest']);
    });

    testWidgets('a conflict names the parts; "keep editing" keeps the '
        'form, "load the current booking" drops it', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'My note.'));
      h.bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.conflict,
        fields: ['notes'],
      );
      await h.save();
      expect(h.state.notice, AdminBookingSaveNotice.conflict);
      expect(h.state.noticeFields, ['notes']);

      // The message stays while the admin reads and types on.
      h.edit((i) => i.copyWith(notes: 'My note, longer.'));
      expect(h.state.notice, AdminBookingSaveNotice.conflict);

      h.notifier.dismissNotice();
      expect(h.state.notice, isNull);
      expect(h.state.noticeFields, isEmpty);
      expect(h.draft.input.notes, 'My note, longer.');

      await h.emit(rawBooking('b1', changes: {'notes': 'Their note.'}));
      h.notifier.loadCurrent();
      expect(h.draft.input.notes, 'Their note.');
      expect(h.state.isDirty, false);
    });

    testWidgets('"Saved" goes away when the admin edits again', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      await h.save();
      expect(h.state.notice, AdminBookingSaveNotice.saved);

      h.edit((i) => i.copyWith(notes: 'Another note.'));

      expect(h.state.notice, isNull);
    });

    testWidgets('an error of an unexpected type is "please try again"', (
      tester,
    ) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updateError = StateError('made up');

      await h.save();

      expect(h.state.notice, AdminBookingSaveNotice.unknown);
      expect(h.state.saving, false);
    });

    testWidgets('a live answer during the save keeps the form and '
        '"saving"', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updatePending = Completer<void>();
      final save = h.notifier.save();
      await h.flush();

      await h.emit(rawBooking('b1', changes: {'notes': 'A note.'}));
      expect(h.state.saving, true);
      expect(h.draft.input.notes, 'A note.');

      h.bookings.updatePending!.complete();
      await save;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.notice, AdminBookingSaveNotice.saved);
      expect(h.state.isDirty, false);
    });

    testWidgets('the session ends during the save: nothing is reported and '
        'nothing breaks', (tester) async {
      final h = await startEditing(tester);
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updatePending = Completer<void>();
      final save = h.notifier.save();
      await h.flush();

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.updatePending!.complete();
      await save;
      await h.flush();

      expect(h.state.status, AdminBookingEditStatus.inactive);
      expect(h.state.notice, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen is left during the save: nothing breaks', (
      tester,
    ) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(
        adminBookingEditProvider('b1'),
        (_, _) {},
      );
      await h.flush();
      await h.flush();
      await h.emit(rawBooking('b1'));
      h.edit((i) => i.copyWith(notes: 'A note.'));
      h.bookings.updatePending = Completer<void>();
      final save = h.notifier.save();
      await h.flush();

      subscription.close();
      await h.elapse(const Duration(seconds: 1));
      h.bookings.updatePending!.complete();
      await save;
      await h.flush();

      expect(tester.takeException(), isNull);
    });

    testWidgets('not an admin: nothing is written', (tester) async {
      final h = await start(tester, session: AdminSession.noAccess);

      await h.save();

      expect(h.bookings.updates, isEmpty);
    });
  });
}
