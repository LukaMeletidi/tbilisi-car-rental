import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

Car car({required String id, required String brand, required String model}) {
  return Car(
    id: id,
    brand: brand,
    model: model,
    year: 2020,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.manual,
    fuelType: FuelType.petrol,
    seats: 5,
    engineSize: 1.6,
    pricePerDay: 40,
    description: const LocalizedText(en: 'A good car.'),
    photos: const [],
    active: true,
  );
}

final _cars = [
  car(id: 'fiat', brand: 'Fiat', model: '500'),
  car(id: 'skoda', brand: 'Skoda', model: 'Octavia'),
];

final _prices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 5,
    'infantSeat': 5,
    'boosterSeat': 5,
  },
});

const _locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport'),
  ),
];

/// Starts the app on the catalog with every Firestore stream replaced, so
/// nothing contacts Firebase.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        activeCarsProvider.overrideWith((ref) => Stream.value(_cars)),
        carProvider.overrideWith(
          (ref, carId) =>
              Stream.value(_cars.firstWhere((car) => car.id == carId)),
        ),
        extrasPricesProvider.overrideWith((ref) => Stream.value(_prices)),
        pickupLocationsProvider.overrideWith((ref) => Stream.value(_locations)),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

/// The real router with the real screens.
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

void main() {
  testWidgets('a card opens the car; going back keeps the search text', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'skoda');
    await settle(tester);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsNothing);

    await tester.tap(find.text('Skoda Octavia, 2020'));
    await settle(tester);

    expect(find.byType(CarDetailScreen), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('A good car.'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Make a booking'), findsOne);

    await tester.pageBack();
    await settle(tester);

    expect(find.byType(CarDetailScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'skoda',
    );
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsNothing);
  });

  testWidgets('"Make a booking" opens the form; Back returns to the car', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Skoda Octavia, 2020'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Make a booking'));
    await settle(tester);

    expect(find.byType(BookingFormScreen), findsOneWidget);
    expect(find.text('Booking request'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);

    expect(find.byType(BookingFormScreen), findsNothing);
    expect(find.byType(CarDetailScreen), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('a direct link to the form: Back leads to the car', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_App)),
    );

    container.read(appRouterProvider).go(AppRoutes.booking('fiat'));
    await settle(tester);
    expect(find.byType(BookingFormScreen), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(BookingFormScreen), findsNothing);
    expect(find.byType(CarDetailScreen), findsOneWidget);
  });

  testWidgets('the thank-you screen without a sent booking goes to the '
      'catalog', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_App)),
    );

    container.read(appRouterProvider).go(AppRoutes.bookingSent);
    await settle(tester);
    await settle(tester);

    expect(find.byType(BookingSentScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(find.textContaining('Thank you'), findsNothing);
  });
}
