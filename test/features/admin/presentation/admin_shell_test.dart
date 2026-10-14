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
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_cars_placeholder_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

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

Future<void> tapEntry(WidgetTester tester, String label) async {
  final navigation = rail.evaluate().isNotEmpty ? rail : bar;
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await settle(tester);
}

void main() {
  group('the kind of navigation', () {
    testWidgets('wide: a side rail with Bookings selected', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      expect(rail, findsOneWidget);
      expect(bar, findsNothing);
      expect(selectedIndex(tester), 0);
      expect(
        find.descendant(of: rail, matching: find.text(adminNavCars)),
        findsOneWidget,
      );
    });

    testWidgets('phone: a bottom bar', (tester) async {
      await pumpApp(tester, size: phone);
      await open(tester, '/admin');

      expect(bar, findsOneWidget);
      expect(rail, findsNothing);
      expect(selectedIndex(tester), 0);
    });
  });

  group('changing the section', () {
    for (final size in [wide, phone]) {
      testWidgets('${size.width.toInt()} px: Cars and back to Bookings', (
        tester,
      ) async {
        await pumpApp(tester, size: size);
        await open(tester, '/admin');

        await tapEntry(tester, adminNavCars);
        expect(address(tester), '/admin/cars');
        expect(find.byType(AdminCarsPlaceholderScreen), findsOneWidget);
        expect(find.text(adminCarsComingSoon), findsOneWidget);
        expect(selectedIndex(tester), 1);

        await tapEntry(tester, adminNavBookings);
        expect(address(tester), '/admin');
        expect(find.byType(AdminBookingsScreen), findsOneWidget);
        expect(selectedIndex(tester), 0);
      });
    }

    testWidgets('the bookings list stays alive while Cars is shown: no new '
        'query, the same listener', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      bookings.emit([rawBooking('b1')]);
      await settle(tester);

      await tapEntry(tester, adminNavCars);
      expect(bookings.activeListeners, 1);
      await tapEntry(tester, adminNavBookings);

      expect(bookings.limits, [50]);
      expect(bookings.activeListeners, 1);
      expect(find.text('Test Person'), findsOneWidget);
    });

    testWidgets('a tap on the section that is shown returns to its first '
        'page', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/bookings/b1');
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);

      await tapEntry(tester, adminNavBookings);

      expect(address(tester), '/admin');
      expect(find.byType(AdminBookingDetailScreen), findsNothing);
    });

    testWidgets('Cars opened directly does not start the bookings list', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/cars');

      expect(find.byType(AdminCarsPlaceholderScreen), findsOneWidget);
      expect(selectedIndex(tester), 1);
      expect(bookings.limits, isEmpty);
    });
  });

  group('which page shows the navigation', () {
    testWidgets('wide: the list, a detail and Cars; not the forms', (
      tester,
    ) async {
      await pumpApp(tester);
      for (final page in [
        ('/admin', true),
        ('/admin/bookings/b1', true),
        ('/admin/cars', true),
        ('/admin/bookings/new', false),
        ('/admin/bookings/b1/edit', false),
      ]) {
        await open(tester, page.$1);
        expect(rail, page.$2 ? findsOneWidget : findsNothing, reason: page.$1);
        expect(bar, findsNothing, reason: page.$1);
      }
      expect(find.byType(AdminBookingEditScreen), findsOneWidget);
    });

    testWidgets('phone: only the list and Cars', (tester) async {
      await pumpApp(tester, size: phone);
      for (final page in [
        ('/admin', true),
        ('/admin/cars', true),
        ('/admin/bookings/b1', false),
        ('/admin/bookings/new', false),
        ('/admin/bookings/b1/edit', false),
      ]) {
        await open(tester, page.$1);
        expect(bar, page.$2 ? findsOneWidget : findsNothing, reason: page.$1);
        expect(rail, findsNothing, reason: page.$1);
      }
    });

    testWidgets('the new-booking form has no navigation, and its back arrow '
        'brings it back', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      await tester.tap(find.text(adminNewBookingTitle));
      await settle(tester);

      expect(find.byType(AdminBookingNewScreen), findsOneWidget);
      expect(rail, findsNothing);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(address(tester), '/admin');
      expect(rail, findsOneWidget);
    });

    testWidgets('the selected entry is always the section of the address', (
      tester,
    ) async {
      await pumpApp(tester);
      for (final page in ['/admin', '/admin/bookings/b1', '/admin/cars']) {
        await open(tester, page);
        expect(
          selectedIndex(tester),
          adminSectionOf(address(tester))!.index,
          reason: page,
        );
      }
    });

    testWidgets('the admin "not found" page has no navigation', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/unknown');

      expect(find.byType(AdminNotFoundScreen), findsOneWidget);
      expect(rail, findsNothing);
      expect(bar, findsNothing);
    });

    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('${session.name}: the gate page of /admin/cars has no '
          'navigation', (tester) async {
        await pumpApp(tester, session: session);
        await open(tester, '/admin/cars');

        expect(
          find.byType(
            session == AdminSession.signedOut
                ? AdminLoginScreen
                : AdminNoAccessScreen,
          ),
          findsOneWidget,
        );
        expect(find.byType(AdminCarsPlaceholderScreen), findsNothing);
        expect(rail, findsNothing);
        expect(bar, findsNothing);
        expect(bookings.limits, isEmpty);
      });
    }

    testWidgets('signed out on /admin/cars: after sign-in the admin lands on '
        'Cars', (tester) async {
      await pumpApp(tester, session: AdminSession.signedOut);
      await open(tester, '/admin/cars');
      expect(address(tester), '/admin/login?from=%2Fadmin%2Fcars');

      auth.report(AdminSession.admin);
      await settle(tester);

      expect(address(tester), '/admin/cars');
      expect(find.byType(AdminCarsPlaceholderScreen), findsOneWidget);
      expect(rail, findsOneWidget);
    });
  });

  group('Sign out', () {
    testWidgets('from Cars, with the list alive: the list listener is '
        'closed and the login page is shown', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      expect(bookings.activeListeners, 1);
      await tapEntry(tester, adminNavCars);

      await tester.tap(find.byTooltip(adminSignOutButton));
      await settle(tester);

      expect(auth.signOuts, 1);
      expect(bookings.activeListeners, 0);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(rail, findsNothing);
    });

    testWidgets('from Cars, without the list: no list is started for it', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/cars');

      await tester.tap(find.byTooltip(adminSignOutButton));
      await settle(tester);

      expect(auth.signOuts, 1);
      expect(bookings.limits, isEmpty);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });
  });

  group('the system Back (tests run as Android, not web)', () {
    testWidgets('from Cars to Bookings, then to the catalog', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      await tapEntry(tester, adminNavCars);
      expect(address(tester), '/admin/cars');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/admin');
      expect(find.byType(AdminBookingsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/');
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('on a detail it goes back to the list as before', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin');
      bookings.emit([rawBooking('b1')]);
      await settle(tester);
      await tester.tap(find.text('Test Person'));
      await settle(tester);
      expect(address(tester), '/admin/bookings/b1');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/admin');
    });
  });
}
