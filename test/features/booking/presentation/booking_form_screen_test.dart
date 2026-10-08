import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/date_time_field.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const carId = 'car-1';

const thanksText =
    'Thank you for your trust — our representative will contact you '
    'shortly to confirm the details.';
const loadErrorText =
    'Could not load the booking form. Please try again later.';
const individualNote =
    'For rentals longer than 7 days, the price is individual — our team '
    'will contact you to confirm the final price.';

const car = Car(
  id: carId,
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

ExtrasPrices prices({num snowChains = 5}) => ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': snowChains,
    'childSeat': 4,
    'infantSeat': 4.5,
    'boosterSeat': 3,
  },
});

/// Records what is sent and answers as the test tells it to. No Firebase.
class FakeBookingRepository implements BookingRepository {
  final sent = <Booking>[];
  Completer<String>? pending;
  Object? error;

  @override
  Future<String> createBooking(
    Booking booking, {
    Duration timeout = bookingCreateTimeout,
  }) {
    sent.add(booking);
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value('document-${sent.length}');
  }
}

/// The real router and screens. The car, the settings, the repository and
/// the clock are replaced, so nothing contacts Firebase.
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

late FakeBookingRepository repository;

/// 1 January 2026, 12:00 in Tbilisi.
DateTime now = DateTime.utc(2026, 1, 1, 8);

/// Lets streams deliver and animations move on. pumpAndSettle is not used
/// because a spinner never stops animating.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

BookingFormNotifier form(WidgetTester tester) =>
    containerOf(tester).read(bookingFormProvider(carId).notifier);

/// Opens the booking form of the car. The screen is tall by default, so the
/// whole form is visible without scrolling.
Future<void> pumpForm(
  WidgetTester tester, {
  Size size = const Size(800, 3200),
  AppLanguage language = AppLanguage.en,
  Stream<Car> Function()? carStream,
  Stream<ExtrasPrices> Function()? pricesStream,
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
        carProvider.overrideWith(
          (ref, id) => carStream?.call() ?? Stream.value(car),
        ),
        extrasPricesProvider.overrideWith(
          (ref) => pricesStream?.call() ?? Stream.value(prices()),
        ),
        pickupLocationsProvider.overrideWith(
          (ref) => locationsStream?.call() ?? Stream.value(locations),
        ),
        bookingRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const _App(),
    ),
  );
  final container = containerOf(tester);
  container.read(appLanguageProvider.notifier).setLanguage(language);
  container.read(appRouterProvider).go(AppRoutes.booking(carId));
  await settle(tester);
}

/// A complete, valid draft: 5 days, no extras, total $225.
void fillValidDraft(WidgetTester tester) {
  form(tester)
    ..setFullName('Nino Beridze')
    ..setPhone('+995 555 12 34 56')
    ..setEmail('nino@example.com')
    ..setPickup(TbilisiDateTime(2026, 1, 10, 18))
    ..setDropoff(TbilisiDateTime(2026, 1, 15, 20))
    ..setPickupLocation(const BookingLocation.fixed('tbilisiAirport'))
    ..setDropoffLocation(const BookingLocation.fixed('tbilisiOffice'));
}

Finder sendButton() => find.widgetWithText(FilledButton, 'Send request');

Finder field(String label) => find.widgetWithText(TextField, label);

Finder backArrow() => find.widgetWithIcon(IconButton, Icons.arrow_back);

Future<void> tapSend(WidgetTester tester) async {
  await tester.tap(sendButton());
  await settle(tester);
}

