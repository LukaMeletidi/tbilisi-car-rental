import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_edit_form.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The real router and the real screens; Firebase is replaced. Every value
/// is made up.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Tbilisi Office'),
  ),
];

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

const editAddress = '/admin/bookings/b1/edit';

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

/// The clock of the tests: 9 Oct 2026, 16:00 in Tbilisi.
final now = DateTime.utc(2026, 10, 9, 12);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

String address(WidgetTester tester) => containerOf(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

Future<void> open(WidgetTester tester, String address) async {
  containerOf(tester).read(appRouterProvider).go(address);
  await settle(tester);
}

Future<void> pumpApp(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  Size size = const Size(800, 3200),
  bool withPrices = true,
  bool withPlaces = true,
  List<Car>? cars,
  Object? carsError,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  auth = FakeAdminAuthRepository(initial: session);
  bookings = FakeAdminBookingsRepository()
    ..cars = cars ?? [testCar(), dearCar]
    ..carsError = carsError;
  addTearDown(auth.close);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => now),
        activeCarsProvider.overrideWith((ref) => Stream.value([testCar()])),
        pickupLocationsProvider.overrideWith(
          (ref) => withPlaces
              ? Stream.value(places)
              : Stream.error(const FormatException('made up')),
        ),
        extrasPricesProvider.overrideWith(
          (ref) => withPrices
              ? Stream.value(
                  ExtrasPrices.fromMap({
                    'pricesPerDay': {
                      'snowChains': 5,
                      'childSeat': 4,
                      'infantSeat': 3,
                      'boosterSeat': 2.5,
                    },
                  }),
                )
              : Stream.error(const FormatException('made up')),
        ),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

/// Opens the edit form of the stored booking "b1": 5 days, car-1, total
/// 225, pickup 10 Jan 2026 18:00 in Tbilisi.
Future<void> openEdit(
  WidgetTester tester, {
  Map<String, dynamic> changes = const {},
  Size size = const Size(800, 3200),
  bool withPrices = true,
  bool withPlaces = true,
  List<Car>? cars,
  Object? carsError,
}) async {
  await pumpApp(
    tester,
    size: size,
    withPrices: withPrices,
    withPlaces: withPlaces,
    cars: cars,
    carsError: carsError,
  );
  await open(tester, editAddress);
  bookings.emitBookingToAll(rawBooking('b1', changes: changes));
  await settle(tester);
}

Finder field(String label) => find.widgetWithText(TextField, label);

Finder get notesField => find.descendant(
  of: find.byType(AdminBookingEditForm),
  matching: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.maxLines == 8,
  ),
);

