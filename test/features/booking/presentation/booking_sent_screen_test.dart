import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const thanksText =
    'Thank you for your trust — our representative will contact you '
    'shortly to confirm the details.';
const individualNote =
    'For rentals longer than 7 days, the price is individual — our team '
    'will contact you to confirm the final price.';
const unknownPlace = 'A place from our list';

const car = Car(
  id: 'car-1',
  brand: 'Toyota',
  model: 'Prius',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.hybrid,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: LocalizedText(en: 'A good car.'),
  photos: [],
  active: true,
);

const locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(
      en: 'Tbilisi Airport',
      ru: 'Аэропорт Тбилиси',
      ka: 'თბილისის აეროპორტი',
    ),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Tbilisi Office'),
  ),
];

/// A sent booking. Pickup on 10 January 2026 at 18:00 Tbilisi time (14:00
/// UTC) and, by default, dropoff on the 15th at 20:00: 5 days.
SentBooking sentBooking({
  String fullName = 'Nino Beridze',
  bool whatsapp = false,
  bool telegram = false,
  DateTime? dropoff,
  BookingLocation pickupLocation = const BookingLocation.fixed(
    'tbilisiAirport',
  ),
  BookingLocation dropoffLocation = const BookingLocation.other(
    'Hotel in Batumi',
  ),
  Set<Extra> extras = const {Extra.childSeat, Extra.snowChains},
  String notes = '',
  double totalPrice = 272.5,
}) {
  return SentBooking(
    id: 'document-1',
    car: car,
    booking: Booking(
      customer: BookingCustomer(
        fullName: fullName,
        phone: '+995555123456',
        whatsapp: whatsapp,
        telegram: telegram,
        email: 'nino@example.com',
      ),
      carId: car.id,
      pickup: DateTime.utc(2026, 1, 10, 14),
      dropoff: dropoff ?? DateTime.utc(2026, 1, 15, 16),
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      extras: extras,
      notes: notes,
      totalPrice: totalPrice,
      language: AppLanguage.en,
      status: BookingStatus.newBooking,
    ),
  );
}

/// The real router and screens; the Firestore streams are replaced.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: buildAppTheme(),
      locale: Locale(ref.watch(appLanguageProvider).code),
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

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

/// Opens the thank-you screen as the form does after a successful sending:
/// [sent] is put into the provider first. With [sent] null the screen is
/// opened without a sent booking.
Future<void> pumpSent(
  WidgetTester tester,
  SentBooking? sent, {
  Size size = const Size(800, 2400),
  AppLanguage language = AppLanguage.en,
  Stream<List<PickupLocation>> Function()? locationsStream,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        activeCarsProvider.overrideWith((ref) => Stream.value([car])),
        pickupLocationsProvider.overrideWith(
          (ref) => locationsStream?.call() ?? Stream.value(locations),
        ),
      ],
      child: const _App(),
    ),
  );
  final container = containerOf(tester);
  container.read(appLanguageProvider.notifier).setLanguage(language);
  if (sent != null) container.read(sentBookingProvider.notifier).set(sent);
  container.read(appRouterProvider).go(AppRoutes.bookingSent);
  await settle(tester);
}

