import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
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

const newAddress = '/admin/bookings/new';
const prius = 'Toyota Prius, 2019';
const editTextOfNoTotal =
    'The new total cannot be calculated. Keep the stored total.';

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

AdminBookingNewState formState(WidgetTester tester) =>
    containerOf(tester).read(adminBookingNewProvider);

Future<void> pumpApp(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  Size size = const Size(800, 3200),
  bool withPrices = true,
  Object? carsError,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  auth = FakeAdminAuthRepository(initial: session);
  bookings = FakeAdminBookingsRepository()
    ..cars = [testCar(), testCar(id: 'car-2', active: false)]
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
        pickupLocationsProvider.overrideWith((ref) => Stream.value(places)),
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

Future<void> openNew(
  WidgetTester tester, {
  Size size = const Size(800, 3200),
  bool withPrices = true,
  Object? carsError,
}) async {
  await pumpApp(
    tester,
    size: size,
    withPrices: withPrices,
    carsError: carsError,
  );
  await open(tester, newAddress);
}

Finder field(String label) => find.widgetWithText(TextField, label);

String textOf(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

Finder get saveButton => find.widgetWithText(FilledButton, adminSave);
Finder get checkButton => find.widgetWithText(FilledButton, adminCheckAgain);

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

/// Types the three texts of the customer. Every value is made up.
Future<void> typeCustomer(WidgetTester tester) async {
  await type(tester, field(adminLabelName), 'Create Test One');
  await type(tester, field(adminLabelPhone), '+995 555 00-00-01');
  await type(tester, field(adminLabelEmail), 'one@example.com');
}

/// Chooses the car, the dates and the places, as the dropdowns and the
/// pickers would: 5 days (9 to 14 Oct 2026, 16:00) with the car of 45.
Future<void> chooseRest(WidgetTester tester, {String carId = 'car-1'}) async {
  final notifier = containerOf(tester).read(adminBookingNewProvider.notifier);
  final draft = formState(tester).draft;
  notifier.setDraft(
    draft.copyWith(
      fields: draft.fields.copyWith(
        carId: carId,
        input: draft.fields.input.copyWith(
          pickup: TbilisiDateTime(2026, 10, 9, 16, 0),
          dropoff: TbilisiDateTime(2026, 10, 14, 16, 0),
          pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
          dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
        ),
      ),
    ),
  );
  await settle(tester);
}

Future<void> fill(WidgetTester tester) async {
  await typeCustomer(tester);
  await chooseRest(tester);
}

void main() {
  group('the empty form', () {
    testWidgets('title, Confirmed, English, nothing chosen, no total yet, '
        'Save disabled', (tester) async {
      await openNew(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(find.text(adminNewBookingTitle), findsOneWidget);
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('English (en)'), findsWidgets);
      expect(textOf(tester, field(adminLabelName)), '');
      expect(textOf(tester, field(adminLabelPhone)), '');
      expect(textOf(tester, field(adminLabelEmail)), '');
      expect(find.text(adminNewTotalIncomplete), findsOneWidget);
      expect(find.text(adminTotalUsesTodaysPrices), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      expect(saveEnabled(tester), false);
      expect(checkButton, findsNothing);
      // A new booking has no stored total and no "not found" car.
      expect(find.textContaining('stored total'), findsNothing);
      expect(find.textContaining('(not found)'), findsNothing);
      expect(find.text(adminPickupInPastNote), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the text fields do not teach the keyboard, as in the edit '
        'form', (tester) async {
      await openNew(tester);

      final fields = tester.widgetList<TextField>(
        find.descendant(
          of: find.byType(AdminBookingNewForm),
          matching: find.byType(TextField),
        ),
      );
      // Name, phone, e-mail, notes.
      expect(fields, hasLength(4));
      for (final field in fields) {
        expect(field.autocorrect, false);
        expect(field.enableSuggestions, false);
        expect(field.autofillHints, isNull);
      }
    });

    testWidgets('the car is chosen in its list; a hidden car is marked', (
      tester,
    ) async {
      await openNew(tester);

      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      expect(find.text('Toyota Prius, 2019 (hidden)'), findsWidgets);
      await tester.tap(find.text(prius).last);
      await settle(tester);

      expect(formState(tester).draft.fields.carId, 'car-1');
      expect(saveEnabled(tester), true);
    });

    testWidgets('a date is chosen with the pickers; today is offered, and a '
        'pickup in the past gets the note', (tester) async {
      await openNew(tester);

      // The calendar icon of the pickup field.
      await tester.tap(find.byIcon(Icons.event).first);
      await settle(tester);
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2021, 1, 1));
      expect(dialog.initialDate, DateTime(2026, 10, 9));
      await tester.tap(find.text('1'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(
        formState(tester).draft.fields.input.pickup,
        TbilisiDateTime(2026, 10, 1, 16, 0),
      );
      expect(find.text('1 Oct 2026 16:00'), findsOneWidget);
      expect(find.text(adminPickupInPastNote), findsOneWidget);
    });
  });

  group('the status and "no e-mail"', () {
    testWidgets('the status is chosen in its list and stored', (tester) async {
      await openNew(tester);
      await fill(tester);

      await tester.tap(find.byType(DropdownButton<BookingStatus>));
      await settle(tester);
      for (final word in ['New', 'Pending', 'Confirmed', 'Cancelled']) {
        expect(find.text(word), findsWidgets, reason: word);
      }
      await tester.tap(find.text('Pending').last);
      await settle(tester);
      await tapSave(tester);

      expect(bookings.creates.single.booking.status, BookingStatus.pending);
    });

    testWidgets('unchanged, the status is Confirmed', (tester) async {
      await openNew(tester);
      await fill(tester);
      await tapSave(tester);

      expect(bookings.creates.single.booking.status, BookingStatus.confirmed);
    });

    testWidgets('the switch greys the e-mail field out, keeps what was '
        'typed, shows no e-mail error, and stores the placeholder', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test Two');
      await type(tester, field(adminLabelPhone), '+995555000002');
      await type(tester, field(adminLabelEmail), 'half typed');
      await chooseRest(tester);

      await tester.tap(find.text(adminNoEmailSwitch));
      await settle(tester);

      expect(tester.widget<TextField>(field(adminLabelEmail)).enabled, false);
      expect(textOf(tester, field(adminLabelEmail)), 'half typed');

      await tapSave(tester);
      expect(find.text('This e-mail address is not valid.'), findsNothing);
      expect(
        bookings.creates.single.booking.customer.email,
        noEmailPlaceholder,
      );
    });

    testWidgets('switched off again, the field is back with its text and '
        'is checked', (tester) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test Two');
      await type(tester, field(adminLabelPhone), '+995555000002');
      await type(tester, field(adminLabelEmail), 'half typed');
      await chooseRest(tester);
      await tester.tap(find.text(adminNoEmailSwitch));
      await settle(tester);
      await tester.tap(find.text(adminNoEmailSwitch));
      await settle(tester);

      expect(tester.widget<TextField>(field(adminLabelEmail)).enabled, true);
      expect(textOf(tester, field(adminLabelEmail)), 'half typed');
      await tapSave(tester);
      expect(find.text('This e-mail address is not valid.'), findsOneWidget);
      expect(bookings.creates, isEmpty);
    });
  });

  group('the total', () {
    testWidgets('with a car and the dates: the total line and the note about '
        'today\'s prices; an extra is counted per day', (tester) async {
      await openNew(tester);
      await fill(tester);

      expect(
        find.text('Total: 5 days × (\$45 car + \$0 extras) = \$225'),
        findsOneWidget,
      );
      expect(find.text(adminTotalUsesTodaysPrices), findsOneWidget);

      await tester.tap(find.text('Child seat · \$4 per day'));
      await settle(tester);
      expect(
        find.text('Total: 5 days × (\$45 car + \$4 extras) = \$245'),
        findsOneWidget,
      );
    });

    testWidgets('prices not loaded: the reason in the total card, Save '
        'disabled, and never the edit form\'s text', (tester) async {
      await openNew(tester, withPrices: false);
      await fill(tester);

      expect(find.text(adminNewTotalNoPricesLoaded), findsOneWidget);
      expect(find.text(editTextOfNoTotal), findsNothing);
      expect(find.textContaining('stored total'), findsNothing);
      expect(saveEnabled(tester), false);
      expect(bookings.creates, isEmpty);
    });

    testWidgets('cars not loaded: said so, with "Try again" that loads them', (
      tester,
    ) async {
      await openNew(
        tester,
        carsError: const AdminBookingsException(AdminBookingsFailure.other),
      );

      expect(find.text(adminCarsLoadFailed), findsOneWidget);
      await typeCustomer(tester);
      await tapSave(tester);
      // No car can be chosen; nothing is sent and the edit text is absent.
      expect(bookings.creates, isEmpty);
      expect(find.text(editTextOfNoTotal), findsNothing);

      bookings.carsError = null;
      await tester.tap(find.widgetWithText(TextButton, adminTryAgain));
      await settle(tester);

      expect(find.text(adminCarsLoadFailed), findsNothing);
      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      expect(find.text(prius), findsWidgets);
    });
  });

  group('saving', () {
    testWidgets('the booking is created once, under the ID of the form; '
        'then the detail of the new booking opens and says "Saved"', (
      tester,
    ) async {
      await openNew(tester);
      await fill(tester);
      await type(
        tester,
        find.byWidgetPredicate((w) => w is TextField && w.maxLines == 8),
        ' A made-up note. ',
      );

      await tapSave(tester);

      final create = bookings.creates.single;
      expect(create.id, 'new-1');
      expect(create.booking.createdBy, 'admin');
      expect(create.booking.customer.fullName, 'Create Test One');
      expect(create.booking.customer.phone, '+995555000001');
      expect(create.booking.customer.email, 'one@example.com');
      expect(create.booking.notes, 'A made-up note.');
      expect(create.booking.totalPrice, 225);
      expect(create.booking.pickup, DateTime.utc(2026, 10, 9, 12));

      expect(find.byType(AdminBookingNewScreen), findsNothing);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/new-1');

      bookings.emitBookingToAll(
        rawBooking('new-1', fullName: 'Create Test One'),
      );
      await settle(tester);
      expect(find.text('Create Test One'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('errors appear after Save, with a line above the button; '
        'nothing is sent; the edit form\'s total text never appears', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test One');
      expect(find.text('Enter the phone number.'), findsNothing);

      await tapSave(tester);

      expect(find.text('Enter the phone number.'), findsOneWidget);
      expect(find.text('Enter the e-mail address.'), findsOneWidget);
      expect(find.text('Choose a car.'), findsOneWidget);
      expect(find.text('Choose the pickup date and time.'), findsOneWidget);
      expect(find.text(adminCorrectFields), findsOneWidget);
      expect(find.text(editTextOfNoTotal), findsNothing);
      expect(bookings.creates, isEmpty);
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
    });

    testWidgets('"Saving…": the button and the fields are disabled; a second '
        'tap creates nothing more', (tester) async {
      await openNew(tester);
      await fill(tester);
      bookings.createPending = Completer<void>();

      await tapSave(tester);
      expect(find.text(adminSaving), findsOneWidget);
      expect(saveEnabled(tester), false);
      expect(tester.widget<TextField>(field(adminLabelName)).enabled, false);

      await tester.tap(saveButton, warnIfMissed: false);
      await settle(tester);
      expect(bookings.creates, hasLength(1));

      bookings.createPending!.complete();
      await settle(tester);
      expect(bookings.creates, hasLength(1));
      expect(address(tester), '/admin/bookings/new-1');
    });

    testWidgets('no connection: said so, the typed values stay, and the '
        'message can be hidden', (tester) async {
      await openNew(tester);
      await fill(tester);
      bookings.createError = const AdminBookingCreateException(
        AdminBookingCreateFailure.noConnection,
      );

      await tapSave(tester);

      expect(find.text('Not saved. No connection.'), findsOneWidget);
      expect(textOf(tester, field(adminLabelName)), 'Create Test One');
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(saveEnabled(tester), true);

      await tester.tap(find.byTooltip(adminDismissNotice));
      await settle(tester);
      expect(find.text('Not saved. No connection.'), findsNothing);
    });

    testWidgets('the car is gone: said so', (tester) async {
      await openNew(tester);
      await fill(tester);
      bookings.createError = const AdminBookingCreateException(
        AdminBookingCreateFailure.carMissing,
      );

      await tapSave(tester);

      expect(
        find.text('Not saved. This car no longer exists. Choose another car.'),
        findsOneWidget,
      );
    });
  });

  group('no answer from the server', () {
    Future<void> saveWithoutAnswer(
      WidgetTester tester, {
      bool landed = false,
    }) async {
      await openNew(tester);
      await fill(tester);
      bookings
        ..createError = const AdminBookingCreateNoAnswer()
        ..createLandsAnyway = landed;
      await tapSave(tester);
    }

    testWidgets('the message that nothing is created twice; the form is '
        'locked; only "Check again" is offered; the message cannot be '
        'hidden', (tester) async {
      await saveWithoutAnswer(tester);

      expect(
        find.text(
          'No answer from the server. Press "Check again": the booking '
          'will not be created twice.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Not saved'), findsNothing);
      expect(saveButton, findsNothing);
      expect(checkButton, findsOneWidget);
      expect(find.byTooltip(adminDismissNotice), findsNothing);
      expect(tester.widget<TextField>(field(adminLabelName)).enabled, false);
      expect(tester.widget<TextField>(field(adminLabelPhone)).enabled, false);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
    });

    testWidgets('"Check again" when the booking did arrive: nothing is '
        'written twice and its detail opens', (tester) async {
      await saveWithoutAnswer(tester, landed: true);
      bookings.createError = null;

      await tester.tap(checkButton);
      await settle(tester);

      expect(bookings.creates.map((create) => create.id), ['new-1', 'new-1']);
      expect(bookings.existingIds, {'new-1'});
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), '/admin/bookings/new-1');
    });

    testWidgets('"Check again" when it did not arrive: it is created now', (
      tester,
    ) async {
      await saveWithoutAnswer(tester);
      bookings.createError = null;

      await tester.tap(checkButton);
      await settle(tester);

      expect(bookings.existingIds, {'new-1'});
      expect(address(tester), '/admin/bookings/new-1');
    });

    testWidgets('"Checking…" while it runs; still no answer: said so, and '
        'the form stays locked', (tester) async {
      await saveWithoutAnswer(tester);
      bookings.createPending = Completer<void>();

      await tester.tap(checkButton);
      await settle(tester);
      expect(find.text(adminChecking), findsOneWidget);
      expect(tester.widget<FilledButton>(checkButton).onPressed, isNull);

      bookings.createPending!.complete();
      await settle(tester);
      expect(
        find.textContaining('Still no answer from the server.'),
        findsOneWidget,
      );
      expect(checkButton, findsOneWidget);
      expect(saveButton, findsNothing);
      expect(tester.widget<TextField>(field(adminLabelName)).enabled, false);
    });
  });

  group('leaving the form', () {
    testWidgets('Back from the empty form returns to the list, no question', (
      tester,
    ) async {
      await openNew(tester);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(address(tester), '/admin');
    });

    testWidgets('Back with something filled in asks "Discard your '
        'changes?"; "Keep editing" stays, "Discard" leaves', (tester) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test One');

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);
      expect(find.text(adminMayExistText), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, adminKeepEditing));
      await settle(tester);
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(textOf(tester, field(adminLabelName)), 'Create Test One');

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, adminDiscard));
      await settle(tester);

      expect(find.byType(AdminBookingNewScreen), findsNothing);
      expect(address(tester), '/admin');
      expect(bookings.creates, isEmpty);
    });

    testWidgets('the system Back with something filled in asks too', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test One');

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text(adminDiscardTitle), findsOneWidget);
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
    });

    testWidgets('while the booking may already exist, Back uses the '
        'stronger words; "Stay" stays, "Leave" opens the list', (tester) async {
      await openNew(tester);
      await fill(tester);
      bookings.createError = const AdminBookingCreateNoAnswer();
      await tapSave(tester);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.text(adminLeaveTitle), findsOneWidget);
      expect(
        find.text('The booking may already exist. Check the bookings list.'),
        findsOneWidget,
      );
      expect(find.text(adminDiscardTitle), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, adminStay));
      await settle(tester);
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(checkButton, findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(adminLeaveTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, adminLeave));
      await settle(tester);

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(address(tester), '/admin');
    });

    testWidgets('while saving, Back is blocked: no question and no leaving', (
      tester,
    ) async {
      await openNew(tester);
      await fill(tester);
      bookings.createPending = Completer<void>();
      await tapSave(tester);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(address(tester), newAddress);

      bookings.createPending!.complete();
      await settle(tester);
      expect(address(tester), '/admin/bookings/new-1');
    });

    testWidgets('leaving disposes the text controllers', (tester) async {
      await openNew(tester);
      final old = tester.widget<TextField>(field(adminLabelName)).controller!;

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(() => old.addListener(() {}), throwsFlutterError);
    });
  });

  group('a second new booking', () {
    testWidgets('after a save, "New booking" gives an empty form with a NEW '
        'document ID, and its save makes a second, different booking', (
      tester,
    ) async {
      await openNew(tester);
      await fill(tester);
      await tapSave(tester);
      expect(address(tester), '/admin/bookings/new-1');

      // Back to the list, and the button again.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(textOf(tester, field(adminLabelName)), '');
      expect(textOf(tester, field(adminLabelPhone)), '');
      expect(textOf(tester, field(adminLabelEmail)), '');
      expect(find.text(adminNewTotalIncomplete), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(saveEnabled(tester), false);
      final second = formState(tester);
      expect(second.bookingId, 'new-2');
      expect(second.isDirty, false);
      expect(second.createdId, isNull);
      expect(second.notice, isNull);

      await type(tester, field(adminLabelName), 'Create Test Two');
      await type(tester, field(adminLabelPhone), '+995555000002');
      await type(tester, field(adminLabelEmail), 'two@example.com');
      await chooseRest(tester);
      await tapSave(tester);

      expect(bookings.creates.map((create) => create.id), ['new-1', 'new-2']);
      expect(bookings.creates[1].booking.customer.fullName, 'Create Test Two');
      expect(bookings.existingIds, {'new-1', 'new-2'});
      expect(address(tester), '/admin/bookings/new-2');
    });

    testWidgets('a form that was discarded leaves nothing behind either', (
      tester,
    ) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test One');
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, adminDiscard));
      await settle(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      expect(textOf(tester, field(adminLabelName)), '');
      expect(formState(tester).bookingId, 'new-2');
    });

    testWidgets('"Saved" is shown on the detail once: opening that detail '
        'again later shows nothing', (tester) async {
      await openNew(tester);
      await fill(tester);
      await tapSave(tester);
      bookings.emitBookingToAll(rawBooking('new-1'));
      await settle(tester);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await open(tester, '/admin/bookings/new-1');
      bookings.emitBookingToAll(rawBooking('new-1'));
      await settle(tester);

      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
    });
  });

  group('the route', () {
    testWidgets('the "New booking" button of the list opens the form', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(address(tester), newAddress);
    });

    testWidgets('"/admin/bookings/new" is the form, not the detail of a '
        'booking called "new": nothing is asked for such a booking', (
      tester,
    ) async {
      await openNew(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(find.byType(AdminBookingDetailScreen), findsNothing);
      expect(bookings.watchedBookingIds, isEmpty);
      // The list underneath has its listener: the cost of a direct link.
      expect(bookings.limits, [50]);
    });

    testWidgets('"/admin/bookings/new/edit" is the admin "not found" page, '
        'and so is anything else below the form', (tester) async {
      await pumpApp(tester);

      for (final wrong in ['$newAddress/edit', '$newAddress/more']) {
        await open(tester, wrong);
        expect(find.byType(AdminNotFoundScreen), findsOneWidget, reason: wrong);
        expect(find.byType(AdminBookingEditScreen), findsNothing);
        expect(find.byType(AdminBookingNewScreen), findsNothing);
      }
      expect(bookings.watchedBookingIds, isEmpty);
    });

    testWidgets('a real booking next to it is still a detail', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/bookings/newer');

      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(bookings.watchedBookingIds, ['newer']);
    });

    testWidgets('signed out: the login page and no form, no ID; after the '
        'sign-in the admin lands on the form', (tester) async {
      await pumpApp(tester, session: AdminSession.signedOut);
      await open(tester, newAddress);

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminBookingNewScreen), findsNothing);
      expect(bookings.newIds, 0);

      auth.report(AdminSession.admin);
      await settle(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(address(tester), newAddress);
      expect(bookings.newIds, 1);
    });

    testWidgets('signed in without the claim: never the form', (tester) async {
      await pumpApp(tester, session: AdminSession.noAccess);
      await open(tester, newAddress);

      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(find.byType(AdminBookingNewScreen), findsNothing);
      expect(bookings.newIds, 0);
    });

    testWidgets('a session that ends while the form is open closes it; the '
        'typed values are gone', (tester) async {
      await openNew(tester);
      await type(tester, field(adminLabelName), 'Create Test One');

      auth.report(AdminSession.noAccess);
      await settle(tester);

      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(find.text('Create Test One'), findsNothing);
      expect(formState(tester).isDirty, false);
    });

    testWidgets('fits a phone 320 wide, with errors shown', (tester) async {
      await openNew(tester, size: const Size(320, 4200));
      await type(tester, field(adminLabelName), 'Create Test One');
      await tapSave(tester);

      expect(find.text(adminCorrectFields), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
