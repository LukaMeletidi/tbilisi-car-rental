import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/privacy_link.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/not_found_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/privacy_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../support/fake_admin_auth_repository.dart';

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

/// Never called: the tests never send.
class _NoBookingRepository implements BookingRepository {
  @override
  Future<String> createBooking(
    Booking booking, {
    Duration timeout = bookingCreateTimeout,
  }) => throw StateError('not used');
}

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

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository();
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        activeCarsProvider.overrideWith((ref) => Stream.value(const [car])),
        carProvider.overrideWith((ref, id) => Stream.value(car)),
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
              id: 'placeOne',
              name: LocalizedText(en: 'Place one'),
            ),
          ]),
        ),
        companyInfoProvider.overrideWith((ref) => Stream.value(null)),
        bookingRepositoryProvider.overrideWithValue(_NoBookingRepository()),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(_App)),
).read(appRouterProvider);

Future<void> open(WidgetTester tester, String address) async {
  routerOf(tester).go(address);
  await settle(tester);
}

/// What the router gives the browser: the address and its saved state.
RouteInformation browserInformation(WidgetTester tester) {
  final router = routerOf(tester);
  return router.routeInformationParser.restoreRouteInformation(
    router.routerDelegate.currentConfiguration,
  )!;
}

/// As Chrome's Back button: the engine sends the earlier address with the
/// state the router saved for it.
Future<void> browserBack(WidgetTester tester, RouteInformation to) async {
  const codec = JSONMethodCodec();
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    codec.encodeMethodCall(
      MethodCall('pushRouteInformation', {
        'location': to.uri.toString(),
        'state': to.state,
      }),
    ),
    (_) {},
  );
  await settle(tester);
}

Finder get bar => find.byType(NavigationBar);

Finder field(String label) => find.widgetWithText(TextField, label);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(field(label)).controller!.text;

Future<void> tapLink(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(privacyLinkKey));
  await settle(tester);
  await tester.tap(find.byKey(privacyLinkKey));
  await settle(tester);
}

/// Made-up values typed into the booking form.
Future<void> fillForm(WidgetTester tester) async {
  await tester.enterText(field(en.bookingFullName), 'Test Person');
  await tester.enterText(field(en.bookingPhone), '+995555000001');
  await tester.enterText(field(en.bookingEmail), 'test@example.com');
  await settle(tester);
}

void expectFormValues(WidgetTester tester) {
  expect(find.byType(BookingFormScreen), findsOneWidget);
  expect(textOf(tester, en.bookingFullName), 'Test Person');
  expect(textOf(tester, en.bookingPhone), '+995555000001');
  expect(textOf(tester, en.bookingEmail), 'test@example.com');
}

void main() {
  testWidgets('/privacy opened directly: the page, no bottom bar, no back '
      'arrow; Android Back goes to Home without an error', (tester) async {
    await pumpApp(tester);
    await open(tester, AppRoutes.privacy);
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(bar, findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('/privacy/x: the "not found" page (the catch-all stays last)', (
    tester,
  ) async {
    await pumpApp(tester);
    await open(tester, '${AppRoutes.privacy}/x');
    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.byType(PrivacyScreen), findsNothing);
  });

  testWidgets('from the Contact tab: the link opens the policy; Back returns '
      'to Contact with its tab selected', (tester) async {
    await pumpApp(tester);
    await open(tester, AppRoutes.about);
    await tapLink(tester);
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(browserInformation(tester).uri.toString(), AppRoutes.privacy);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 2);
  });

  testWidgets('from the booking form: the values stay after the policy and '
      'the back arrow', (tester) async {
    await pumpApp(tester);
    await open(tester, AppRoutes.booking(car.id));
    await fillForm(tester);
    await tapLink(tester);
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(browserInformation(tester).uri.toString(), AppRoutes.privacy);

    await tester.pageBack();
    await settle(tester);
    expectFormValues(tester);
  });

  testWidgets('from the booking form: the values stay after the browser\'s '
      'Back as well', (tester) async {
    await pumpApp(tester);
    await open(tester, AppRoutes.booking(car.id));
    await fillForm(tester);
    final formAddress = browserInformation(tester);
    await tapLink(tester);
    expect(find.byType(PrivacyScreen), findsOneWidget);

    await browserBack(tester, formAddress);
    expect(find.byType(PrivacyScreen), findsNothing);
    expectFormValues(tester);
  });

  testWidgets('"Go to the Contact page" opens the Contact tab', (tester) async {
    await pumpApp(tester);
    await open(tester, AppRoutes.privacy);
    await tester.ensureVisible(find.byKey(privacyGoToContactKey));
    await tester.tap(find.byKey(privacyGoToContactKey));
    await settle(tester);
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 2);
  });
}
