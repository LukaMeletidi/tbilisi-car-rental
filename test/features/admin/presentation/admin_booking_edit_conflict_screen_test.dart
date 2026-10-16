import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict dialog of the edit form (step 5.3), with the real router.
/// Every value is made up.
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

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Office'),
  ),
];

const otherCar = Car(
  id: 'car-2',
  brand: 'Kia',
  model: 'Rio',
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.manual,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: 30,
  description: LocalizedText(),
  photos: [],
  active: true,
);

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Opens the edit form of the CONFIRMED booking "b1" (car-1) and changes
/// its car to the Kia, with the new total chosen.
Future<void> openAndChangeCar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  bookings = FakeAdminBookingsRepository()..cars = [testCar(), otherCar];
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1)),
        activeCarsProvider.overrideWith((ref) => Stream.value([testCar()])),
        pickupLocationsProvider.overrideWith((ref) => Stream.value(places)),
        extrasPricesProvider.overrideWith(
          (ref) => Stream.value(
            ExtrasPrices.fromMap({
              'pricesPerDay': {
                'snowChains': 5,
                'childSeat': 4,
                'infantSeat': 3,
                'boosterSeat': 2.5,
              },
            }),
          ),
        ),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_App)),
  );
  container.read(appRouterProvider).go('/admin/bookings/b1/edit');
  await settle(tester);
  bookings.emitBookingToAll(rawBooking('b1', status: 'confirmed'));
  await settle(tester);

  await tester.tap(find.text('Toyota Prius, 2019').first);
  await settle(tester);
  await tester.tap(find.text('Kia Rio, 2020').last);
  await settle(tester);
  final useNew = find.textContaining('Use the new total');
  await tester.ensureVisible(useNew);
  await tester.tap(useNew);
  await settle(tester);
}

/// A confirmed booking of the Kia that overlaps.
Booking clash() => Booking.fromMap(
  'other',
  rawBooking(
    'other',
    carId: 'car-2',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 1, 12, 10),
    dropoff: DateTime.utc(2026, 1, 13, 10),
  ).data,
);

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, adminSave);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await settle(tester);
}

void main() {
  testWidgets('a conflict: the dialog; Cancel keeps every field', (
    tester,
  ) async {
    await openAndChangeCar(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [clash()],
      unreadable: 0,
    );
    await tapSave(tester);
    expect(bookings.confirmedReads, ['car-2']);
    expect(find.text(adminConflictTitle), findsOneWidget);

    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.updates, isEmpty);
    // The form still shows the new car and the chosen total.
    expect(find.text('Kia Rio, 2020'), findsWidgets);
    expect(find.text(adminSave), findsOneWidget);
  });

  testWidgets('Continue anyway: saved, back to the detail with "Saved"', (
    tester,
  ) async {
    await openAndChangeCar(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [clash()],
      unreadable: 0,
    );
    await tapSave(tester);
    await tester.tap(find.text(adminContinueAnyway));
    await settle(tester);
    expect(bookings.updates.single.changes.values['carId'], 'car-2');
    expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
  });
}