void main() {
  testWidgets('shows the thank-you sentence and the summary of the sent '
      'booking', (tester) async {
    await pumpSent(tester, sentBooking());

    expect(find.text(thanksText), findsOneWidget);
    expect(find.text('Your request'), findsOneWidget);
    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    // The stored UTC moments, shown as Tbilisi time.
    expect(find.text('10.01.2026 18:00'), findsOneWidget);
    expect(find.text('15.01.2026 20:00'), findsOneWidget);
    expect(find.text('Rental days'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('\$272.50'), findsOneWidget);

    expect(find.text('Your details'), findsOneWidget);
    expect(find.text('Nino Beridze'), findsOneWidget);
    expect(find.text('+995555123456'), findsOneWidget);
    expect(find.text('nino@example.com'), findsOneWidget);

    // The document ID is not shown.
    expect(find.textContaining('document-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each date has the line "Tbilisi time (GMT+4)"', (tester) async {
    await pumpSent(tester, sentBooking());
    expect(find.text('Tbilisi time (GMT+4)'), findsNWidgets(2));
  });

  testWidgets('a fixed place shows its name; "other" shows the typed text', (
    tester,
  ) async {
    await pumpSent(tester, sentBooking());

    expect(find.text('Tbilisi Airport'), findsOneWidget);
    expect(find.text('Hotel in Batumi'), findsOneWidget);
    expect(find.text('tbilisiAirport'), findsNothing);
    expect(find.text(unknownPlace), findsNothing);
  });

  testWidgets('the chosen extras are listed in the usual order', (
    tester,
  ) async {
    await pumpSent(tester, sentBooking());

    expect(find.text('Snow chains'), findsOneWidget);
    expect(find.text('Child seat'), findsOneWidget);
    expect(find.text('Infant seat'), findsNothing);
    expect(find.text('None'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Snow chains')).dy,
      lessThan(tester.getTopLeft(find.text('Child seat')).dy),
    );
  });

  testWidgets('without extras the row says "None"', (tester) async {
    await pumpSent(tester, sentBooking(extras: const {}));

    expect(find.text('Extras'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('exactly 7 days: "Total", no note', (tester) async {
    await pumpSent(
      tester,
      sentBooking(dropoff: DateTime.utc(2026, 1, 17, 14), totalPrice: 315),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Estimated total'), findsNothing);
    expect(find.text(individualNote), findsNothing);
  });

  testWidgets('a rental over 7 days: "Estimated total" and the note', (
    tester,
  ) async {
    await pumpSent(
      tester,
      sentBooking(dropoff: DateTime.utc(2026, 1, 17, 17), totalPrice: 360),
    );

    expect(find.text('8'), findsOneWidget);
    expect(find.text('Total'), findsNothing);
    expect(find.text('Estimated total'), findsOneWidget);
    expect(find.text('\$360'), findsOneWidget);
    expect(find.text(individualNote), findsOneWidget);
  });

  testWidgets('the total is the stored one, not a new calculation', (
    tester,
  ) async {
    // 5 days of this car would be 225 or more; the stored total is shown
    // as it is, whatever the prices in settings are now (even 0).
    await pumpSent(tester, sentBooking(totalPrice: 100));

    expect(find.text('\$100'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  testWidgets('WhatsApp and Telegram are shown only when ticked', (
    tester,
  ) async {
    await pumpSent(tester, sentBooking());
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Telegram'), findsNothing);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
    await settle(tester);
    await pumpSent(tester, sentBooking(whatsapp: true, telegram: true));
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
  });

  testWidgets('the notes row appears only when there are notes', (
    tester,
  ) async {
    await pumpSent(tester, sentBooking());
    expect(find.text('Special requests'), findsNothing);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
    await settle(tester);
    await pumpSent(tester, sentBooking(notes: 'Late arrival'));
    expect(find.text('Special requests'), findsOneWidget);
    expect(find.text('Late arrival'), findsOneWidget);
  });

  testWidgets('a language switch changes the labels, extras and place '
      'names, not the data', (tester) async {
    final sent = sentBooking(
      pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
      dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
    );
    await pumpSent(tester, sent);

    final container = containerOf(tester);
    container.read(appLanguageProvider.notifier).setLanguage(AppLanguage.ru);
    await settle(tester);

    expect(find.text('Ваша заявка'), findsOneWidget);
    expect(find.text('Your request'), findsNothing);
    expect(find.text('Аэропорт Тбилиси'), findsOneWidget);
    // No Russian name: the English one is shown.
    expect(find.text('Tbilisi Office'), findsOneWidget);
    expect(find.text('Детское кресло'), findsOneWidget);
    expect(find.text('Время Тбилиси (GMT+4)'), findsNWidgets(2));

    expect(find.text('Toyota Prius, 2019'), findsOneWidget);
    expect(find.text('10.01.2026 18:00'), findsOneWidget);
    expect(find.text('Nino Beridze'), findsOneWidget);
    expect(find.text('\$272.50'), findsOneWidget);
    // The stored booking keeps the language it was sent in.
    expect(sent.booking.language, AppLanguage.en);
    expect(container.read(sentBookingProvider), same(sent));
  });

  testWidgets('settings not loaded yet: the neutral place text, no spinner; '
      'the name appears when it arrives', (tester) async {
    final controller = StreamController<List<PickupLocation>>();
    addTearDown(controller.close);

    await pumpSent(
      tester,
      sentBooking(),
      locationsStream: () => controller.stream,
    );

    expect(find.text(thanksText), findsOneWidget);
    expect(find.text(unknownPlace), findsOneWidget);
    expect(find.text('Hotel in Batumi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    controller.add(locations);
    await settle(tester);
    expect(find.text(unknownPlace), findsNothing);
    expect(find.text('Tbilisi Airport'), findsOneWidget);
  });

  testWidgets('settings cannot be loaded: the neutral place text, no error '
      'message', (tester) async {
    await pumpSent(
      tester,
      sentBooking(),
      locationsStream: () => Stream.error(const FormatException('no places')),
    );

    expect(find.text(thanksText), findsOneWidget);
    expect(find.text(unknownPlace), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('\$272.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a place that is no longer in settings: the neutral place '
      'text, never the id', (tester) async {
    await pumpSent(
      tester,
      sentBooking(
        pickupLocation: const BookingLocation.fixed('kutaisiAirport'),
        dropoffLocation: const BookingLocation.fixed('batumiAirport'),
      ),
    );

    expect(find.text(unknownPlace), findsNWidgets(2));
    expect(find.text('kutaisiAirport'), findsNothing);
    expect(find.text('batumiAirport'), findsNothing);
  });

  testWidgets('"Back to the cars" opens the catalog and the sent booking is '
      'forgotten', (tester) async {
    await pumpSent(tester, sentBooking());
    expect(containerOf(tester).read(sentBookingProvider), isNotNull);

    await tester.tap(find.text('Back to the cars'));
    await settle(tester);

    expect(find.byType(BookingSentScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(containerOf(tester).read(sentBookingProvider), isNull);
  });

  testWidgets('the back arrow also leaves and forgets the sent booking', (
    tester,
  ) async {
    await pumpSent(tester, sentBooking());

    await tester.pageBack();
    await settle(tester);

    expect(find.byType(BookingSentScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(containerOf(tester).read(sentBookingProvider), isNull);
  });

  testWidgets('opened without a sent booking: goes to the catalog', (
    tester,
  ) async {
    await pumpSent(tester, null);
    await settle(tester);

    expect(find.byType(BookingSentScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(find.text(thanksText), findsNothing);
  });

  group('320 px wide', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.code}: long texts, all extras and a long '
          'rental do not overflow', (tester) async {
        final longName = List.filled(10, 'Konstantine').join(' ');
        final longAddress = 'Rustaveli Avenue 12, ' * 10;
        await pumpSent(
          tester,
          sentBooking(
            fullName: longName.substring(0, 100),
            whatsapp: true,
            telegram: true,
            dropoff: DateTime.utc(2026, 2, 10, 14),
            pickupLocation: BookingLocation.other(
              longAddress.substring(0, 200).trim(),
            ),
            dropoffLocation: const BookingLocation.fixed('tbilisiAirport'),
            extras: Extra.values.toSet(),
            notes: ('note ' * 100).trim(),
            totalPrice: 123456.78,
          ),
          size: const Size(320, 4200),
          language: language,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(BookingSentScreen), findsOneWidget);
        expect(find.text('\$123456.78'), findsOneWidget);
      });
    }
  });
}
