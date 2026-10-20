import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';

/// A made-up car, marked popular unless told otherwise.
Car homeCar(
  String id, {
  String brand = 'Brand',
  String model = 'Model',
  double price = 40,
  bool popular = true,
  List<String> photos = const [],
}) => Car(
  id: id,
  brand: brand,
  model: model,
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: price,
  description: const LocalizedText(
    ka: 'გამოგონილი მანქანა.',
    ru: 'Выдуманная машина.',
    en: 'A made-up car.',
  ),
  photos: photos,
  active: true,
  popular: popular,
);

/// Three made-up popular cars and one that is not marked.
final homeCars = [
  homeCar('car-b', brand: 'Brand B', price: 50),
  homeCar('car-a', brand: 'Brand A', price: 30),
  homeCar('car-c', brand: 'Brand C', price: 70),
  homeCar('car-plain', brand: 'Brand D', popular: false),
];

/// The real app router on Home, at [size] and [textScale], in [language].
/// The live cars are [cars] (an error with [carsError], nothing yet with
/// [carsPending]); the car page reads them too.
Future<void> pumpHome(
  WidgetTester tester, {
  List<Car>? cars,
  Object? carsError,
  bool carsPending = false,
  Size size = const Size(400, 900),
  double textScale = 1,
  String language = 'en',
}) async {
  final shown = cars ?? homeCars;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository();
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        activeCarsProvider.overrideWith(
          (ref) => carsPending
              ? const Stream<List<Car>>.empty()
              : carsError != null
              ? Stream<List<Car>>.error(carsError)
              : Stream.value(shown),
        ),
        carProvider.overrideWith(
          (ref, carId) => Stream.value(shown.firstWhere((c) => c.id == carId)),
        ),
        // For the booking form: made-up prices and one made-up place.
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
      ],
      child: _App(language: language, textScale: textScale),
    ),
  );
  await settleHome(tester);
}

Future<void> settleHome(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _App extends ConsumerWidget {
  const _App({required this.language, required this.textScale});

  final String language;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: buildAppTheme(),
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );
  }
}

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(_App)),
).read(appRouterProvider);

/// The selected tab of the bottom bar, or null without a bar.
int? selectedTab(WidgetTester tester) {
  final bar = find.byType(NavigationBar);
  return bar.evaluate().isEmpty
      ? null
      : tester.widget<NavigationBar>(bar).selectedIndex;
}

/// The texts of the current language, for finders.
AppLocalizations homeTexts(String language) =>
    lookupAppLocalizations(Locale(language));

/// The address the router reports to the browser (the address bar).
String browserAddress(WidgetTester tester) {
  final router = routerOf(tester);
  return router.routeInformationParser
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)!
      .uri
      .toString();
}
