import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_card.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

/// The clock of the tests; a test moves it to make time "pass".
DateTime now = DateTime.utc(2026, 10, 9, 12);

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport', ka: 'აეროპორტი'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Tbilisi Office'),
  ),
];

/// Shows the detail of the booking [id] for a signed-in admin. All data is
/// made up. With [knownPlaces] null the places cannot be loaded.
Future<void> pumpScreen(
  WidgetTester tester, {
  String id = 'b1',
  Size size = const Size(800, 1600),
  List<PickupLocation>? knownPlaces = places,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => now),
        pickupLocationsProvider.overrideWith(
          (ref) => knownPlaces == null
              ? Stream.error(const FormatException('made up'))
              : Stream.value(knownPlaces),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminBookingDetailScreen(bookingId: id),
      ),
    ),
  );
  await settle(tester);
}

/// pumpAndSettle is not used: a spinner never stops animating.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Long enough for a dialog to open or close.
Future<void> settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> emit(
  WidgetTester tester,
  RawBookingDocument? document, {
  bool fromCache = false,
}) async {
  bookings.emitBooking(document, fromCache: fromCache);
  await settle(tester);
}

Finder changeButton(BookingStatus status) =>
    find.widgetWithText(OutlinedButton, adminChangeTo(status));

/// The word on the status chip.
String chipWord(WidgetTester tester) {
  final chip = tester.widget<AdminStatusChip>(find.byType(AdminStatusChip));
  return adminStatusLabel(chip.status);
}

Future<void> tapChange(WidgetTester tester, BookingStatus status) async {
  await tester.ensureVisible(changeButton(status));
  await tester.tap(changeButton(status));
  await settleDialog(tester);
}

