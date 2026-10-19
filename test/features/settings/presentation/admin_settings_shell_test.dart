import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_navigation.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_settings_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// A made-up car for the public part of the router.
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
  AdminSession session = AdminSession.admin,
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
        // The Extras & Prices form reads the repository (step 6.6).
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
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

Future<void> tapEntry(WidgetTester tester, String label) async {
  final navigation = rail.evaluate().isNotEmpty ? rail : bar;
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await settle(tester);
}

/// The labels of the navigation, in order.
List<String> entryLabels(WidgetTester tester) {
  if (rail.evaluate().isNotEmpty) {
    return [
      for (final destination
          in tester.widget<NavigationRail>(rail).destinations)
        (destination.label as Text).data!,
    ];
  }
  return [
    for (final destination in tester.widget<NavigationBar>(bar).destinations)
      (destination as NavigationDestination).label,
  ];
}

const allEntries = [
  adminNavBookings,
  adminNavCalendar,
  adminNavCars,
  adminNavSettings,
];

void main() {
  group('the Settings entry', () {
    testWidgets('wide: the rail has four entries, Settings last', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      expect(rail, findsOneWidget);
      expect(entryLabels(tester), allEntries);
    });

    testWidgets('phone: the bottom bar has the same four entries', (
      tester,
    ) async {
      await pumpApp(tester, size: phone);
      await open(tester, '/admin');

      expect(bar, findsOneWidget);
      expect(entryLabels(tester), allEntries);
    });

    for (final size in [wide, phone]) {
      testWidgets('${size.width.toInt()} px: Settings is selected at index 3 '
          'and back to Bookings', (tester) async {
        await pumpApp(tester, size: size);
        await open(tester, '/admin');

        await tapEntry(tester, adminNavSettings);
        expect(address(tester), '/admin/settings');
        expect(find.byType(AdminSettingsScreen), findsOneWidget);
        expect(selectedIndex(tester), 3);

        await tapEntry(tester, adminNavBookings);
        expect(address(tester), '/admin');
        expect(find.byType(AdminBookingsScreen), findsOneWidget);
        expect(selectedIndex(tester), 0);
      });
    }

    testWidgets('the selected entry is always the section of the address', (
      tester,
    ) async {
      await pumpApp(tester);
      for (final page in [
        '/admin',
        '/admin/calendar',
        '/admin/cars',
        '/admin/settings',
      ]) {
        await open(tester, page);
        expect(
          selectedIndex(tester),
          adminSectionOf(address(tester))!.index,
          reason: page,
        );
      }
    });

    testWidgets('the bookings list stays alive while Settings is shown', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      expect(bookings.activeListeners, 1);

      await tapEntry(tester, adminNavSettings);
      expect(bookings.limits, [50]);
      expect(bookings.activeListeners, 1);
    });
  });

  group('the two pages below Settings', () {
    for (final size in [wide, phone]) {
      testWidgets('${size.width.toInt()} px: each entry opens its page, '
          'without navigation; the back arrow returns to Settings', (
        tester,
      ) async {
        await pumpApp(tester, size: size);
        await open(tester, '/admin/settings');

        for (final page in [
          (
            adminSettingsExtrasKey,
            '/admin/settings/extras',
            AdminExtrasPricesScreen,
          ),
          (
            adminSettingsCompanyKey,
            '/admin/settings/company',
            AdminCompanyInfoScreen,
          ),
        ]) {
          await tester.tap(find.byKey(page.$1));
          await settle(tester);
          expect(address(tester), page.$2);
          expect(find.byType(page.$3), findsOneWidget);
          expect(rail, findsNothing);
          expect(bar, findsNothing);

          await tester.tap(find.byType(BackButton));
          await settle(tester);
          expect(address(tester), '/admin/settings');
          expect(find.byType(AdminSettingsScreen), findsOneWidget);
          expect(selectedIndex(tester), 3);
        }
      });
    }

    testWidgets('opened directly, a page shows its form (a spinner until '
        'the server answers) and its back arrow leads to Settings', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/settings/company');

      expect(find.byType(AdminCompanyInfoScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(rail, findsNothing);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(address(tester), '/admin/settings');
    });

    testWidgets('an unknown page below Settings is the admin "not found" '
        'page, without navigation', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/settings/x');

      expect(find.byType(AdminNotFoundScreen), findsOneWidget);
      expect(find.byType(AdminSettingsScreen), findsNothing);
      expect(rail, findsNothing);
      expect(bar, findsNothing);
    });
  });

  group('sign-in, sign-out and the system Back', () {
    testWidgets('signed out on /admin/settings: after sign-in the admin '
        'lands on Settings', (tester) async {
      await pumpApp(tester, session: AdminSession.signedOut);
      await open(tester, '/admin/settings');
      expect(address(tester), '/admin/login?from=%2Fadmin%2Fsettings');
      expect(find.byType(AdminSettingsScreen), findsNothing);

      auth.report(AdminSession.admin);
      await settle(tester);

      expect(address(tester), '/admin/settings');
      expect(find.byType(AdminSettingsScreen), findsOneWidget);
      expect(rail, findsOneWidget);
    });

    testWidgets('Sign out on Settings shows the login page', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/settings');

      await tester.tap(find.byTooltip(adminSignOutButton));
      await settle(tester);

      expect(auth.signOuts, 1);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(rail, findsNothing);
    });

    testWidgets('Android Back: from a page to Settings, from Settings to '
        'Bookings', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      await tapEntry(tester, adminNavSettings);
      await tester.tap(find.byKey(adminSettingsExtrasKey));
      await settle(tester);
      expect(address(tester), '/admin/settings/extras');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/admin/settings');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/admin');
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
    });
  });
}
