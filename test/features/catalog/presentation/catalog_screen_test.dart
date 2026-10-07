import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const _errorText = 'Could not load the cars. Please try again later.';
const _emptyText = 'No cars available yet';
const _noMatchText = 'No cars match your filters';

/// A test car without photos, so the test makes no network request.
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
    description: const LocalizedText(),
    photos: const [],
    active: true,
  );
}

/// Shows the real catalog screen with [cars] in place of the Firestore
/// stream. [cars] is called each time the screen asks for the stream.
Future<void> pumpCatalog(
  WidgetTester tester,
  Stream<List<Car>> Function() cars,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [activeCarsProvider.overrideWith((ref) => cars())],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CatalogScreen(),
      ),
    ),
  );
  await settle(tester);
}

/// Lets the localization load and the stream deliver. pumpAndSettle is not
/// used because the loading spinner never stops animating.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows a spinner while the cars are loading', (tester) async {
    final controller = StreamController<List<Car>>();
    addTearDown(controller.close);

    await pumpCatalog(tester, () => controller.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
    expect(find.text(_emptyText), findsNothing);
  });

  testWidgets('error state: "Try again" asks for the cars again', (
    tester,
  ) async {
    var requests = 0;

    await pumpCatalog(tester, () {
      requests++;
      return requests == 1
          ? Stream<List<Car>>.error(Exception('no connection'))
          : Stream.value(<Car>[]);
    });

    expect(find.text(_errorText), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(requests, 1);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(requests, 2);
    expect(find.text(_errorText), findsNothing);
    expect(find.text(_emptyText), findsOneWidget);
  });

  testWidgets('no cars at all: the empty text and no Filters button', (
    tester,
  ) async {
    await pumpCatalog(tester, () => Stream.value(<Car>[]));

    expect(find.text(_emptyText), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no match: the text, and "Reset filters" brings the cars back', (
    tester,
  ) async {
    await pumpCatalog(
      tester,
      () => Stream.value([
        car(id: 'a', brand: 'Fiat', model: '500'),
        car(id: 'b', brand: 'Skoda', model: 'Octavia'),
      ]),
    );

    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    // Both test cars run on petrol, so "Electric" matches none of them.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatalogScreen)),
    );
    container.read(carFilterProvider.notifier).setFuelType(FuelType.electric);
    await settle(tester);

    expect(find.text(_noMatchText), findsOneWidget);
    expect(find.text('Filters (1)'), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsNothing);
    expect(find.text(_emptyText), findsNothing);

    await tester.tap(find.text('Reset filters'));
    await settle(tester);

    expect(find.text(_noMatchText), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
  });
}