void main() {
  setUp(() {
    repository = FakeBookingRepository();
    now = DateTime.utc(2026, 1, 1, 8);
  });

  group('states', () {
    testWidgets('shows a spinner while the settings are loading', (
      tester,
    ) async {
      final controller = StreamController<ExtrasPrices>();
      addTearDown(controller.close);

      await pumpForm(tester, pricesStream: () => controller.stream);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(sendButton(), findsNothing);

      controller.add(prices());
      await settle(tester);
      expect(sendButton(), findsOneWidget);
    });

    testWidgets('a car that is not available: the message and the way back', (
      tester,
    ) async {
      await pumpForm(
        tester,
        carStream: () => Stream.error(const CarNotAvailableException()),
      );

      expect(find.text('This car is not available'), findsOneWidget);
      expect(sendButton(), findsNothing);

      await tester.tap(find.text('Back to the cars'));
      await settle(tester);
      expect(find.byType(BookingFormScreen), findsNothing);
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('the prices cannot be loaded: the message, and "Try again" '
        'loads the form', (tester) async {
      var requests = 0;
      await pumpForm(
        tester,
        pricesStream: () {
          requests += 1;
          return requests == 1
              ? Stream.error(const FormatException('no prices'))
              : Stream.value(prices());
        },
      );

      expect(find.text(loadErrorText), findsOneWidget);
      expect(sendButton(), findsNothing);

      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(requests, 2);
      expect(find.text(loadErrorText), findsNothing);
      expect(sendButton(), findsOneWidget);
    });

    testWidgets('the places cannot be loaded: the same message', (
      tester,
    ) async {
      await pumpForm(
        tester,
        locationsStream: () => Stream.error(const FormatException('no places')),
      );

      expect(find.text(loadErrorText), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(sendButton(), findsNothing);
    });
  });

  group('content', () {
    testWidgets('shows the car and all blocks; places and extras follow the '
        'language', (tester) async {
      await pumpForm(tester);

      expect(find.text('Booking request'), findsOneWidget);
      expect(find.text('Toyota Prius, 2019'), findsOneWidget);
      expect(find.text('\$45 / day'), findsOneWidget);
      for (final title in [
        'Your details',
        'Dates',
        'Places',
        'Extras',
        'Special requests',
        'Price',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Child seat'), findsOneWidget);
      expect(find.text('1–4 years'), findsOneWidget);
      expect(find.text('0–12 months'), findsOneWidget);
      expect(find.text('3–16 years'), findsOneWidget);
      expect(find.text('\$4.50 / day'), findsOneWidget);

      // The places are in the opened dropdown.
      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      expect(find.text('Tbilisi Airport'), findsWidgets);
      expect(find.text('Tbilisi Office'), findsWidgets);
      expect(find.text('Other place'), findsWidgets);
      await tester.tap(find.text('Tbilisi Airport').last);
      await settle(tester);

      containerOf(
        tester,
      ).read(appLanguageProvider.notifier).setLanguage(AppLanguage.ru);
      await settle(tester);

      // The chosen place is shown in the new language.
      expect(find.text('Аэропорт Тбилиси'), findsWidgets);
      expect(find.text('Tbilisi Airport'), findsNothing);
      expect(find.text('Детское кресло'), findsOneWidget);
      expect(find.text('Child seat'), findsNothing);

      // No Russian name: the English one is shown.
      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      expect(find.text('Tbilisi Office'), findsWidgets);
    });

    testWidgets('every date field shows "Tbilisi time (GMT+4)", also with an '
        'error', (tester) async {
      await pumpForm(tester);
      expect(find.text('Tbilisi time (GMT+4)'), findsNWidgets(2));

      await tapSend(tester);

      expect(find.text('Choose the pickup date and time'), findsOneWidget);
      expect(find.text('Choose the dropoff date and time'), findsOneWidget);
      expect(find.text('Tbilisi time (GMT+4)'), findsNWidgets(2));
    });

    testWidgets('an extra with the price 0 shows "Free"', (tester) async {
      await pumpForm(
        tester,
        pricesStream: () => Stream.value(prices(snowChains: 0)),
      );

      expect(find.text('Free'), findsOneWidget);
      expect(find.text('\$0 / day'), findsNothing);
    });
  });

  group('errors', () {
    testWidgets('no error at first; Send shows the required errors and sends '
        'nothing', (tester) async {
      await pumpForm(tester);

      expect(find.text('Enter your full name'), findsNothing);
      expect(find.text('Please check the marked fields'), findsNothing);

      await tapSend(tester);

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.text('Enter your e-mail'), findsOneWidget);
      expect(find.text('Choose the pickup date and time'), findsOneWidget);
      expect(find.text('Choose a place'), findsNWidgets(2));
      expect(find.text('Please check the marked fields'), findsOneWidget);
      expect(repository.sent, isEmpty);
      expect(find.byType(BookingFormScreen), findsOneWidget);
    });

    testWidgets('an error appears after leaving a field and disappears when '
        'corrected', (tester) async {
      await pumpForm(tester);

      await tester.enterText(field('Full name and surname'), 'N');
      await settle(tester);
      expect(find.text('The name is too short'), findsNothing);

      // Leaving the field: the cursor goes to the phone field.
      await tester.tap(field('Phone number'));
      await settle(tester);
      expect(find.text('The name is too short'), findsOneWidget);
      // The other fields were not touched yet.
      expect(find.text('Enter your e-mail'), findsNothing);

      await tester.enterText(field('Full name and surname'), 'Nino');
      await settle(tester);
      expect(find.text('The name is too short'), findsNothing);
    });

    testWidgets('"Other place" shows the text field, and its error after '
        'Send', (tester) async {
      await pumpForm(tester);
      expect(field('Address or place in Georgia'), findsNothing);

      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      await tester.tap(find.text('Other place').last);
      await settle(tester);

      expect(field('Address or place in Georgia'), findsOneWidget);
      expect(find.text('Enter the address or place'), findsNothing);

      await tapSend(tester);
      expect(find.text('Enter the address or place'), findsOneWidget);

      await tester.enterText(
        field('Address or place in Georgia'),
        'Hotel in Batumi',
      );
      await settle(tester);
      expect(find.text('Enter the address or place'), findsNothing);
      expect(
        containerOf(
          tester,
        ).read(bookingFormProvider(carId)).input.pickupLocation,
        const BookingLocation.other('Hotel in Batumi'),
      );
    });

    testWidgets('a failed Send scrolls to the first field with an error', (
      tester,
    ) async {
      await pumpForm(tester, size: const Size(400, 600));

      await tester.ensureVisible(sendButton());
      await settle(tester);
      final name = field('Full name and surname');
      expect(tester.getRect(name).bottom, lessThan(0));

      await tapSend(tester);
      await settle(tester);

      final rect = tester.getRect(name);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(tester.widget<TextField>(name).focusNode!.hasFocus, true);
    });
  });

  group('price', () {
    testWidgets('the total follows the dates and the extras', (tester) async {
      await pumpForm(tester);
      expect(find.text('Choose the dates to see the price'), findsOneWidget);

      form(tester)
        ..setPickup(TbilisiDateTime(2026, 1, 10, 18))
        ..setDropoff(TbilisiDateTime(2026, 1, 15, 20));
      await settle(tester);

      expect(find.text('Choose the dates to see the price'), findsNothing);
      expect(find.text('Rental days'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('\$225'), findsOneWidget);

      await tester.tap(find.text('Child seat'));
      await settle(tester);
      // 5 days * (45 + 4)
      expect(find.text('\$245'), findsOneWidget);

      form(tester).setDropoff(TbilisiDateTime(2026, 1, 15, 20, 1));
      await settle(tester);
      // One minute after the grace period: 6 days * 49
      expect(find.text('6'), findsOneWidget);
      expect(find.text('\$294'), findsOneWidget);
    });

    testWidgets('the individual-price note at 8 days, not at exactly 7', (
      tester,
    ) async {
      await pumpForm(tester);

      form(tester)
        ..setPickup(TbilisiDateTime(2026, 1, 10, 18))
        ..setDropoff(TbilisiDateTime(2026, 1, 17, 18));
      await settle(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Estimated total'), findsNothing);
      expect(find.text(individualNote), findsNothing);

      form(tester).setDropoff(TbilisiDateTime(2026, 1, 17, 21));
      await settle(tester);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Estimated total'), findsOneWidget);
      expect(find.text(individualNote), findsOneWidget);
    });

    testWidgets('the notes counter appears from 400 characters', (
      tester,
    ) async {
      await pumpForm(tester);
      final notes = find.byType(TextField).last;

      await tester.enterText(notes, 'a' * 399);
      await settle(tester);
      expect(find.text('399 / 500'), findsNothing);

      await tester.enterText(notes, 'a' * 400);
      await settle(tester);
      expect(find.text('400 / 500'), findsOneWidget);

      // Typing is not cut off; the text is refused with an error instead.
      await tester.enterText(notes, 'a' * 501);
      await tapSend(tester);
      expect(find.text('501 / 500'), findsOneWidget);
      expect(find.text('At most 500 characters'), findsOneWidget);
    });
  });

  group('pickers', () {
    testWidgets('the pickup pickers open on Tbilisi\'s today and the next '
        'full hour; the choice appears in the field', (tester) async {
      // 20:30 UTC on 10 January is already 00:30 on 11 January in Tbilisi.
      now = DateTime.utc(2026, 1, 10, 20, 30);
      await pumpForm(tester);

      await tester.tap(find.byType(DateTimeField).first);
      await settle(tester);

      final dates = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dates.currentDate, DateTime(2026, 1, 11));
      expect(dates.firstDate, DateTime(2026, 1, 11));
      expect(dates.initialDate, DateTime(2026, 1, 11));
      expect(dates.lastDate, DateTime(2028, 1, 11));

      await tester.tap(find.text('13'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      final times = tester.widget<TimePickerDialog>(
        find.byType(TimePickerDialog),
      );
      expect(times.initialTime, const TimeOfDay(hour: 1, minute: 0));

      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('13.01.2026 01:00'), findsOneWidget);
      expect(
        containerOf(tester).read(bookingFormProvider(carId)).input.pickup,
        TbilisiDateTime(2026, 1, 13, 1),
      );
    });

    testWidgets('the dropoff picker starts on the pickup day and ends 365 '
        'days later; closing it changes nothing', (tester) async {
      await pumpForm(tester);
      form(tester).setPickup(TbilisiDateTime(2026, 3, 5, 18, 30));
      await settle(tester);

      await tester.tap(find.byType(DateTimeField).last);
      await settle(tester);

      final dates = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dates.firstDate, DateTime(2026, 3, 5));
      expect(dates.initialDate, DateTime(2026, 3, 6));
      expect(dates.lastDate, DateTime(2027, 3, 5));
      expect(dates.currentDate, DateTime(2026, 1, 1));

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(
        containerOf(tester).read(bookingFormProvider(carId)).input.dropoff,
        isNull,
      );
    });
  });

  group('sending', () {
    testWidgets('while sending: a spinner, locked fields, and a second tap '
        'sends nothing', (tester) async {
      await pumpForm(tester);
      fillValidDraft(tester);
      await settle(tester);
      repository.pending = Completer<String>();

      await tapSend(tester);

      expect(find.text('Sending…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Sending…');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(
        tester.widget<TextField>(field('Full name and surname')).enabled,
        false,
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byType(DropdownButton<String>).first,
            )
            .onChanged,
        isNull,
      );

      await tester.tap(button, warnIfMissed: false);
      await settle(tester);
      expect(repository.sent, hasLength(1));

      repository.pending!.complete('document-x');
      await settle(tester);
      expect(find.byType(BookingSentScreen), findsOneWidget);
    });

    testWidgets('while sending, going back is blocked', (tester) async {
      await pumpForm(tester);
      fillValidDraft(tester);
      await settle(tester);

      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, true);
      expect(tester.widget<IconButton>(backArrow()).onPressed, isNotNull);

      repository.pending = Completer<String>();
      await tapSend(tester);

      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
      expect(tester.widget<IconButton>(backArrow()).onPressed, isNull);

      // The system back button does nothing.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(BookingFormScreen), findsOneWidget);

      repository.pending!.complete('document-x');
      await settle(tester);
      expect(find.byType(BookingSentScreen), findsOneWidget);
    });

    testWidgets('the form is gone when the answer arrives (browser Back): no '
        'thank-you screen, and the sent booking is forgotten', (tester) async {
      await pumpForm(tester);
      fillValidDraft(tester);
      await settle(tester);
      repository.pending = Completer<String>();
      await tapSend(tester);

      // What the browser's Back button does: the address changes at once.
      containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
      await settle(tester);
      expect(find.byType(BookingFormScreen), findsNothing);

      repository.pending!.complete('document-x');
      await settle(tester);

      expect(find.byType(BookingSentScreen), findsNothing);
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(containerOf(tester).read(sentBookingProvider), isNull);
    });

    testWidgets('each failure shows its text, and Send works again', (
      tester,
    ) async {
      await pumpForm(tester);
      fillValidDraft(tester);
      await settle(tester);

      const texts = {
        BookingCreateFailure.rejected:
            'The request was not accepted. Check your details and the '
            'dates, or choose another car.',
        BookingCreateFailure.noConnection:
            'Could not send the request. Check your internet connection '
            'and try again.',
        BookingCreateFailure.unknown: 'Something went wrong. Please try again.',
      };
      var attempts = 0;
      for (final MapEntry(key: failure, value: text) in texts.entries) {
        repository.error = BookingCreateException(failure);
        await tapSend(tester);
        attempts += 1;

        expect(find.text(text), findsOneWidget, reason: failure.name);
        expect(repository.sent, hasLength(attempts));
        expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
        // The draft is still in the fields.
        expect(find.text('Nino Beridze'), findsOneWidget);
      }

      repository.error = null;
      await tapSend(tester);
      expect(find.byType(BookingSentScreen), findsOneWidget);
    });

    testWidgets('success opens the thank-you screen; leaving it forgets the '
        'sent booking', (tester) async {
      await pumpForm(tester);
      fillValidDraft(tester);
      await settle(tester);

      await tapSend(tester);

      expect(find.byType(BookingSentScreen), findsOneWidget);
      expect(find.byType(BookingFormScreen), findsNothing);
      expect(find.text(thanksText), findsOneWidget);
      // Nothing personal is shown in this step.
      expect(find.text('Nino Beridze'), findsNothing);

      final sent = containerOf(tester).read(sentBookingProvider)!;
      expect(sent.id, 'document-1');
      expect(sent.booking.language, AppLanguage.en);
      expect(sent.booking.totalPriceCents, 22500);
      // The draft is empty again.
      expect(
        containerOf(tester).read(bookingFormProvider(carId)).input.fullName,
        '',
      );

      await tester.tap(find.text('Back to the cars'));
      await settle(tester);

      expect(find.byType(BookingSentScreen), findsNothing);
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(find.byType(CarDetailScreen), findsNothing);
      expect(containerOf(tester).read(sentBookingProvider), isNull);
    });
  });

  group('the draft', () {
    testWidgets('typed text survives a language switch and a reload of the '
        'settings, and the cursor stays in place', (tester) async {
      await pumpForm(tester);
      final name = field('Full name and surname');

      await tester.enterText(name, 'Nino Beridze');
      await settle(tester);
      final controller = tester.widget<TextField>(name).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);

      // Another value changes: the field must not be written to again.
      await tester.tap(find.text('I use WhatsApp on this number'));
      await settle(tester);
      expect(controller.text, 'Nino Beridze');
      expect(controller.selection.baseOffset, 4);

      final container = containerOf(tester);
      container.read(appLanguageProvider.notifier).setLanguage(AppLanguage.ka);
      await settle(tester);
      expect(find.text('Nino Beridze'), findsOneWidget);
      expect(find.text('Full name and surname'), findsNothing);

      container.invalidate(extrasPricesProvider);
      container.invalidate(pickupLocationsProvider);
      await settle(tester);
      expect(find.text('Nino Beridze'), findsOneWidget);
      expect(container.read(bookingFormProvider(carId)).input.whatsapp, true);
    });

    testWidgets('comes back in the fields when the user returns to the form', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(field('Full name and surname'), 'Nino Beridze');
      await tester.enterText(field('Phone number'), '+995 555 12 34 56');
      await tester.tap(find.byType(DropdownButton<String>).first);
      await settle(tester);
      await tester.tap(find.text('Other place').last);
      await settle(tester);
      await tester.enterText(
        field('Address or place in Georgia'),
        'Hotel in Batumi',
      );
      await settle(tester);

      await tester.tap(backArrow());
      await settle(tester);
      expect(find.byType(BookingFormScreen), findsNothing);
      expect(find.byType(CarDetailScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Make a booking'));
      await settle(tester);

      expect(find.byType(BookingFormScreen), findsOneWidget);
      String textOf(String label) =>
          tester.widget<TextField>(field(label)).controller!.text;
      expect(textOf('Full name and surname'), 'Nino Beridze');
      expect(textOf('Phone number'), '+995 555 12 34 56');
      expect(textOf('Address or place in Georgia'), 'Hotel in Batumi');
    });
  });

  group('320 px wide', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.code}: nothing overflows, with errors and a '
          'price', (tester) async {
        await pumpForm(tester, size: const Size(320, 4200), language: language);
        expect(tester.takeException(), isNull);

        // A long rental (the note), "Other place", and every error text.
        form(tester)
          ..setPickup(TbilisiDateTime(2026, 1, 10, 18))
          ..setDropoff(TbilisiDateTime(2026, 2, 10, 18))
          ..setPickupLocation(const BookingLocation.other(''))
          ..setPhone('123');
        await settle(tester);
        await tester.tap(find.byType(FilledButton).last);
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(repository.sent, isEmpty);
      });
    }
  });
}
