import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/not_found_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../support/fake_admin_auth_repository.dart';
import '../../support/fake_admin_bookings_repository.dart';
import '../../support/fake_fleet_repository.dart';

/// One made-up car.
const car = Car(
  id: 'car-1',
  brand: 'Brand',
  model: 'Model',
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: 40,
  description: LocalizedText(en: 'A made-up car.'),
  photos: [],
  active: true,
);

final en = lookupAppLocalizations(const Locale('en'));

late FakeAdminAuthRepository auth;

/// The real router and the real screens; Firebase is replaced.
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

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> pumpApp(
  WidgetTester tester, {
  AdminSession session = AdminSession.signedOut,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: session);
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(
          FakeAdminBookingsRepository(),
        ),
        fleetRepositoryProvider.overrideWithValue(FakeFleetRepository()),
        activeCarsProvider.overrideWith((ref) => Stream.value(const [car])),
        carProvider.overrideWith(
          (ref, carId) => carId == car.id
              ? Stream.value(car)
              : Stream.error(const CarNotAvailableException()),
        ),
        extrasPricesProvider.overrideWith(
          (ref) => Stream.value(
            ExtrasPrices.fromMap({
              'pricesPerDay': {
                'snowChains': 7,
                'childSeat': 4.5,
                'infantSeat': 0,
                'boosterSeat': 3,
              },
            }),
          ),
        ),
        pickupLocationsProvider.overrideWith(
          (ref) => Stream.value(const <PickupLocation>[
            PickupLocation(
              id: 'tbilisiAirport',
              name: LocalizedText(en: 'Tbilisi Airport'),
            ),
          ]),
        ),
        companyInfoProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

Future<void> open(WidgetTester tester, String address) async {
  ProviderScope.containerOf(
    tester.element(find.byType(_App)),
  ).read(appRouterProvider).go(address);
  await settle(tester);
}

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(_App)),
).read(appRouterProvider);

/// The address the router gives the browser (the address bar).
String browserAddress(WidgetTester tester) {
  final router = routerOf(tester);
  return router.routeInformationParser
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)!
      .uri
      .toString();
}

Finder get bar => find.byType(NavigationBar);

int? selectedTab(WidgetTester tester) => bar.evaluate().isEmpty
    ? null
    : tester.widget<NavigationBar>(bar).selectedIndex;

void main() {
  for (final address in [
    '/zzz',
    '/faq/x',
    '/about/x',
    '/cars/abc/zzz',
    '/zzz/',
    '/a/b/c/d',
  ]) {
    testWidgets('$address: the "not found" page, without the bottom bar; '
        'the address bar keeps the address', (tester) async {
      await pumpApp(tester);
      await open(tester, address);
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(bar, findsNothing);
      expect(find.text(en.notFoundTitle), findsOneWidget);
      // The typed address is never shown on the page.
      expect(find.textContaining('zzz'), findsNothing);
      expect(find.textContaining('/a/b'), findsNothing);
      // The address bar still shows what was typed (a slash at the end
      // may be dropped by the router).
      final shown = browserAddress(tester);
      expect(
        shown == address || '$shown/' == address,
        isTrue,
        reason: 'shown: $shown',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Go to Home" opens Home with the Home tab selected', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/zzz');
    await tester.tap(find.widgetWithText(FilledButton, en.notFoundGoHome));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(selectedTab(tester), 0);
  });

  testWidgets('Android system Back on the page goes to Home; no error, the '
      'app does not close', (tester) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpApp(tester);
    await open(tester, '/zzz');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(selectedTab(tester), 0);
    expect(browserAddress(tester), '/');
  });

  testWidgets('an unknown admin address, signed out: the login page', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/admin/zzz');
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  testWidgets('a known admin address, signed out: the login page with "from"', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/admin/calendar');
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(browserAddress(tester), '/admin/login?from=%2Fadmin%2Fcalendar');
  });

  testWidgets('a known admin address, admin: the admin page', (tester) async {
    await pumpApp(tester, session: AdminSession.admin);
    await open(tester, '/admin');
    expect(find.byType(AdminBookingsScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(find.byType(AdminNotFoundScreen), findsNothing);
  });

  testWidgets('/booking-sent without a sent booking: on to the catalog', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/booking-sent');
    await settle(tester);
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('an unknown admin address, admin: the admin "not found" page', (
    tester,
  ) async {
    await pumpApp(tester, session: AdminSession.admin);
    await open(tester, '/admin/zzz');
    expect(find.byType(AdminNotFoundScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  testWidgets('an unknown car: the car page says "not available"', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/cars/no-such-car');
    expect(find.byType(CarDetailScreen), findsOneWidget);
    expect(find.text(en.carNotAvailable), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  for (final (address, screen) in [
    ('/', HomeScreen),
    ('/cars', CatalogScreen),
    ('/about', AboutScreen),
    ('/faq', FaqScreen),
    ('/cars/car-1', CarDetailScreen),
    ('/cars/car-1/book', BookingFormScreen),
  ]) {
    testWidgets('$address: its own page, never "not found"', (tester) async {
      await pumpApp(tester);
      await open(tester, address);
      expect(find.byType(screen), findsOneWidget);
      expect(find.byType(NotFoundScreen), findsNothing);
    });
  }

  testWidgets('/cars/ with a trailing slash (reported, not changed)', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '/cars/');
    final notFound = find.byType(NotFoundScreen).evaluate().isNotEmpty;
    final catalog = find.byType(CatalogScreen).evaluate().isNotEmpty;
    // ignore: avoid_print
    print('TRAILING SLASH /cars/: notFound=$notFound catalog=$catalog');
    expect(notFound != catalog, isTrue);
  });
}
