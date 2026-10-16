import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_screen.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/widgets/calendar_grid_view.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The calendar screen (step 5.5b) with fake repositories and a small
/// router: the calendar and a stand-in for the booking detail. Every value
/// is made up.
DateTime tb(int month, int day, [int hour = 0]) =>
    TbilisiDateTime(2026, month, day, hour).toUtc();

RawBookingDocument confirmed(
  String id, {
  String carId = 'car-a',
  DateTime? pickup,
  DateTime? dropoff,
}) => rawBooking(
  id,
  carId: carId,
  status: 'confirmed',
  fullName: 'Made Up Name',
  phone: '+995555000321',
  pickup: pickup ?? tb(10, 18, 10),
  dropoff: dropoff ?? tb(10, 20, 18),
);

final carA = (id: 'car-a', data: rawCar(brand: 'Kia'));

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;
late FakeFleetRepository fleet;

/// 12:00 on 16 Oct 2026 in Tbilisi.
DateTime now = DateTime.utc(2026, 10, 16, 8);

Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  now = DateTime.utc(2026, 10, 16, 8);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  bookings = FakeAdminBookingsRepository();
  fleet = FakeFleetRepository();
  final router = GoRouter(
    initialLocation: '/admin/calendar',
    routes: [
      GoRoute(
        path: '/admin/calendar',
        builder: (context, state) => const AdminCalendarScreen(),
      ),
      GoRoute(
        path: '/admin/bookings/:id',
        builder: (context, state) =>
            Text('detail ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        fleetRepositoryProvider.overrideWithValue(fleet),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> answer(
  WidgetTester tester, {
  List<RawBookingDocument>? confirmedBookings,
  List<FleetRawDocument>? cars,
  bool fromCache = false,
}) async {
  bookings.emitConfirmed(
    confirmedBookings ?? [confirmed('b1')],
    fromCache: fromCache,
  );
  fleet.emit(cars ?? [carA], fromCache: fromCache);
  await tester.pump();
  await tester.pump();
}

Future<void> elapse(WidgetTester tester, Duration duration) async {
  now = now.add(duration);
  await tester.pump(duration);
}

Finder get grid => find.byType(CalendarGridView);
Finder get todayButton => find.widgetWithText(OutlinedButton, 'Today');

void main() {
  testWidgets('loading: the title, the time zone, the controls and the '
      'loading line; Sign out; no back arrow; no grid and no "no '
      'bookings"', (tester) async {
    await pumpScreen(tester);
    expect(find.text(adminCalendarTitle), findsOneWidget);
    expect(find.text(adminTbilisiTimeNote), findsOneWidget);
    expect(find.text('16 Oct – 29 Oct 2026'), findsOneWidget);
    expect(find.byTooltip(adminCalendarPrevious), findsOneWidget);
    expect(find.byTooltip(adminCalendarNext), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(adminCalendarLoading), findsOneWidget);
    expect(find.byTooltip(adminSignOutButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(grid, findsNothing);
    expect(find.text(adminCalendarNoBookings), findsNothing);
    expect(bookings.confirmedWatches, 1);
    expect(fleet.queries, 1);
    expect(bookings.limits, isEmpty);
  });

  testWidgets('answers only from memory: "no connection" after the wait, '
      'never a grid; the server answers and the grid appears', (tester) async {
    await pumpScreen(tester);
    await answer(tester, fromCache: true);
    expect(find.text(adminCalendarLoading), findsOneWidget);
    expect(grid, findsNothing);

    await elapse(tester, serverAnswerWait);
    expect(find.text(adminCalendarNoConnection), findsOneWidget);
    expect(find.text(adminTryAgain), findsOneWidget);
    expect(grid, findsNothing);
    expect(find.text(adminCalendarNoBookings), findsNothing);
    expect(find.text(adminCalendarNoCars), findsNothing);

    await answer(tester);
    expect(grid, findsOneWidget);
    expect(find.text(adminCalendarNoConnection), findsNothing);
  });

  testWidgets('refused: the no-access text; Try again starts again', (
    tester,
  ) async {
    await pumpScreen(tester);
    bookings.failConfirmed(
      const AdminBookingsException(AdminBookingsFailure.permissionDenied),
    );
    await tester.pump();
    expect(find.text(adminCalendarNoAccess), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text(adminTryAgain));
    await tester.pump();
    expect(find.text(adminCalendarLoading), findsOneWidget);
    expect(bookings.confirmedWatches, 2);
    expect(fleet.queries, 2);
    await answer(tester);
    expect(grid, findsOneWidget);
  });

  testWidgets('another error: its text', (tester) async {
    await pumpScreen(tester);
    fleet.fail(const FleetLoadException(FleetLoadFailure.other));
    await tester.pump();
    expect(find.text(adminCalendarLoadError), findsOneWidget);
    expect(grid, findsNothing);
  });

  testWidgets('ready: the grid with the booking, no "no bookings" line, no '
      'customer name anywhere', (tester) async {
    await pumpScreen(tester);
    await answer(tester);
    expect(grid, findsOneWidget);
    expect(find.byKey(calendarBarKey('b1')), findsOneWidget);
    expect(find.byKey(calendarCarKey('car-a')), findsOneWidget);
    expect(find.text(adminCalendarNoBookings), findsNothing);
    expect(find.textContaining('Made Up'), findsNothing);
    expect(find.textContaining('555'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Made Up|555')), findsNothing);
  });

  testWidgets('no booking in these days: the grid of the cars and the line', (
    tester,
  ) async {
    await pumpScreen(tester);
    await answer(tester, confirmedBookings: []);
    expect(grid, findsOneWidget);
    expect(find.byKey(calendarCarKey('car-a')), findsOneWidget);
    expect(find.text(adminCalendarNoBookings), findsOneWidget);
  });

  testWidgets('no cars and no bookings: the "no cars" line, no grid', (
    tester,
  ) async {
    await pumpScreen(tester);
    await answer(tester, confirmedBookings: [], cars: []);
    expect(find.text(adminCalendarNoCars), findsOneWidget);
    expect(grid, findsNothing);
  });

  testWidgets('Previous, Next and Today move the days; Today is off while '
      'the days start today', (tester) async {
    await pumpScreen(tester);
    final later = confirmed(
      'later',
      pickup: tb(11, 3, 10),
      dropoff: tb(11, 4, 10),
    );
    await answer(tester, confirmedBookings: [confirmed('b1'), later]);
    expect(tester.widget<OutlinedButton>(todayButton).onPressed, isNull);
    expect(find.byKey(calendarBarKey('later')), findsNothing);

    await tester.tap(find.byTooltip(adminCalendarNext));
    await tester.pump();
    expect(find.text('23 Oct – 5 Nov 2026'), findsOneWidget);
    expect(find.byKey(calendarBarKey('later')), findsOneWidget);
    expect(find.byKey(calendarBarKey('b1')), findsNothing);
    expect(tester.widget<OutlinedButton>(todayButton).onPressed, isNotNull);

    await tester.tap(find.byTooltip(adminCalendarPrevious));
    await tester.tap(find.byTooltip(adminCalendarPrevious));
    await tester.pump();
    expect(find.text('9 Oct – 22 Oct 2026'), findsOneWidget);

    await tester.tap(todayButton);
    await tester.pump();
    expect(find.text('16 Oct – 29 Oct 2026'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(todayButton).onPressed, isNull);
  });

  testWidgets('a tap on a booking opens its detail', (tester) async {
    await pumpScreen(tester);
    await answer(tester);
    await tester.tap(find.byKey(calendarBarKey('b1')));
    await tester.pumpAndSettle();
    expect(find.text('detail b1'), findsOneWidget);
  });

  testWidgets('from memory for a while after the grid: the offline note, '
      'the grid stays', (tester) async {
    await pumpScreen(tester);
    await answer(tester);
    expect(find.text(adminOfflineNote), findsNothing);
    bookings.emitConfirmed([confirmed('b1')], fromCache: true);
    await tester.pump();
    await elapse(tester, offlineNoteDelay);
    expect(find.text(adminOfflineNote), findsOneWidget);
    expect(find.byKey(calendarBarKey('b1')), findsOneWidget);

    bookings.emitConfirmed([confirmed('b1')]);
    await tester.pump();
    expect(find.text(adminOfflineNote), findsNothing);
  });

  testWidgets('unreadable documents: the line, 1 and more', (tester) async {
    await pumpScreen(tester);
    RawBookingDocument broken(String id) =>
        rawBooking(id, status: 'confirmed', changes: {'carId': 7});
    await answer(tester, confirmedBookings: [confirmed('b1'), broken('x1')]);
    expect(find.text(adminCalendarUnreadable(1)), findsOneWidget);
    expect(
      find.text('1 confirmed booking could not be read and is not shown.'),
      findsOneWidget,
    );
    await answer(
      tester,
      confirmedBookings: [broken('x1'), broken('x2'), broken('x3')],
    );
    expect(
      find.text('3 confirmed bookings could not be read and are not shown.'),
      findsOneWidget,
    );
  });

  testWidgets('Sign out closes the listeners of the calendar first', (
    tester,
  ) async {
    await pumpScreen(tester);
    await answer(tester);
    expect(bookings.activeConfirmedListeners, 1);
    expect(fleet.activeListeners, 1);
    await tester.tap(find.byTooltip(adminSignOutButton));
    await tester.pump();
    expect(bookings.activeConfirmedListeners, 0);
    expect(fleet.activeListeners, 0);
    expect(auth.signOuts, 1);
  });

  for (final size in [const Size(320, 640), const Size(1200, 900)]) {
    final width = size.width.toInt();

    testWidgets('$width px wide, with bookings: nothing overflows', (
      tester,
    ) async {
      await pumpScreen(tester, size: size);
      await answer(
        tester,
        confirmedBookings: [
          confirmed('b1'),
          confirmed('b2', pickup: tb(10, 20, 21), dropoff: tb(10, 22, 12)),
        ],
      );
      expect(grid, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$width px wide, failed: nothing overflows', (tester) async {
      await pumpScreen(tester, size: size);
      bookings.failConfirmed(
        const AdminBookingsException(AdminBookingsFailure.noConnection),
      );
      await tester.pump();
      expect(find.text(adminCalendarNoConnection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