String textOf(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

Finder get saveButton => find.widgetWithText(FilledButton, adminSave);

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(saveButton).onPressed != null;

Future<void> type(WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await settle(tester);
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(saveButton);
  await settle(tester);
}

/// Opens the dropdown that shows [shown] and picks [choice].
Future<void> choose(WidgetTester tester, String shown, String choice) async {
  await tester.tap(find.text(shown).first);
  await settle(tester);
  await tester.tap(find.text(choice).last);
  await settle(tester);
}

const prius = 'Toyota Prius, 2019';
const cruiserHidden = 'Toyota Land Cruiser, 2022 (hidden)';

void main() {
  group('what the form shows', () {
    testWidgets('every stored value, and Save is disabled while nothing '
        'changed', (tester) async {
      await openEdit(tester);

      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(find.text(adminEditTitle), findsOneWidget);
      expect(textOf(tester, field(adminLabelName)), 'Test Person');
      expect(textOf(tester, field(adminLabelPhone)), '+995555000000');
      expect(textOf(tester, field(adminLabelEmail)), 'person@example.com');
      expect(textOf(tester, notesField), '');
      expect(find.text('English (en)'), findsWidgets);
      expect(find.text(prius), findsWidgets);
      // Stored 14:00 and 16:00 UTC; Tbilisi time, in the admin format.
      expect(find.text('10 Jan 2026 18:00'), findsOneWidget);
      expect(find.text('15 Jan 2026 20:00'), findsOneWidget);
      expect(find.text('Tbilisi Airport'), findsWidgets);
      expect(find.text('Tbilisi Office'), findsWidgets);
      expect(find.text('Child seat · \$4 per day'), findsOneWidget);
      expect(find.text('Booster seat · \$2.50 per day'), findsOneWidget);
      expect(find.text('Stored total: 5 days · \$225'), findsOneWidget);
      expect(find.text(adminTotalStays), findsOneWidget);
      expect(saveEnabled(tester), false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pickup in the past has a note; a coming one has none', (
      tester,
    ) async {
      await openEdit(tester);
      expect(find.text(adminPickupInPastNote), findsOneWidget);

      bookings.emitBookingToAll(
        rawBooking(
          'b1',
          pickup: DateTime.utc(2027, 1, 10, 14),
          dropoff: DateTime.utc(2027, 1, 15, 16),
        ),
      );
      await settle(tester);
      expect(find.text(adminPickupInPastNote), findsNothing);
    });

    testWidgets('a hidden car is marked in the list of cars', (tester) async {
      await openEdit(tester);

      await tester.tap(find.text(prius).first);
      await settle(tester);

      expect(find.text(cruiserHidden), findsWidgets);
    });

    testWidgets('a car that was deleted is shown as "<id> (not found)", and '
        'Save reports it', (tester) async {
      await openEdit(tester, changes: {'carId': 'gone-car'});

      expect(find.text('gone-car (not found)'), findsWidgets);

      await type(tester, notesField, 'A note.');
      await tapSave(tester);

      expect(
        find.text('This car no longer exists. Choose another car.'),
        findsOneWidget,
      );
      expect(bookings.updates, isEmpty);
    });

    testWidgets('cars that cannot be loaded: the car is shown by its ID and '
        'cannot be changed', (tester) async {
      await openEdit(tester, carsError: StateError('made up'));

      expect(find.text('car-1'), findsWidgets);
      expect(find.text(adminCarsNotLoaded), findsOneWidget);
    });

    testWidgets('a stored place that settings no longer has stays in the '
        'list, marked', (tester) async {
      await openEdit(
        tester,
        changes: {
          'pickupLocation': {'id': 'oldPlace'},
        },
      );

      expect(find.text('oldPlace (not in the list any more)'), findsWidgets);
      expect(find.text(adminPlacesNotLoaded), findsNothing);
    });

    testWidgets('places that cannot be loaded: the stored place by its ID, '
        'and a note', (tester) async {
      await openEdit(tester, withPlaces: false);

      expect(find.text('tbilisiAirport'), findsWidgets);
      expect(find.text(adminPlacesNotLoaded), findsOneWidget);
    });

    testWidgets('another place shows its address field', (tester) async {
      await openEdit(
        tester,
        changes: {
          'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
        },
      );

      expect(textOf(tester, field(adminLabelAddress)), 'Made-up Street 1');
      expect(find.text(adminOtherPlace), findsWidgets);
    });

    testWidgets('a stored value in a format the rules refuse is said at '
        'once, before any Save', (tester) async {
      await openEdit(
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

      expect(
        find.text(
          'The phone number is stored in a format the app does not accept. '
          'Edit it to correct it.',
        ),
        findsOneWidget,
      );

      await type(tester, field(adminLabelPhone), '+995555000000');
      expect(find.textContaining('stored in a format'), findsNothing);
    });

    testWidgets('the text fields do not teach the keyboard: no autocorrect, '
        'no suggestions, no autofill', (tester) async {
      await openEdit(
        tester,
        changes: {
          'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
        },
      );

      final fields = tester.widgetList<TextField>(
        find.descendant(
          of: find.byType(AdminBookingEditForm),
          matching: find.byType(TextField),
        ),
      );
      // Name, phone, e-mail, address, notes.
      expect(fields, hasLength(5));
      for (final field in fields) {
        expect(field.autocorrect, false);
        expect(field.enableSuggestions, false);
        expect(field.autofillHints, isNull);
      }
      TextField of(String label) => tester.widget<TextField>(field(label));
      expect(of(adminLabelName).keyboardType, TextInputType.name);
      expect(of(adminLabelPhone).keyboardType, TextInputType.phone);
      expect(of(adminLabelEmail).keyboardType, TextInputType.emailAddress);
    });

    testWidgets('the date pickers offer 5 years back and 2 years ahead', (
      tester,
    ) async {
      await openEdit(tester);

      await tester.tap(find.text('10 Jan 2026 18:00'));
      await settle(tester);

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2021, 1, 1));
      expect(dialog.lastDate, DateTime(2028, 12, 31));
      expect(dialog.initialDate, DateTime(2026, 1, 10));

      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(saveEnabled(tester), false);
    });

    testWidgets('fits a phone 320 wide, also with errors and the choice of '
        'the total', (tester) async {
      await openEdit(tester, size: const Size(320, 4200));
      await type(tester, field(adminLabelName), '');
      await choose(tester, prius, cruiserHidden);
      await tester.tap(find.textContaining('Keep the stored total'));
      await settle(tester);
      await tapSave(tester);

      expect(find.text('Enter the name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('saving', () {
    testWidgets('a changed name and notes: only those parts are sent; then '
        'the detail is shown and says "Saved"', (tester) async {
      await openEdit(tester);

      await type(tester, field(adminLabelName), ' Other Person ');
      await type(tester, notesField, 'A note.');
      expect(saveEnabled(tester), true);
      await tapSave(tester);

      final update = bookings.updates.single;
      expect(update.id, 'b1');
      expect(update.changes.values.keys.toSet(), {'customer', 'notes'});
      expect(
        (update.changes.values['customer'] as Map)['fullName'],
        'Other Person',
      );

      expect(find.byType(AdminBookingEditScreen), findsNothing);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/b1');
      // The notice the detail already has for a status change.
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('"Saving…": the button and the fields are disabled until '
        'the server answered; "Saved" comes only then', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');
      bookings.updatePending = Completer<void>();

      await tapSave(tester);

      expect(find.text(adminSaving), findsOneWidget);
      expect(saveEnabled(tester), false);
      expect(tester.widget<TextField>(field(adminLabelName)).enabled, false);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(find.text('Saved'), findsNothing);

      bookings.updatePending!.complete();
      await settle(tester);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('errors appear after Save, with a line above the button; '
        'nothing is sent', (tester) async {
      await openEdit(tester);
      await type(tester, field(adminLabelName), '');
      expect(find.text('Enter the name.'), findsNothing);

      await tapSave(tester);

      expect(find.text('Enter the name.'), findsOneWidget);
      expect(find.text(adminCorrectFields), findsOneWidget);
      expect(bookings.updates, isEmpty);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);

      await type(tester, field(adminLabelName), 'Other Person');
      expect(find.text('Enter the name.'), findsNothing);
      expect(find.text(adminCorrectFields), findsNothing);
    });

    testWidgets('no connection: said so, and the typed values stay', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');
      bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.noConnection,
      );

      await tapSave(tester);

      expect(find.text('Not saved. No connection.'), findsOneWidget);
      expect(textOf(tester, notesField), 'A note.');
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(saveEnabled(tester), true);

      await tester.tap(find.byTooltip(adminDismissNotice));
      await settle(tester);
      expect(find.text('Not saved. No connection.'), findsNothing);
    });

    testWidgets('no answer in time is not "Not saved"', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');
      bookings.updateError = const AdminBookingSaveNoAnswer();

      await tapSave(tester);

      expect(find.textContaining('No answer from the server.'), findsOneWidget);
      expect(find.textContaining('Not saved'), findsNothing);
    });

    testWidgets('an unknown field of the stored document is named', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');
      bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.unknownFields,
        fields: ['zzTest'],
      );

      await tapSave(tester);

      expect(
        find.text(
          'Not saved. This booking has a field the app does not know: '
          'zzTest. Remove it in the Firebase console.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the total', () {
    testWidgets('another car: both totals, the text about today\'s prices, '
        'two choices with nothing selected, and Save disabled', (tester) async {
      await openEdit(tester);

      await choose(tester, prius, cruiserHidden);

      expect(find.text('Stored total: 5 days · \$225'), findsOneWidget);
      expect(
        find.text('New total: 5 days × (\$120 car + \$0 extras) = \$600'),
        findsOneWidget,
      );
      expect(find.text(adminNewTotalUsesTodaysPrices), findsOneWidget);
      expect(find.text('Keep the stored total (\$225)'), findsOneWidget);
      expect(find.text('Use the new total (\$600)'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      expect(find.text('Choose which total to save.'), findsOneWidget);
      expect(saveEnabled(tester), false);
    });

    testWidgets('"Keep the stored total": the car is sent, the total is not', (
      tester,
    ) async {
      await openEdit(tester);
      await choose(tester, prius, cruiserHidden);

      await tester.tap(find.text('Keep the stored total (\$225)'));
      await settle(tester);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('Choose which total to save.'), findsNothing);
      expect(saveEnabled(tester), true);
      await tapSave(tester);

      expect(bookings.updates.single.changes.values, {'carId': 'car-2'});
    });

    testWidgets('"Use the new total": the car and the new total are sent', (
      tester,
    ) async {
      await openEdit(tester);
      await choose(tester, prius, cruiserHidden);

      await tester.tap(find.text('Use the new total (\$600)'));
      await settle(tester);
      await tapSave(tester);

      expect(bookings.updates.single.changes.values, {
        'carId': 'car-2',
        'totalPrice': 600.0,
      });
    });

    testWidgets('an extra: the new total counts it per day', (tester) async {
      await openEdit(tester);

      await tester.tap(find.text('Child seat · \$4 per day'));
      await settle(tester);

      expect(
        find.text('New total: 5 days × (\$45 car + \$4 extras) = \$245'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), false);
    });

    testWidgets('prices that cannot be loaded: only "Keep the stored '
        'total", with the reason', (tester) async {
      await openEdit(tester, withPrices: false);

      await choose(tester, prius, cruiserHidden);

      expect(find.text(adminNewTotalNoPrices), findsOneWidget);
      expect(find.text('Keep the stored total (\$225)'), findsOneWidget);
      expect(find.textContaining('Use the new total'), findsNothing);
      expect(saveEnabled(tester), false);

      await tester.tap(find.text('Keep the stored total (\$225)'));
      await settle(tester);
      expect(saveEnabled(tester), true);
    });

    testWidgets('a text change only: no choice and no new total', (
      tester,
    ) async {
      await openEdit(tester);

      await type(tester, notesField, 'A note.');

      expect(find.text(adminTotalStays), findsOneWidget);
      expect(find.textContaining('Keep the stored total'), findsNothing);
      expect(saveEnabled(tester), true);
    });
  });

  group('changed elsewhere', () {
    testWidgets('before saving: a banner names the part; "Keep editing" '
        'hides it and keeps what was typed', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'My note.');

      bookings.emitBookingToAll(
        rawBooking('b1', changes: {'notes': 'Their note.'}),
      );
      await settle(tester);

      const banner =
          'This booking was changed elsewhere (notes). '
          'Saving will be refused.';
      expect(find.text(banner), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, adminKeepEditing));
      await settle(tester);

      expect(find.text(banner), findsNothing);
      expect(textOf(tester, notesField), 'My note.');
    });

    testWidgets('before saving: "Load the current booking" drops the edits; '
        'the fields show the stored values with NEW controllers and the '
        'old ones are disposed', (tester) async {
      await openEdit(tester);
      await type(tester, field(adminLabelName), 'My Name');
      await type(tester, notesField, 'My note.');
      final oldName = tester
          .widget<TextField>(field(adminLabelName))
          .controller!;
      final oldNotes = tester.widget<TextField>(notesField).controller!;

      bookings.emitBookingToAll(
        rawBooking(
          'b1',
          fullName: 'Their Name',
          changes: {'notes': 'Their note.'},
        ),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, adminLoadCurrent));
      await settle(tester);

      expect(textOf(tester, field(adminLabelName)), 'Their Name');
      expect(textOf(tester, notesField), 'Their note.');
      expect(find.textContaining('changed elsewhere'), findsNothing);
      expect(saveEnabled(tester), false);

      final newName = tester
          .widget<TextField>(field(adminLabelName))
          .controller!;
      expect(identical(newName, oldName), false);
      // A disposed controller refuses to be used.
      expect(() => oldName.addListener(() {}), throwsFlutterError);
      expect(() => oldNotes.addListener(() {}), throwsFlutterError);

      // The new fields work: typing reaches the draft.
      await type(tester, notesField, 'A new note.');
      expect(saveEnabled(tester), true);
    });

    testWidgets('without unsaved changes the form simply follows the stored '
        'booking, also with new controllers', (tester) async {
      await openEdit(tester);
      final old = tester.widget<TextField>(field(adminLabelName)).controller!;

      bookings.emitBookingToAll(rawBooking('b1', fullName: 'Their Name'));
      await settle(tester);

      expect(textOf(tester, field(adminLabelName)), 'Their Name');
      expect(() => old.addListener(() {}), throwsFlutterError);
      expect(find.textContaining('changed elsewhere'), findsNothing);
    });

    testWidgets('an answer with the same values keeps the controllers', (
      tester,
    ) async {
      await openEdit(tester);
      final old = tester.widget<TextField>(field(adminLabelName)).controller!;

      bookings.emitBookingToAll(rawBooking('b1', status: 'confirmed'));
      await settle(tester);

      expect(
        identical(
          tester.widget<TextField>(field(adminLabelName)).controller,
          old,
        ),
        true,
      );
    });

    testWidgets('after a refused save: the conflict message with both '
        'buttons; "Keep editing" keeps the typed values', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'My note.');
      bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.conflict,
        fields: ['notes'],
      );

      await tapSave(tester);

      const message =
          'This booking was changed elsewhere (notes). '
          'Your changes were not saved.';
      expect(find.text(message), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, adminKeepEditing));
      await settle(tester);

      expect(find.text(message), findsNothing);
      expect(textOf(tester, notesField), 'My note.');
    });

    testWidgets('after a refused save: "Load the current booking" shows the '
        'stored values', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'My note.');
      bookings.updateError = const AdminBookingSaveException(
        AdminBookingSaveFailure.conflict,
        fields: ['notes'],
      );
      await tapSave(tester);
      bookings.emitBookingToAll(
        rawBooking('b1', changes: {'notes': 'Their note.'}),
      );
      await settle(tester);

      // Only the message after the save is shown, not the banner as well.
      expect(
        find.widgetWithText(FilledButton, adminLoadCurrent),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, adminLoadCurrent));
      await settle(tester);

      expect(textOf(tester, notesField), 'Their note.');
      expect(find.textContaining('changed elsewhere'), findsNothing);
    });
  });

  group('leaving the form', () {
    testWidgets('Back without changes returns to the detail, no question', (
      tester,
    ) async {
      await openEdit(tester);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/b1');
    });

    testWidgets('Back with unsaved changes asks; "Keep editing" stays with '
        'the typed values, "Discard" leaves and nothing is sent', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, adminKeepEditing));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(textOf(tester, notesField), 'A note.');

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, adminDiscard));
      await settle(tester);

      expect(find.byType(AdminBookingEditScreen), findsNothing);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/b1');
      expect(bookings.updates, isEmpty);
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('the system Back with unsaved changes asks too', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text(adminDiscardTitle), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
    });

    testWidgets('the system Back without changes returns to the detail', (
      tester,
    ) async {
      await openEdit(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/b1');
    });

    testWidgets('while saving, Back is blocked: no question and no leaving', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');
      bookings.updatePending = Completer<void>();
      await tapSave(tester);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(address(tester), editAddress);

      bookings.updatePending!.complete();
      await settle(tester);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
    });

    testWidgets('leaving disposes the controllers and closes the listener '
        'of the form', (tester) async {
      await openEdit(tester);
      final old = tester.widget<TextField>(field(adminLabelName)).controller!;
      // The detail underneath and the form both listen.
      expect(bookings.activeBookingListeners, 2);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(() => old.addListener(() {}), throwsFlutterError);
      expect(bookings.activeBookingListeners, 1);
    });
  });

  group('the route', () {
    testWidgets('the Edit icon of the detail opens the form', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/bookings/b1');
      bookings.emitBookingToAll(rawBooking('b1'));
      await settle(tester);

      await tester.tap(find.byTooltip(adminEditTooltip));
      await settle(tester);
      bookings.emitBookingToAll(rawBooking('b1'));
      await settle(tester);

      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(address(tester), editAddress);
      expect(textOf(tester, field(adminLabelName)), 'Test Person');
    });

    testWidgets('its address opened directly by an admin shows it; the list '
        'and the detail underneath start their listeners too', (tester) async {
      await pumpApp(tester);
      await open(tester, editAddress);

      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The accepted extra cost of a direct link.
      expect(bookings.limits, [50]);
      expect(bookings.watchedBookingIds, ['b1', 'b1']);
    });

    testWidgets('signed out: the login page and nothing is asked for; after '
        'the sign-in the admin lands on the form', (tester) async {
      await pumpApp(tester, session: AdminSession.signedOut);
      await open(tester, editAddress);

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsNothing);
      expect(bookings.watchedBookingIds, isEmpty);
      expect(bookings.carReads, 0);

      auth.report(AdminSession.admin);
      await settle(tester);

      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(address(tester), editAddress);
    });

    testWidgets('signed in without the claim: never the form', (tester) async {
      await pumpApp(tester, session: AdminSession.noAccess);
      await open(tester, editAddress);

      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsNothing);
      expect(bookings.watchedBookingIds, isEmpty);
    });

    testWidgets('a session that ends while the form is open closes it; the '
        'typed values are gone with it', (tester) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');

      auth.report(AdminSession.noAccess);
      await settle(tester);

      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsNothing);
      expect(find.text('A note.'), findsNothing);
      expect(bookings.activeBookingListeners, 0);
    });

    testWidgets('a booking that does not exist: said so, with a way back', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, editAddress);
      bookings.emitBookingToAll(null);
      await settle(tester);

      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(find.byType(AdminBookingEditForm), findsNothing);

      await tester.tap(find.text(adminBackToBookings));
      await settle(tester);
      expect(address(tester), '/admin');
    });

    testWidgets('a booking that cannot be read has no form', (tester) async {
      await pumpApp(tester);
      await open(tester, editAddress);
      bookings.emitBookingToAll(
        rawBooking('b1', changes: {'status': 'approved'}),
      );
      await settle(tester);

      expect(find.text(adminBookingUnreadable), findsOneWidget);
      expect(find.byType(AdminBookingEditForm), findsNothing);
    });

    testWidgets('a booking deleted while the form is open: "does not exist"', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, notesField, 'A note.');

      bookings.emitBookingToAll(null);
      await settle(tester);

      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(find.byType(AdminBookingEditForm), findsNothing);
    });

    testWidgets('an address below the form is the admin "not found" page', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '$editAddress/more');

      expect(find.byType(AdminNotFoundScreen), findsOneWidget);
      expect(find.byType(AdminBookingEditScreen), findsNothing);
    });
  });
}
