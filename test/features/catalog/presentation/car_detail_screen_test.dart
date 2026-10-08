import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const _carId = 'car-1';
const _notAvailableText = 'This car is not available';
const _errorText = 'Could not load the car. Please try again later.';
const _descriptionText = 'Economical hybrid, ideal for city driving.';

Car car({
  List<String> photos = const [],
  LocalizedText description = const LocalizedText(en: _descriptionText),
}) {
  return Car(
    id: _carId,
    brand: 'Toyota',
    model: 'Prius',
    year: 2019,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: FuelType.hybrid,
    seats: 5,
    engineSize: 1.8,
    pricePerDay: 45,
    description: description,
    photos: photos,
    active: true,
  );
}

/// Shows the real detail screen with [stream] in place of the Firestore
/// stream. [stream] is called each time the screen asks for the car.
Future<void> pumpDetail(
  WidgetTester tester,
  Stream<Car> Function() stream,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [carProvider(_carId).overrideWith((ref) => stream())],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CarDetailScreen(carId: _carId),
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

Finder bookingButton() => find.widgetWithText(FilledButton, 'Make a booking');

/// The gallery's position text for screen readers, such as "Photo 1 of 3".
Finder galleryPosition(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

/// Any gallery position text at all.
Finder anyGalleryPosition() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label ?? '').startsWith('Photo '),
);

void main() {
  testWidgets('shows a spinner while the car is loading', (tester) async {
    final controller = StreamController<Car>();
    addTearDown(controller.close);

    await pumpDetail(tester, () => controller.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(bookingButton(), findsNothing);
  });

  testWidgets('shows the car and a disabled booking button', (tester) async {
    await pumpDetail(tester, () => Stream.value(car()));

    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    expect(find.text('\$45 / day'), findsOneWidget);
    expect(find.text('5 seats'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
    expect(find.text('FWD'), findsOneWidget);
    expect(find.text('1.8 L'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text(_descriptionText), findsOneWidget);

    expect(bookingButton(), findsOneWidget);
    expect(tester.widget<FilledButton>(bookingButton()).onPressed, isNull);
    expect(find.text('Online booking is coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a car without photos and description: placeholder, no section', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      () => Stream.value(car(description: const LocalizedText())),
    );

    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    // The placeholder is the car icon, labelled "No photo" for screen readers.
    final placeholder = find.byIcon(Icons.directions_car);
    expect(placeholder, findsOneWidget);
    expect(tester.widget<Icon>(placeholder).semanticLabel, 'No photo');
    expect(find.text('Description'), findsNothing);
  });

  testWidgets('a car with several photos shows the gallery position', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      () => Stream.value(
        car(
          photos: const [
            'https://example.com/1.jpg',
            'https://example.com/2.jpg',
            'https://example.com/3.jpg',
          ],
        ),
      ),
    );

    expect(galleryPosition('Photo 1 of 3'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('a car with one photo has no gallery dots', (tester) async {
    await pumpDetail(
      tester,
      () => Stream.value(car(photos: const ['https://example.com/1.jpg'])),
    );

    expect(find.byType(PageView), findsNothing);
    expect(anyGalleryPosition(), findsNothing);
  });

  testWidgets('a car that is not available: one message and a way back', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      () => Stream<Car>.error(const CarNotAvailableException()),
    );

    expect(find.text(_notAvailableText), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Back to the cars'), findsOne);
    expect(find.text('Try again'), findsNothing);
    expect(find.text(_errorText), findsNothing);
    expect(bookingButton(), findsNothing);
  });

  testWidgets('another error: "Try again" asks for the car again', (
    tester,
  ) async {
    var requests = 0;

    await pumpDetail(tester, () {
      requests++;
      return requests == 1
          ? Stream<Car>.error(Exception('no connection'))
          : Stream.value(car());
    });

    expect(find.text(_errorText), findsOneWidget);
    expect(find.text(_notAvailableText), findsNothing);
    expect(bookingButton(), findsNothing);
    expect(requests, 1);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(requests, 2);
    expect(find.text(_errorText), findsNothing);
    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
  });

  testWidgets('320 px wide: nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDetail(tester, () => Stream.value(car()));

    expect(tester.takeException(), isNull);
    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    expect(bookingButton(), findsOneWidget);
  });
}
