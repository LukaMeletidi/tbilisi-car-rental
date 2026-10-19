import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// Made-up cars.
Car car(String id, String brand, String model) => Car(
  id: id,
  brand: brand,
  model: model,
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: 1.4,
  pricePerDay: 40,
  description: const LocalizedText(en: 'A good car.'),
  photos: const [],
  active: true,
);

final cars = [car('fiat', 'Fiat', '500'), car('skoda', 'Skoda', 'Octavia')];

/// Made-up sample prices.
final prices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 7,
    'childSeat': 4.5,
    'infantSeat': 0,
    'boosterSeat': 3,
  },
});

/// A made-up sent booking for the thank-you page.
SentBooking sent() => SentBooking(
  id: 'document-1',
  car: cars.first,
  booking: Booking(
    customer: const BookingCustomer(
      fullName: 'Test Person',
      phone: '+995555000000',
      whatsapp: false,
      telegram: false,
      email: 'test@example.com',
    ),
    carId: 'fiat',
    pickup: DateTime.utc(2026, 1, 10, 14),
    dropoff: DateTime.utc(2026, 1, 12, 14),
    pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
    dropoffLocation: const BookingLocation.fixed('tbilisiAirport'),
    extras: const {},
    notes: '',
    totalPrice: 80,
    language: AppLanguage.en,
    status: BookingStatus.newBooking,
  ),
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

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  AdminSession session = AdminSession.signedOut,
}) async {
  tester.view.physicalSize = size;
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
        activeCarsProvider.overrideWith((ref) => Stream.value(cars)),
        carProvider.overrideWith(
          (ref, carId) => Stream.value(cars.firstWhere((c) => c.id == carId)),
        ),
        extrasPricesProvider.overrideWith((ref) => Stream.value(prices)),
        pickupLocationsProvider.overrideWith(
          (ref) => Stream.value(const <PickupLocation>[
            PickupLocation(
              id: 'tbilisiAirport',
              name: LocalizedText(en: 'Tbilisi Airport'),
            ),
          ]),
        ),
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

Finder get bar => find.byType(NavigationBar);

int? selectedIndex(WidgetTester tester) => bar.evaluate().isEmpty
    ? null
    : tester.widget<NavigationBar>(bar).selectedIndex;

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: bar, matching: find.text(label)));
  await settle(tester);
}

