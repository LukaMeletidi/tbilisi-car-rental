import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict dialog of the "new booking" form (step 5.3), with the real
/// router. Every value is made up.
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

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

/// Opens the form and fills it: car-1, 9 to 14 Oct 2026 16:00 in Tbilisi,
/// with [status].
Future<void> openAndFill(
  WidgetTester tester, {
  BookingStatus status = BookingStatus.confirmed,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  bookings = FakeAdminBookingsRepository()..cars = [testCar()];
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 9, 12)),
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
  containerOf(tester).read(appRouterProvider).go('/admin/bookings/new');
  await settle(tester);

  final notifier = containerOf(tester).read(adminBookingNewProvider.notifier);
  final draft = containerOf(tester).read(adminBookingNewProvider).draft;
  notifier.setDraft(
    draft.copyWith(
      status: status,
      fields: draft.fields.copyWith(
        carId: 'car-1',
        input: draft.fields.input.copyWith(
          fullName: 'Create Test One',
          phone: '+995555000001',
          email: 'one@example.com',
          pickup: TbilisiDateTime(2026, 10, 9, 16, 0),
          dropoff: TbilisiDateTime(2026, 10, 14, 16, 0),
          pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
          dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
        ),
      ),
    ),
  );
  await settle(tester);
}

/// A stored confirmed booking of car-1 that overlaps the form's times.
Booking clash() => Booking.fromMap(
  'other',
  rawBooking(
    'other',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 10, 10, 10),
    dropoff: DateTime.utc(2026, 10, 11, 10),
  ).data,
);

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, adminSave);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await settle(tester);
}

void main() {
  testWidgets('a conflict: the dialog; Cancel keeps the form', (tester) async {
    await openAndFill(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [clash()],
      unreadable: 0,
    );
    await tapSave(tester);
    expect(find.text(adminConflictTitle), findsOneWidget);

    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(bookings.creates, isEmpty);
    expect(find.byType(AdminBookingNewScreen), findsOneWidget);
    final state = containerOf(tester).read(adminBookingNewProvider);
    expect(state.draft.fields.input.fullName, 'Create Test One');
    expect(state.canEdit, true);
  });

  testWidgets('Continue anyway: created, the detail opens', (tester) async {
    await openAndFill(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [clash()],
      unreadable: 0,
    );
    await tapSave(tester);
    await tester.tap(find.text(adminContinueAnyway));
    await settle(tester);
    expect(bookings.creates, hasLength(1));
    expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
  });

  testWidgets('saved as "new": no check, no dialog', (tester) async {
    await openAndFill(tester, status: BookingStatus.newBooking);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [clash()],
      unreadable: 0,
    );
    await tapSave(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.confirmedReads, isEmpty);
    expect(bookings.creates, hasLength(1));
  });
}