void main() {
  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    auth = FakeAdminAuthRepository(initial: AdminSession.admin);
    bookings = FakeAdminBookingsRepository()
      ..cars = [testCar(), testCar(id: 'hidden-car', active: false)];
    addTearDown(auth.close);
  });

  group('states', () {
    testWidgets('a spinner until the first answer', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AdminStatusChip), findsNothing);
      expect(bookings.watchedBookingIds, ['b1']);
    });

    testWidgets('no such booking: says so, with a way back', (tester) async {
      await pumpScreen(tester);
      await emit(tester, null);

      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, adminBackToBookings),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('an ID of an impossible shape: "does not exist", and '
        'Firestore is not asked', (tester) async {
      await pumpScreen(tester, id: 'a b/c');

      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(bookings.watchedBookingIds, isEmpty);
    });

    testWidgets('a booking that cannot be read: says so; the reason is for '
        'the developer and never holds the customer', (tester) async {
      await pumpScreen(tester);
      await emit(
        tester,
        rawBooking(
          'b1',
          fullName: 'Secret Person',
          changes: {'status': 'approved'},
        ),
      );

      expect(find.text(adminBookingUnreadable), findsOneWidget);
      // Tests run in debug mode, where the reason is shown.
      expect(find.textContaining('approved'), findsOneWidget);
      expect(find.textContaining('Secret Person'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('refused by the rules: no access, with "Try again"', (
      tester,
    ) async {
      await pumpScreen(tester);
      bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await settle(tester);

      expect(find.text(adminBookingNoAccess), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, adminTryAgain));
      await settle(tester);
      expect(bookings.watchedBookingIds, ['b1', 'b1']);
      await emit(tester, rawBooking('b1'));
      expect(find.text('Test Person'), findsOneWidget);
    });

    testWidgets('nothing saved and no connection: "could not load" after 3 '
        'seconds, not "does not exist"', (tester) async {
      await pumpScreen(tester);
      await emit(tester, null, fromCache: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.text(adminBookingLoadError), findsOneWidget);
      expect(find.text(adminBookingMissing), findsNothing);
    });

    testWidgets('a booking deleted while it is open: "does not exist"', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1'));
      expect(find.text('Test Person'), findsOneWidget);

      await emit(tester, null);

      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(find.text('Test Person'), findsNothing);
    });
  });

  group('what is shown', () {
    testWidgets('every stored value, with the dates in Tbilisi time', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(
        tester,
        rawBooking(
          'b1',
          totalPrice: 272.5,
          changes: {
            'customer': {
              'fullName': 'Test Person',
              'phone': '+995555000000',
              'whatsapp': true,
              'telegram': true,
              'email': 'person@example.com',
            },
            'language': 'ka',
          },
        ),
      );

      expect(find.text(adminBookingTitle), findsOneWidget);
      expect(find.text('Tbilisi time (GMT+4)'), findsOneWidget);
      expect(find.text('Test Person'), findsOneWidget);
      expect(find.text('+995555000000'), findsOneWidget);
      expect(find.text('WhatsApp, Telegram'), findsOneWidget);
      expect(find.text('person@example.com'), findsOneWidget);
      expect(find.text('Georgian (ka)'), findsOneWidget);
      expect(find.text('Toyota Prius, 2019'), findsOneWidget);
      // Stored 14:00 and 16:00 UTC; shown as 18:00 and 20:00 in Tbilisi.
      expect(find.text('10 Jan 2026 18:00'), findsOneWidget);
      expect(find.text('15 Jan 2026 20:00'), findsOneWidget);
      // The English names of the places, from settings.
      expect(find.text('Tbilisi Airport'), findsOneWidget);
      expect(find.text('Tbilisi Office'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text(adminLabelNotes), findsNothing);
      expect(find.text('5 days · \$272.50'), findsOneWidget);
      expect(find.text('Received 9 Oct 2026 17:34'), findsOneWidget);
      expect(find.text('Booking ID: b1'), findsOneWidget);
      expect(find.textContaining('Created by'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the phone, the e-mail and the ID can be selected', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1'));

      for (final text in [
        '+995555000000',
        'person@example.com',
        'Booking ID: b1',
      ]) {
        expect(
          find.widgetWithText(SelectableText, text),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('a customer without e-mail: "No e-mail" instead of the '
        'stored placeholder, which is never shown', (tester) async {
      await pumpScreen(tester);
      await emit(
        tester,
        rawBooking(
          'b1',
          changes: {
            'customer': {
              'fullName': 'Test Person',
              'phone': '+995555000000',
              'whatsapp': false,
              'telegram': false,
              'email': noEmailPlaceholder,
            },
          },
        ),
      );

      expect(find.text(adminNoEmail), findsOneWidget);
      expect(find.text('No e-mail'), findsOneWidget);
      expect(find.textContaining('no-email.invalid'), findsNothing);
      // It is words, not an address to select and copy.
      expect(find.widgetWithText(SelectableText, adminNoEmail), findsNothing);
      // The phone stays as it is.
      expect(
        find.widgetWithText(SelectableText, '+995555000000'),
        findsOneWidget,
      );
    });

    testWidgets('no messenger line when neither is chosen', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1'));

      expect(find.textContaining('WhatsApp'), findsNothing);
      expect(find.textContaining('Telegram'), findsNothing);
      expect(find.text('English (en)'), findsOneWidget);
    });

    testWidgets('another place, extras, notes and "created by"', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(
        tester,
        rawBooking(
          'b1',
          changes: {
            'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
            'extras': ['boosterSeat', 'snowChains'],
            'notes': 'A made-up note.',
            'createdBy': 'Made-up Staff',
            'language': 'ru',
          },
        ),
      );

      expect(find.text('Made-up Street 1'), findsOneWidget);
      expect(find.text('Tbilisi Office'), findsOneWidget);
      // In the fixed order of the extras, not the stored one.
      final chains = tester.getTopLeft(find.text('Snow chains')).dy;
      final booster = tester.getTopLeft(find.text('Booster seat')).dy;
      expect(chains, lessThan(booster));
      expect(find.text('None'), findsNothing);
      expect(find.text('A made-up note.'), findsOneWidget);
      expect(find.text('Created by Made-up Staff'), findsOneWidget);
      expect(find.text('Russian (ru)'), findsOneWidget);
    });

    testWidgets('a place that is not in settings any more, or settings that '
        'cannot be loaded: a neutral text, never an empty line', (
      tester,
    ) async {
      await pumpScreen(tester, knownPlaces: null);
      await emit(tester, rawBooking('b1'));

      expect(find.text(adminUnknownPlace), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('more than 7 days: the total is marked as an estimate', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(
        tester,
        rawBooking(
          'b1',
          dropoff: DateTime.utc(2026, 1, 20, 14),
          totalPrice: 450,
        ),
      );

      expect(find.text('10 days · \$450 · estimate'), findsOneWidget);
    });

    testWidgets('a hidden car is marked and a missing car says so', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', carId: 'hidden-car'));
      expect(find.text('Toyota Prius, 2019 (hidden)'), findsOneWidget);

      await emit(tester, rawBooking('b1', carId: 'gone-car'));
      expect(find.text('Car not found'), findsOneWidget);
    });

    testWidgets('fits a narrow phone', (tester) async {
      await pumpScreen(tester, size: const Size(320, 1800));
      await emit(
        tester,
        rawBooking(
          'b1',
          fullName: 'A Very Long Made-up Name Of A Test Person',
          status: 'confirmed',
          changes: {
            'notes':
                'A made-up note that is long enough to need more '
                'than one line on a narrow phone.',
          },
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the offline note', () {
    testWidgets('appears after 3 seconds of saved data; the choices stay '
        'enabled; an answer of the server removes it', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1'), fromCache: true);
      expect(find.text(adminOfflineNote), findsNothing);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.text(adminOfflineNote), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(changeButton(BookingStatus.pending))
            .onPressed,
        isNotNull,
      );

      await emit(tester, rawBooking('b1'));
      expect(find.text(adminOfflineNote), findsNothing);
    });
  });

  group('the status', () {
    for (final status in BookingStatus.values) {
      testWidgets('${status.name}: the chip of the list, and a button for '
          'each other status', (tester) async {
        await pumpScreen(tester);
        await emit(tester, rawBooking('b1', status: status.storedName));

        expect(find.byType(AdminStatusChip), findsOneWidget);
        expect(chipWord(tester), adminStatusLabel(status));
        for (final other in BookingStatus.values) {
          expect(
            changeButton(other),
            other == status ? findsNothing : findsOneWidget,
            reason: other.name,
          );
        }
      });
    }

    testWidgets('new to pending: no question; "Saving…" with the buttons '
        'disabled, then "Saved"; the chip follows the live read', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangePending = Completer<void>();

      await tapChange(tester, BookingStatus.pending);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.statusChanges, [
        (id: 'b1', status: BookingStatus.pending),
      ]);
      expect(find.text(adminSaving), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
      // Not "Pending" yet: the server has not answered.
      expect(chipWord(tester), 'New');

      bookings.statusChangePending!.complete();
      await settle(tester);
      expect(find.text(adminSaving), findsNothing);
      expect(find.text('Saved'), findsOneWidget);
      expect(chipWord(tester), 'New');

      await emit(tester, rawBooking('b1', status: 'pending'));
      expect(chipWord(tester), 'Pending');
      expect(find.text('Saved'), findsOneWidget);
      expect(changeButton(BookingStatus.pending), findsNothing);
      expect(changeButton(BookingStatus.newBooking), findsOneWidget);
    });

    testWidgets('a tap on a disabled button during "Saving…" writes nothing', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangePending = Completer<void>();
      await tapChange(tester, BookingStatus.pending);

      await tester.tap(changeButton(BookingStatus.confirmed));
      await tester.tap(changeButton(BookingStatus.pending));
      await settle(tester);

      expect(bookings.statusChanges, hasLength(1));

      bookings.statusChangePending!.complete();
      await settle(tester);
    });

    testWidgets('to cancelled: asks first; "Keep" writes nothing', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));

      await tapChange(tester, BookingStatus.cancelled);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(adminConfirmTitle), findsOneWidget);
      expect(
        find.text('The status changes from "New" to "Cancelled".'),
        findsOneWidget,
      );
      expect(bookings.statusChanges, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, adminConfirmNo));
      await settleDialog(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.statusChanges, isEmpty);
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('to cancelled: "Change" writes', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'pending'));

      await tapChange(tester, BookingStatus.cancelled);
      await tester.tap(find.widgetWithText(FilledButton, adminConfirmYes));
      await settleDialog(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.statusChanges, [
        (id: 'b1', status: BookingStatus.cancelled),
      ]);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('closing the question another way writes nothing', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      await tapChange(tester, BookingStatus.cancelled);

      // A tap beside the dialog.
      await tester.tapAt(const Offset(5, 5));
      await settleDialog(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.statusChanges, isEmpty);
    });

    testWidgets('away from confirmed: asks first', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'confirmed'));

      await tapChange(tester, BookingStatus.pending);

      expect(
        find.text('The status changes from "Confirmed" to "Pending".'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, adminConfirmYes));
      await settleDialog(tester);
      expect(bookings.statusChanges, [
        (id: 'b1', status: BookingStatus.pending),
      ]);
    });

    testWidgets('new to confirmed and cancelled to new: no question', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      await tapChange(tester, BookingStatus.confirmed);
      expect(find.byType(AlertDialog), findsNothing);

      await emit(tester, rawBooking('b1', status: 'cancelled'));
      await tapChange(tester, BookingStatus.newBooking);
      expect(find.byType(AlertDialog), findsNothing);

      expect(bookings.statusChanges.map((change) => change.status), [
        BookingStatus.confirmed,
        BookingStatus.newBooking,
      ]);
    });

    testWidgets('the question is dark text on white', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      await tapChange(tester, BookingStatus.cancelled);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, Colors.white);
      final text = tester.renderObject<RenderParagraph>(
        find.text(adminConfirmTitle),
      );
      expect(text.text.style!.color!.computeLuminance(), lessThan(0.3));

      await tester.tap(find.widgetWithText(TextButton, adminConfirmNo));
      await settleDialog(tester);
    });

    const texts = {
      AdminStatusChangeFailure.noConnection: 'Not saved. No connection.',
      AdminStatusChangeFailure.refused: 'Not saved. The change was refused.',
      AdminStatusChangeFailure.bookingMissing:
          'Not saved. This booking no longer exists.',
      AdminStatusChangeFailure.unknown: 'Not saved. Please try again.',
    };
    for (final entry in texts.entries) {
      testWidgets('${entry.key.name}: "${entry.value}", the chip stays and '
          'the buttons come back', (tester) async {
        await pumpScreen(tester);
        await emit(tester, rawBooking('b1', status: 'new'));
        bookings.statusChangeError = AdminStatusChangeException(entry.key);

        await tapChange(tester, BookingStatus.confirmed);

        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(find.text(adminSaving), findsNothing);
        expect(chipWord(tester), 'New');
        expect(
          tester
              .widget<OutlinedButton>(changeButton(BookingStatus.confirmed))
              .onPressed,
          isNotNull,
        );
      });
    }

    testWidgets('no answer in time: not "Not saved", and the chip shows '
        'what the live read says', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangeError = const AdminStatusChangeNoAnswer();

      await tapChange(tester, BookingStatus.confirmed);

      expect(
        find.text(
          'No answer from the server. The status shown is the current one.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Not saved'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(chipWord(tester), 'New');

      // It did arrive after all.
      await emit(tester, rawBooking('b1', status: 'confirmed'));
      expect(chipWord(tester), 'Confirmed');
    });

    testWidgets('a field the rules do not know: the message names it and '
        'says what to do, instead of a bare "refused"', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.unknownFields,
        fields: ['zzTest'],
      );

      await tapChange(tester, BookingStatus.confirmed);

      expect(
        find.text(
          'Not saved. This booking has a field the app does not know: '
          'zzTest. Remove it in the Firebase console.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('refused'), findsNothing);
      expect(chipWord(tester), 'New');
    });

    testWidgets('no creation date: the message says so', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.noCreatedAt,
      );

      await tapChange(tester, BookingStatus.confirmed);

      expect(
        find.text(
          'Not saved. This booking has no creation date and cannot be '
          'changed from the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a stored value in a form the rules refuse: one sentence '
        'names the part, instead of a bare "refused"', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.storedFormat,
        fields: ['phoneStoredFormat'],
      );

      await tapChange(tester, BookingStatus.confirmed);

      expect(
        find.text(
          'Not saved. The phone number is stored in a format the app does '
          'not accept. Edit it to correct it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('refused'), findsNothing);
      expect(chipWord(tester), 'New');
    });

    testWidgets('the message can be hidden', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      await tapChange(tester, BookingStatus.pending);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byTooltip(adminDismissNotice));
      await settle(tester);

      expect(find.text('Saved'), findsNothing);
      expect(find.text('Test Person'), findsOneWidget);
    });

    testWidgets('deleted meanwhile: the change says "no longer exists" and '
        'the page then says the booking does not exist', (tester) async {
      await pumpScreen(tester);
      await emit(tester, rawBooking('b1', status: 'new'));
      bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.bookingMissing,
      );

      await tapChange(tester, BookingStatus.confirmed);
      await emit(tester, null);

      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(
        find.text('Not saved. This booking no longer exists.'),
        findsOneWidget,
      );
    });
  });

  group('the Edit icon', () {
    for (final status in BookingStatus.values) {
      testWidgets('is shown for a booking in the status ${status.name}', (
        tester,
      ) async {
        await pumpScreen(tester);
        await emit(tester, rawBooking('b1', status: status.storedName));

        expect(find.byTooltip(adminEditTooltip), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
      });
    }

    testWidgets('is not shown while loading, for a missing booking, for an '
        'unreadable one, or after a failure', (tester) async {
      await pumpScreen(tester);
      expect(find.byTooltip(adminEditTooltip), findsNothing);

      await emit(tester, rawBooking('b1', changes: {'status': 'approved'}));
      expect(find.byTooltip(adminEditTooltip), findsNothing);

      await emit(tester, null);
      expect(find.byTooltip(adminEditTooltip), findsNothing);

      bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.other),
      );
      await settle(tester);
      expect(find.byTooltip(adminEditTooltip), findsNothing);
    });

    testWidgets('fits the app bar of a phone 320 wide', (tester) async {
      await pumpScreen(tester, size: const Size(320, 1800));
      await emit(tester, rawBooking('b1', status: 'confirmed'));

      expect(find.byTooltip(adminEditTooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the texts after a change: one "Saved", seven "Not saved", and "no '
      'answer" is neither', () {
    final all = {
      for (final notice in AdminStatusChangeNotice.values)
        notice: adminStatusNoticeText(notice),
    };

    expect(
      all.values.toSet(),
      hasLength(AdminStatusChangeNotice.values.length),
    );
    expect(all[AdminStatusChangeNotice.saved], 'Saved');
    expect(
      all.values.where((text) => text.startsWith('Not saved.')),
      hasLength(7),
    );
    expect(all[AdminStatusChangeNotice.noAnswer], isNot(contains('Not saved')));
  });
}