void main() {
  group('the tabs', () {
    testWidgets('the app starts on Home with four tabs in order', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(address(tester), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(selectedIndex(tester), 0);
      final labels = [
        for (final destination
            in tester.widget<NavigationBar>(bar).destinations)
          (destination as NavigationDestination).label,
      ];
      expect(labels, ['Home', 'Cars', 'Contact', 'FAQ']);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a wide window also has the bottom bar, never a rail', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1400, 900));
      expect(bar, findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('each tab opens its page and is selected', (tester) async {
      await pumpApp(tester);
      for (final (label, path, screen, index) in [
        ('Cars', '/cars', CatalogScreen, 1),
        ('Contact', '/about', AboutScreen, 2),
        ('FAQ', '/faq', FaqScreen, 3),
        ('Home', '/', HomeScreen, 0),
      ]) {
        await tapTab(tester, label);
        expect(address(tester), path, reason: label);
        expect(find.byType(screen), findsOneWidget, reason: label);
        expect(selectedIndex(tester), index, reason: label);
      }
    });

    testWidgets('the placeholders show their titles and "coming soon"', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Tbilisi Car Rental'), findsWidgets);
      expect(find.text('This page is coming soon.'), findsOneWidget);
      await tapTab(tester, 'Contact');
      expect(find.text('About us'), findsOneWidget);
      await tapTab(tester, 'FAQ');
      expect(find.text('Frequently asked questions'), findsOneWidget);
    });

    testWidgets('opened directly, a tab is selected', (tester) async {
      await pumpApp(tester);
      for (final (path, index) in [
        ('/faq', 3),
        ('/about', 2),
        ('/cars', 1),
        ('/', 0),
      ]) {
        await open(tester, path);
        expect(selectedIndex(tester), index, reason: path);
      }
    });

    testWidgets('the search and the filter of the catalog are kept across '
        'tabs', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Cars');
      await tester.enterText(find.byType(TextField), 'skoda');
      containerOf(tester).read(carFilterProvider.notifier).reset();
      await settle(tester);
      expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
      expect(find.text('Fiat 500, 2020'), findsNothing);

      await tapTab(tester, 'FAQ');
      await tapTab(tester, 'Cars');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'skoda',
      );
      expect(find.text('Fiat 500, 2020'), findsNothing);
    });
  });

  group('the pages outside the tabs', () {
    testWidgets('a car card opens the car without the bar; Back returns to '
        'the catalog', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Cars');
      // In a narrow window the second card may lie under the bottom bar.
      await tester.ensureVisible(find.text('Skoda Octavia, 2020'));
      await settle(tester);
      await tester.tap(find.text('Skoda Octavia, 2020'));
      await settle(tester);

      expect(address(tester), '/cars/skoda');
      expect(find.byType(CarDetailScreen), findsOneWidget);
      expect(bar, findsNothing);

      await tester.pageBack();
      await settle(tester);
      expect(address(tester), '/cars');
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(bar, findsOneWidget);
    });

    testWidgets('the booking form has no bar; Back returns to the car', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/cars/fiat');
      await tester.tap(find.widgetWithText(FilledButton, 'Make a booking'));
      await settle(tester);

      expect(address(tester), '/cars/fiat/book');
      expect(find.byType(BookingFormScreen), findsOneWidget);
      expect(bar, findsNothing);

      await tester.pageBack();
      await settle(tester);
      expect(find.byType(CarDetailScreen), findsOneWidget);
    });

    testWidgets('a direct link to a car: no bar; Back leads to the catalog', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/cars/fiat');
      expect(find.byType(CarDetailScreen), findsOneWidget);
      expect(bar, findsNothing);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/cars');
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('the thank-you page without a sent booking goes to the '
        'catalog', (tester) async {
      await pumpApp(tester);
      await open(tester, '/booking-sent');
      await settle(tester);
      expect(address(tester), '/cars');
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('the thank-you page: no bar; "Back to the cars" opens the '
        'catalog', (tester) async {
      await pumpApp(tester);
      containerOf(tester).read(sentBookingProvider.notifier).set(sent());
      await open(tester, '/booking-sent');
      expect(find.byType(BookingSentScreen), findsOneWidget);
      expect(bar, findsNothing);

      final back = find.widgetWithText(FilledButton, 'Back to the cars');
      await tester.ensureVisible(back);
      await tester.tap(back);
      await settle(tester);
      expect(address(tester), '/cars');
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('the thank-you page: Android Back opens the catalog', (
      tester,
    ) async {
      await pumpApp(tester);
      containerOf(tester).read(sentBookingProvider.notifier).set(sent());
      await open(tester, '/booking-sent');
      expect(find.byType(BookingSentScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/cars');
      expect(find.byType(CatalogScreen), findsOneWidget);
    });
  });

  group('Android Back on the tabs (tests run as Android, not web)', () {
    for (final (label, path) in [
      ('Cars', '/cars'),
      ('Contact', '/about'),
      ('FAQ', '/faq'),
    ]) {
      testWidgets('from $label to Home', (tester) async {
        await pumpApp(tester);
        await tapTab(tester, label);
        expect(address(tester), path);

        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(address(tester), '/');
        expect(selectedIndex(tester), 0);
      });
    }
  });

  group('the hidden admin entry and the admin area', () {
    testWidgets('a long press on the logo opens the admin login from every '
        'tab; a tap does nothing', (tester) async {
      await pumpApp(tester);
      for (final path in ['/', '/cars', '/about', '/faq']) {
        await open(tester, path);
        await tester.tap(find.byType(AppBarLogo));
        await settle(tester);
        expect(address(tester), path, reason: 'tap on $path');

        await tester.longPress(find.byType(AppBarLogo));
        await settle(tester);
        expect(find.byType(AdminLoginScreen), findsOneWidget, reason: path);
        expect(bar, findsNothing, reason: path);
      }
    });

    testWidgets('the back arrow of the admin login goes to Home', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/login');
      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);
      expect(address(tester), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the admin area never shows the public bar; Back from it '
        'leads to Home', (tester) async {
      await pumpApp(tester, session: AdminSession.admin);
      await open(tester, '/admin');
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.text('Contact')),
        findsNothing,
      );

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(address(tester), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('320 px wide: nothing overflows on any tab', (tester) async {
    await pumpApp(tester, size: const Size(320, 640));
    for (final path in ['/', '/cars', '/about', '/faq']) {
      await open(tester, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}
