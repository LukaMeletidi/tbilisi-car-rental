import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The Calendar entry of the admin navigation (step 5.5a), with the real
/// router and the real shell; Firebase is replaced. Every value is made up.
const car = Car(
  id: 'car-1',
  brand: 'Honda',
  model: 'Civic',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: LocalizedText(en: 'A good car.'),
  photos: [],
  active: true,
);

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

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

const wide = Size(1200, 900);
const phone = Size(400, 900);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = wide,
  AdminSession? session = AdminSession.admin,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: session);
  bookings = FakeAdminBookingsRepository();
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        fleetRepositoryProvider.overrideWithValue(FakeFleetRepository()),
        activeCarsProvider.overrideWith((ref) => Stream.value([car])),
        carProvider.overrideWith((ref, id) => Stream.value(car)),
        pickupLocationsProvider.overrideWith((ref) => Stream.value(const [])),
        extrasPricesProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

Future<void> open(WidgetTester tester, String address) async {
  containerOf(tester).read(appRouterProvider).go(address);
  await settle(tester);
}

String address(WidgetTester tester) => containerOf(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

Finder get rail => find.byType(NavigationRail);
Finder get bar => find.byType(NavigationBar);

int? selectedIndex(WidgetTester tester) {
  if (rail.evaluate().isNotEmpty) {
    return tester.widget<NavigationRail>(rail).selectedIndex;
  }
  if (bar.evaluate().isNotEmpty) {
    return tester.widget<NavigationBar>(bar).selectedIndex;
  }
  return null;
}

/// The labels of the navigation, from left to right or top to bottom.
List<String> entries(WidgetTester tester) {
  final navigation = rail.evaluate().isNotEmpty ? rail : bar;
  final labels = [adminNavBookings, adminNavCalendar, adminNavCars];
  final found = [
    for (final label in labels)
      (
        label: label,
        at: tester.getCenter(
          find.descendant(of: navigation, matching: find.text(label)),
        ),
      ),
  ];
  found.sort(
    (a, b) => rail.evaluate().isNotEmpty
        ? a.at.dy.compareTo(b.at.dy)
        : a.at.dx.compareTo(b.at.dx),
  );
  return [for (final entry in found) entry.label];
}

Future<void> tapEntry(WidgetTester tester, String label) async {
  final navigation = rail.evaluate().isNotEmpty ? rail : bar;
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await settle(tester);
}

void main() {
  for (final size in [wide, phone]) {
    final width = size.width.toInt();

    testWidgets('$width px: three entries, Bookings, Calendar, Cars', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      await open(tester, '/admin');
      expect(entries(tester), [
        adminNavBookings,
        adminNavCalendar,
        adminNavCars,
      ]);
      expect(selectedIndex(tester), 0);
    });

    testWidgets('$width px: Calendar, Cars and Calendar again', (tester) async {
      await pumpApp(tester, size: size);
      await open(tester, '/admin');

      await tapEntry(tester, adminNavCalendar);
      expect(address(tester), '/admin/calendar');
      expect(find.byType(AdminCalendarScreen), findsOneWidget);
      expect(selectedIndex(tester), 1);

      await tapEntry(tester, adminNavCars);
      expect(find.byType(AdminCarsScreen), findsOneWidget);
      expect(selectedIndex(tester), 2);

      await tapEntry(tester, adminNavCalendar);
      expect(find.byType(AdminCalendarScreen), findsOneWidget);
      expect(selectedIndex(tester), 1);

      await tapEntry(tester, adminNavBookings);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(selectedIndex(tester), 0);
    });
  }

  testWidgets('Calendar opened directly: its page with the navigation, and '
      'no bookings query', (tester) async {
    await pumpApp(tester);
    await open(tester, '/admin/calendar');
    expect(find.byType(AdminCalendarScreen), findsOneWidget);
    expect(rail, findsOneWidget);
    expect(selectedIndex(tester), 1);
    expect(bookings.limits, isEmpty);
  });

  testWidgets('a page below Calendar is the "not found" page, without '
      'navigation', (tester) async {
    await pumpApp(tester);
    await open(tester, '/admin/calendar/x');
    expect(find.byType(AdminNotFoundScreen), findsOneWidget);
    expect(find.byType(AdminCalendarScreen), findsNothing);
    expect(rail, findsNothing);
    expect(bar, findsNothing);
  });

  testWidgets('320 px wide: the bottom bar with three entries fits', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 700));
    await open(tester, '/admin/calendar');
    expect(bar, findsOneWidget);
    expect(entries(tester), [adminNavBookings, adminNavCalendar, adminNavCars]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system Back on Calendar (as Android) goes to Bookings', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/admin');
    await tapEntry(tester, adminNavCalendar);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(address(tester), '/admin');
    expect(find.byType(AdminBookingsScreen), findsOneWidget);
  });

  group('without an admin session, the Calendar is out of reach', () {
    testWidgets('signed out: the login page; after the sign-in the admin '
        'lands on Calendar', (tester) async {
      await pumpApp(tester, session: AdminSession.signedOut);
      await open(tester, '/admin/calendar');
      expect(address(tester), '/admin/login?from=%2Fadmin%2Fcalendar');
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminCalendarScreen), findsNothing);
      expect(rail, findsNothing);

      auth.report(AdminSession.admin);
      await settle(tester);
      expect(address(tester), '/admin/calendar');
      expect(find.byType(AdminCalendarScreen), findsOneWidget);
    });

    testWidgets('signed in without the claim: the no-access page', (
      tester,
    ) async {
      await pumpApp(tester, session: AdminSession.noAccess);
      await open(tester, '/admin/calendar');
      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(find.byType(AdminCalendarScreen), findsNothing);
      expect(rail, findsNothing);
    });

    testWidgets('while the session is checked: the checking page', (
      tester,
    ) async {
      await pumpApp(tester, session: null);
      await open(tester, '/admin/calendar');
      expect(find.byType(AdminCheckingScreen), findsOneWidget);
      expect(find.byType(AdminCalendarScreen), findsNothing);
    });
  });
}
