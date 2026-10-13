import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_search_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_search_field.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/filters_button.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const _errorText = 'Could not load the cars. Please try again later.';
const _emptyText = 'No cars available yet';
const _noMatchText = 'No cars match your filters';
const _noSearchMatchText = 'No cars match your search';

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

Stream<List<Car>> twoCars() => Stream.value([
  car(id: 'a', brand: 'Fiat', model: '500'),
  car(id: 'b', brand: 'Skoda', model: 'Octavia'),
]);

/// Shows the real catalog screen with [cars] in place of the Firestore
/// stream. [cars] is called each time the screen asks for the stream.
Future<void> pumpCatalog(
  WidgetTester tester,
  Stream<List<Car>> Function() cars, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [activeCarsProvider.overrideWith((ref) => cars())],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: locale,
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

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));

String searchFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

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
    // Only the translated text: nothing technical, also in a debug build.
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('no connection'), findsNothing);

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
    await pumpCatalog(tester, twoCars);

    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    // Both test cars run on petrol, so "Electric" matches none of them.
    containerOf(
      tester,
    ).read(carFilterProvider.notifier).setFuelType(FuelType.electric);
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

  testWidgets('search with no match: the search text and "Clear search"', (
    tester,
  ) async {
    await pumpCatalog(tester, twoCars);

    await tester.enterText(find.byType(TextField), 'skoda');
    await settle(tester);

    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Fiat 500, 2020'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);

    expect(find.text(_noSearchMatchText), findsOneWidget);
    expect(find.text(_noMatchText), findsNothing);
    expect(find.text('Filters'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear search'));
    await settle(tester);

    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(searchFieldText(tester), '');
  });

  testWidgets('"Reset filters" clears the search and the filters', (
    tester,
  ) async {
    await pumpCatalog(tester, twoCars);
    final container = containerOf(tester);

    // The filter alone still matches both cars; the search matches none.
    container
        .read(carFilterProvider.notifier)
        .setTransmission(Transmission.manual);
    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);

    expect(find.text(_noMatchText), findsOneWidget);
    expect(find.text(_noSearchMatchText), findsNothing);
    expect(find.text('Filters (1)'), findsOneWidget);

    await tester.tap(find.text('Reset filters'));
    await settle(tester);

    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(searchFieldText(tester), '');
    expect(container.read(carSearchProvider), '');
  });

  testWidgets('a search of only spaces behaves like an empty search', (
    tester,
  ) async {
    await pumpCatalog(tester, twoCars);

    await tester.enterText(find.byType(TextField), '   ');
    await settle(tester);

    expect(find.text('Fiat 500, 2020'), findsOneWidget);
    expect(find.text('Skoda Octavia, 2020'), findsOneWidget);
    expect(find.text(_noSearchMatchText), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Clear search'), findsNothing);
  });

  testWidgets('the sheet button counts cars with filters and search together', (
    tester,
  ) async {
    await pumpCatalog(tester, twoCars);

    // Both cars match the filter; only one of them matches the search.
    containerOf(
      tester,
    ).read(carFilterProvider.notifier).setTransmission(Transmission.manual);
    await tester.enterText(find.byType(TextField), 'skoda');
    await settle(tester);

    await tester.tap(find.byType(FiltersButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Show cars (1)'), findsOneWidget);
    expect(find.text('Show cars (2)'), findsNothing);
  });

  testWidgets('the search field and the Filters button have the same height', (
    tester,
  ) async {
    await pumpCatalog(tester, twoCars);

    // The visible boxes: the white field and the outlined button shape.
    final field = tester.getRect(find.byType(InputDecorator));
    final button = tester.getRect(
      find
          .descendant(
            of: find.byType(FiltersButton),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(button.height, field.height);
    expect(button.top, field.top);
    expect(button.bottom, field.bottom);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('320 px wide, ${locale.languageCode}: the search row does not '
        'overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpCatalog(tester, twoCars, locale: locale);
      expect(tester.takeException(), isNull);

      // Two filters that both test cars match, so the cars stay visible and
      // the button shows its longest label.
      final filter = containerOf(tester).read(carFilterProvider.notifier);
      filter.setFuelType(FuelType.petrol);
      filter.setTransmission(Transmission.manual);
      await settle(tester);

      final l10n = lookupAppLocalizations(locale);
      expect(find.text(l10n.filtersWithCount(2)), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The button ends inside the screen (12 px page padding on the right).
      final button = tester.getRect(find.byType(FiltersButton));
      expect(button.right, lessThanOrEqualTo(320 - 12));
      final field = tester.getRect(find.byType(CatalogSearchField));
      expect(field.left, greaterThanOrEqualTo(12));
      expect(field.right, lessThanOrEqualTo(button.left));
      expect(field.width, greaterThan(0));

      // With text in the field the "x" button appears; still no overflow.
      await tester.enterText(find.byType(TextField), 'fiat');
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  // The real path of the answers: activeCarsFrom decides what an empty
  // answer means. Only Firestore itself is replaced.
  group('without a connection', () {
    const fiat = <String, dynamic>{
      'brand': 'Fiat',
      'model': '500',
      'year': 2020,
      'drivetrain': 'fwd',
      'transmission': 'manual',
      'fuelType': 'petrol',
      'seats': 4,
      'pricePerDay': 40,
      'active': true,
    };

    late List<StreamController<CarsAnswer>> queries;

    /// Opens the catalog; every request for the cars is a new query.
    Future<void> pumpOffline(WidgetTester tester) async {
      queries = [];
      await pumpCatalog(tester, () {
        final query = StreamController<CarsAnswer>();
        addTearDown(query.close);
        queries.add(query);
        return activeCarsFrom(query.stream);
      });
    }

    Future<void> answer(
      WidgetTester tester, {
      required bool fromCache,
      bool withCar = false,
    }) async {
      queries.last.add((
        documents: [if (withCar) (id: 'a', data: fiat)],
        fromCache: fromCache,
      ));
      await settle(tester);
    }

    testWidgets('an empty answer that is not from the server: a spinner, '
        'never "no cars"', (tester) async {
      await pumpOffline(tester);
      await answer(tester, fromCache: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_emptyText), findsNothing);
      expect(find.text(_errorText), findsNothing);

      // Let the wait run out before the test ends.
      await tester.pump(serverAnswerWait);
    });

    testWidgets('after 3 seconds: the error text with "Try again", and '
        'nothing technical', (tester) async {
      await pumpOffline(tester);
      await answer(tester, fromCache: true);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(find.text(_errorText), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);

      expect(find.text(_errorText), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text(_emptyText), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('the server answers later: the cars appear by themselves', (
      tester,
    ) async {
      await pumpOffline(tester);
      await answer(tester, fromCache: true);
      await tester.pump(serverAnswerWait);
      await settle(tester);
      expect(find.text(_errorText), findsOneWidget);

      await answer(tester, fromCache: false, withCar: true);

      expect(find.text(_errorText), findsNothing);
      expect(find.text('Fiat 500, 2020'), findsOneWidget);
      expect(queries, hasLength(1));
    });

    testWidgets('the server says there are no cars: the empty text', (
      tester,
    ) async {
      await pumpOffline(tester);
      await answer(tester, fromCache: true);
      await answer(tester, fromCache: false);

      expect(find.text(_emptyText), findsOneWidget);
      expect(find.text(_errorText), findsNothing);

      await tester.pump(serverAnswerWait);
      await settle(tester);
      expect(find.text(_emptyText), findsOneWidget);
    });

    testWidgets('"Try again": a spinner and a new request; still nothing: '
        'the error text again; then the cars', (tester) async {
      await pumpOffline(tester);
      await answer(tester, fromCache: true);
      await tester.pump(serverAnswerWait);
      await settle(tester);

      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(queries, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_errorText), findsNothing);

      await answer(tester, fromCache: true);
      await tester.pump(serverAnswerWait);
      await settle(tester);
      expect(find.text(_errorText), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await settle(tester);
      await answer(tester, fromCache: false, withCar: true);
      expect(queries, hasLength(3));
      expect(find.text('Fiat 500, 2020'), findsOneWidget);
    });
  });
}
