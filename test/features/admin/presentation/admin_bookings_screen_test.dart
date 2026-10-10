import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_card.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

/// The clock of the tests; a test moves it to make time "pass".
DateTime now = DateTime.utc(2026, 10, 9, 12);

/// Shows the bookings screen for a signed-in admin. All data is made up.
Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminBookingsScreen(),
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

Future<void> emit(
  WidgetTester tester,
  List<RawBookingDocument> documents, {
  bool fromCache = false,
}) async {
  bookings.emit(documents, fromCache: fromCache);
  await settle(tester);
}

void main() {
  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    auth = FakeAdminAuthRepository(initial: AdminSession.admin);
    bookings = FakeAdminBookingsRepository()
      ..cars = [testCar(), testCar(id: 'hidden-car', active: false)];
    addTearDown(auth.close);
  });

  testWidgets('shows a spinner until the first answer', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AdminBookingCard), findsNothing);
    expect(find.text(adminNoBookings), findsNothing);
  });

  testWidgets('no bookings: the empty text', (tester) async {
    await pumpScreen(tester);
    await emit(tester, const []);

    expect(find.text(adminNoBookings), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('one row shows the customer, the car, the dates in Tbilisi '
      'time, the days, the total and when it was received', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [
      rawBooking('a', fullName: 'Test Person', totalPrice: 272.5),
    ]);

    expect(find.text(adminBookingsTitle), findsOneWidget);
    // Once above the list, not on every row.
    expect(find.text('Tbilisi time (GMT+4)'), findsOneWidget);
    expect(find.text('Test Person'), findsOneWidget);
    expect(find.text('+995555000000'), findsOneWidget);
    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    // Stored 14:00 and 16:00 UTC; shown as 18:00 and 20:00 in Tbilisi.
    expect(find.text('10 Jan 2026 18:00 → 15 Jan 2026 20:00'), findsOneWidget);
    expect(find.text('5 days · \$272.50'), findsOneWidget);
    expect(find.text('Received 9 Oct 2026 17:34'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rows keep the order of the answer; each status has its '
      'word on the chip', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [
      rawBooking('1', fullName: 'Person One', status: 'new'),
      rawBooking('2', fullName: 'Person Two', status: 'pending'),
      rawBooking('3', fullName: 'Person Three', status: 'confirmed'),
      rawBooking('4', fullName: 'Person Four', status: 'cancelled'),
    ]);

    final names = ['Person One', 'Person Two', 'Person Three', 'Person Four'];
    final tops = [
      for (final name in names) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, [...tops]..sort());

    for (final word in ['New', 'Pending', 'Confirmed', 'Cancelled']) {
      expect(find.text(word), findsOneWidget, reason: word);
    }
    expect(find.byType(AdminStatusChip), findsNWidgets(4));
  });

  test('the four statuses have four different colours and four words', () {
    final colours = {
      for (final status in BookingStatus.values) adminStatusColor(status),
    };
    final words = {
      for (final status in BookingStatus.values) adminStatusLabel(status),
    };
    expect(colours, hasLength(BookingStatus.values.length));
    expect(words, hasLength(BookingStatus.values.length));
    expect(words.every((word) => word.isNotEmpty), true);
  });

  testWidgets('a hidden car is marked, and a missing car says so', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [
      rawBooking('a', carId: 'hidden-car'),
      rawBooking('b', carId: 'no-such-car'),
    ]);

    expect(find.text('Toyota Prius, 2019 (hidden)'), findsOneWidget);
    expect(find.text('Car not found'), findsOneWidget);
    // The stored id of the car is never shown.
    expect(find.textContaining('no-such-car'), findsNothing);
  });

  testWidgets('cars that could not be loaded: the rows still appear', (
    tester,
  ) async {
    bookings.carsError = const AdminBookingsException(
      AdminBookingsFailure.other,
    );
    await pumpScreen(tester);
    await emit(tester, [rawBooking('a')]);

    expect(find.byType(AdminBookingCard), findsOneWidget);
    expect(find.text('Car: not loaded'), findsOneWidget);
  });

  testWidgets('more than 7 days is marked as an estimate; 7 days is not', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [
      rawBooking(
        'week',
        dropoff: DateTime.utc(2026, 1, 17, 14),
        totalPrice: 315,
      ),
      rawBooking(
        'long',
        dropoff: DateTime.utc(2026, 1, 17, 17),
        totalPrice: 360,
      ),
      rawBooking(
        'short',
        dropoff: DateTime.utc(2026, 1, 10, 15),
        totalPrice: 45,
      ),
    ]);

    expect(find.text('7 days · \$315'), findsOneWidget);
    expect(find.text('8 days · \$360 · estimate'), findsOneWidget);
    expect(find.text('1 day · \$45'), findsOneWidget);
  });

  testWidgets('unreadable documents: the count is shown and the good rows '
      'stay', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [
      rawBooking('good'),
      rawBooking('bad-1', status: 'completed'),
      rawBooking('bad-2', totalPrice: -5),
    ]);

    expect(find.text('2 bookings could not be read.'), findsOneWidget);
    expect(find.byType(AdminBookingCard), findsOneWidget);
    // In a debug build (tests are one) the ids and reasons are listed.
    expect(find.textContaining('bad-1:'), findsOneWidget);
    expect(find.textContaining('bad-2:'), findsOneWidget);
  });

  testWidgets('one unreadable document and nothing else: singular text, not '
      'the empty state', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [rawBooking('bad', status: 'completed')]);

    expect(find.text('1 booking could not be read.'), findsOneWidget);
    expect(find.text(adminNoBookings), findsNothing);
  });

  testWidgets('permission denied: its own text', (tester) async {
    await pumpScreen(tester);
    bookings.fail(
      const AdminBookingsException(AdminBookingsFailure.permissionDenied),
    );
    await settle(tester);

    expect(find.text(adminBookingsNoAccess), findsOneWidget);
    expect(find.text(adminBookingsLoadError), findsNothing);
  });

  testWidgets('another error: the text, and "Try again" loads the list', (
    tester,
  ) async {
    await pumpScreen(tester);
    bookings.fail(const AdminBookingsException(AdminBookingsFailure.other));
    await settle(tester);

    expect(find.text(adminBookingsLoadError), findsOneWidget);

    await tester.tap(find.text(adminTryAgain));
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(bookings.limits, [50, 50]);

    await emit(tester, [rawBooking('a')]);
    expect(find.byType(AdminBookingCard), findsOneWidget);
    expect(find.text(adminBookingsLoadError), findsNothing);
  });

  testWidgets('the offline line appears only after 3 seconds of saved data, '
      'and goes when the server answers', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [rawBooking('a')], fromCache: true);
    expect(find.text(adminOfflineNote), findsNothing);
    expect(find.byType(AdminBookingCard), findsOneWidget);

    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text(adminOfflineNote), findsOneWidget);

    await emit(tester, [rawBooking('a')]);
    expect(find.text(adminOfflineNote), findsNothing);
  });

  testWidgets('"Load more" appears only for a full page, and asks for 50 '
      'more', (tester) async {
    await pumpScreen(tester, size: const Size(800, 12000));
    await emit(tester, [for (var i = 0; i < 49; i++) rawBooking('b$i')]);
    expect(find.text(adminLoadMore), findsNothing);

    await emit(tester, [for (var i = 0; i < 50; i++) rawBooking('b$i')]);
    expect(find.text(adminLoadMore), findsOneWidget);

    await tester.tap(find.text(adminLoadMore));
    await settle(tester);
    expect(bookings.limits, [50, 100]);
    // The rows stay while the next page loads.
    expect(find.byType(AdminBookingCard), findsNWidgets(50));
    expect(find.text(adminLoadMore), findsNothing);

    await emit(tester, [for (var i = 0; i < 60; i++) rawBooking('b$i')]);
    expect(find.byType(AdminBookingCard), findsNWidgets(60));
    expect(find.text(adminLoadMore), findsNothing);
  });

  testWidgets('Sign out closes the listener first, then signs out', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [rawBooking('a')]);
    expect(bookings.activeListeners, 1);

    await tester.tap(find.byTooltip(adminSignOutButton));
    await settle(tester);

    expect(auth.signOuts, 1);
    expect(bookings.activeListeners, 0);
    // No failure text flashes after the sign-out.
    expect(find.text(adminBookingsNoAccess), findsNothing);
    expect(find.text(adminBookingsLoadError), findsNothing);
    expect(find.byType(AdminBookingCard), findsNothing);
  });

  testWidgets('320 px wide: a long name and a hidden car do not overflow', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(320, 2000));
    await emit(tester, [
      rawBooking(
        'a',
        fullName: List.filled(9, 'Konstantine').join(' '),
        carId: 'hidden-car',
        status: 'confirmed',
        dropoff: DateTime.utc(2026, 2, 20, 16),
        totalPrice: 123456.78,
      ),
      rawBooking('bad', status: 'completed'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminBookingCard), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  group('filter, search and sort (step 3.7)', () {
    final four = [
      rawBooking(
        'a',
        fullName: 'Person One',
        phone: '+995555000001',
        status: 'new',
        pickup: DateTime.utc(2026, 12, 20, 14),
        dropoff: DateTime.utc(2026, 12, 22, 14),
        createdAt: DateTime.utc(2026, 10, 9, 13),
      ),
      rawBooking(
        'b',
        fullName: 'Person Two',
        phone: '+995555000002',
        status: 'confirmed',
        pickup: DateTime.utc(2026, 11, 5, 14),
        dropoff: DateTime.utc(2026, 11, 7, 14),
        createdAt: DateTime.utc(2026, 10, 8, 13),
      ),
      rawBooking(
        'c',
        fullName: 'Someone Else',
        phone: '+995577123456',
        status: 'confirmed',
        pickup: DateTime.utc(2026, 9, 1, 14),
        dropoff: DateTime.utc(2026, 9, 3, 14),
        createdAt: DateTime.utc(2026, 10, 7, 13),
      ),
      rawBooking(
        'd',
        fullName: 'Person Four',
        phone: '+995555000004',
        status: 'cancelled',
        pickup: DateTime.utc(2026, 10, 20, 14),
        dropoff: DateTime.utc(2026, 10, 22, 14),
        createdAt: DateTime.utc(2026, 10, 6, 13),
      ),
    ];

    Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

    List<String> namesInOrder(WidgetTester tester) {
      final cards = tester.widgetList<AdminBookingCard>(
        find.byType(AdminBookingCard),
      );
      return [for (final card in cards) card.booking.customer.fullName];
    }

    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await settle(tester);
    }

    // The menu needs time to open and to close again.
    Future<void> chooseSort(WidgetTester tester, String label) async {
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<AdminBookingsSort>, label),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // On a narrow screen a chip can be outside the row; scroll to it first.
    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(chip(label));
      await settle(tester);
      await tester.tap(chip(label));
      await settle(tester);
    }

    testWidgets('the five chips show their counts, and "All" is selected', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, four);

      for (final label in [
        'All 4',
        'New 1',
        'Pending 0',
        'Confirmed 2',
        'Cancelled 1',
      ]) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      expect(tester.widget<ChoiceChip>(chip('All 4')).selected, true);
      expect(tester.widget<ChoiceChip>(chip('New 1')).selected, false);
      expect(find.byType(AdminBookingCard), findsNWidgets(4));
    });

    testWidgets('a chip shows only its bookings; "All" brings them back', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, four);

      await tapChip(tester, 'Confirmed 2');
      expect(namesInOrder(tester), ['Person Two', 'Someone Else']);
      expect(tester.widget<ChoiceChip>(chip('Confirmed 2')).selected, true);
      expect(tester.widget<ChoiceChip>(chip('All 4')).selected, false);
      // The counts do not change with the chosen chip.
      expect(chip('New 1'), findsOneWidget);

      await tapChip(tester, 'All 4');
      expect(find.byType(AdminBookingCard), findsNWidgets(4));
    });

    testWidgets('a status without bookings: "No bookings match" and "Clear '
        'filters"', (tester) async {
      await pumpScreen(tester);
      await emit(tester, four);

      await tapChip(tester, 'Pending 0');
      expect(find.byType(AdminBookingCard), findsNothing);
      expect(find.text(adminNoMatch), findsOneWidget);
      // Not the "no bookings at all" text.
      expect(find.text(adminNoBookings), findsNothing);

      await tester.tap(find.text(adminClearFilters));
      await settle(tester);
      expect(find.byType(AdminBookingCard), findsNWidgets(4));
      expect(find.text(adminNoMatch), findsNothing);
      expect(tester.widget<ChoiceChip>(chip('All 4')).selected, true);
    });

    testWidgets('the search finds by name and by phone, and the counts '
        'follow it', (tester) async {
      await pumpScreen(tester);
      await emit(tester, four);

      await search(tester, 'person');
      expect(namesInOrder(tester), ['Person One', 'Person Two', 'Person Four']);
      expect(chip('All 3'), findsOneWidget);
      expect(chip('Confirmed 1'), findsOneWidget);

      // A phone number with a space in it.
      await search(tester, '577 12');
      expect(namesInOrder(tester), ['Someone Else']);
      expect(chip('All 1'), findsOneWidget);

      await search(tester, 'nobody');
      expect(find.byType(AdminBookingCard), findsNothing);
      expect(find.text(adminNoMatch), findsOneWidget);

      await tester.tap(find.byTooltip(adminClearSearch));
      await settle(tester);
      expect(find.byType(AdminBookingCard), findsNWidgets(4));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('a chip and a search together', (tester) async {
      await pumpScreen(tester);
      await emit(tester, four);

      await search(tester, 'person');
      await tapChip(tester, 'Confirmed 1');

      expect(namesInOrder(tester), ['Person Two']);
    });

    testWidgets('the search field does not let the keyboard learn names', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, four);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, false);
      expect(field.enableSuggestions, false);
      expect(field.autofillHints, anyOf(isNull, isEmpty));
      expect(field.textInputAction, TextInputAction.search);
    });

    testWidgets('the sort menu: newest first, oldest first, pickup date', (
      tester,
    ) async {
      // "Now" is 9 October 2026: the September pickup is past.
      await pumpScreen(tester);
      await emit(tester, four);
      expect(namesInOrder(tester), [
        'Person One',
        'Person Two',
        'Someone Else',
        'Person Four',
      ]);
      expect(find.byTooltip('Sort: Newest first'), findsOneWidget);

      await chooseSort(tester, 'Oldest first');
      expect(namesInOrder(tester), [
        'Person Four',
        'Someone Else',
        'Person Two',
        'Person One',
      ]);
      expect(find.byTooltip('Sort: Oldest first'), findsOneWidget);

      await chooseSort(tester, 'Pickup date');
      // Coming pickups, the soonest first; the past one last.
      expect(namesInOrder(tester), [
        'Person Four',
        'Person Two',
        'Person One',
        'Someone Else',
      ]);
    });

    testWidgets('a live update keeps the chosen chip and search', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, four);
      await search(tester, 'person');
      await tapChip(tester, 'Confirmed 1');

      await emit(tester, [
        rawBooking('e', fullName: 'Person Five', status: 'confirmed'),
        ...four,
      ]);

      expect(namesInOrder(tester), ['Person Five', 'Person Two']);
      expect(chip('Confirmed 2'), findsOneWidget);
      expect(chip('All 4'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'person',
      );
      // Still one query; filtering asked Firestore for nothing.
      expect(bookings.limits, [50]);
    });

    testWidgets('the "loaded bookings" line shows only while more can be '
        'loaded, with the real number', (tester) async {
      await pumpScreen(tester, size: const Size(800, 12000));
      await emit(tester, four);
      expect(find.textContaining('Filters and counts cover'), findsNothing);

      await emit(tester, [for (var i = 0; i < 50; i++) rawBooking('b$i')]);
      expect(find.text(adminLoadedOnlyNote(50)), findsOneWidget);

      // One of the 50 documents cannot be read: 49 bookings are loaded.
      await emit(tester, [
        for (var i = 0; i < 49; i++) rawBooking('b$i'),
        rawBooking('bad', status: 'completed'),
      ]);
      expect(find.text(adminLoadedOnlyNote(49)), findsOneWidget);
      expect(find.text(adminLoadedOnlyNote(50)), findsNothing);
    });

    testWidgets('"Load more" stays with a filter that matches nothing', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(800, 12000));
      await emit(tester, [for (var i = 0; i < 50; i++) rawBooking('b$i')]);

      await tapChip(tester, 'Cancelled 0');

      expect(find.text(adminNoMatch), findsOneWidget);
      expect(find.text(adminLoadMore), findsOneWidget);

      await tester.tap(find.text(adminLoadMore));
      await settle(tester);
      expect(bookings.limits, [50, 100]);
    });

    testWidgets('the choice is back to the default after Sign out', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, four);
      await search(tester, 'person');
      await tapChip(tester, 'Confirmed 1');

      await tester.tap(find.byTooltip(adminSignOutButton));
      await settle(tester);
      auth.report(AdminSession.admin);
      await settle(tester);
      await emit(tester, four);

      expect(find.byType(AdminBookingCard), findsNWidgets(4));
      expect(tester.widget<ChoiceChip>(chip('All 4')).selected, true);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('no bookings at all: no controls, only the empty text', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, const []);

      expect(find.text(adminNoBookings), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('320 px wide: the controls fit and the chips scroll '
        'sideways', (tester) async {
      await pumpScreen(tester, size: const Size(320, 2400));
      await emit(tester, four);
      expect(tester.takeException(), isNull);

      // The last chip is outside at first and can be brought into view.
      await tapChip(tester, 'Cancelled 1');

      expect(namesInOrder(tester), ['Person Four']);
      expect(tester.takeException(), isNull);
    });
  });
}
