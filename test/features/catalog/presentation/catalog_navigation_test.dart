import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
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

/// The real router with the catalog and the detail screen. Both Firestore
/// streams are replaced, so nothing contacts Firebase.
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
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          activeCarsProvider.overrideWith((ref) => Stream.value(_cars)),
          carProvider.overrideWith(
            (ref, carId) =>
                Stream.value(_cars.firstWhere((car) => car.id == carId)),
          ),
        ],
        child: const _App(),
      ),
    );
    await settle(tester);

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
}
