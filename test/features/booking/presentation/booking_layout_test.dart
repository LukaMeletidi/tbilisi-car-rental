import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/contact_fields.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/date_time_field.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/location_field.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/notes_field.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';

/// The narrow phone of the layout tests, at a larger text size.
const narrow = Size(360, 780);
const textScale = 1.3;
const languages = AppLanguage.values;

const carId = 'car-1';

/// A made-up car.
const car = Car(
  id: carId,
  brand: 'Brand',
  model: 'Model',
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: 40,
  description: LocalizedText(en: 'A made-up car.'),
  photos: [],
  active: true,
);

const locations = [
  PickupLocation(
    id: 'placeOne',
    name: LocalizedText(ka: 'ადგილი ერთი', ru: 'Место один', en: 'Place one'),
  ),
];

/// 1 January 2026, 12:00 in Tbilisi.
final now = DateTime.utc(2026, 1, 1, 8);

/// Never called: the tests only show errors and never send.
class _NoBookingRepository implements BookingRepository {
  @override
  Future<String> createBooking(
    Booking booking, {
    Duration timeout = bookingCreateTimeout,
  }) => throw StateError('not used');
}

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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(textScale)),
        child: child!,
      ),
    );
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The real app at [address], narrow, at text size 1.3, in [language].
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  AppLanguage language,
  String address,
) async {
  tester.view.physicalSize = narrow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(
          FakeAdminAuthRepository(),
        ),
        activeCarsProvider.overrideWith((ref) => Stream.value(const [car])),
        carProvider.overrideWith((ref, id) => Stream.value(car)),
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
        pickupLocationsProvider.overrideWith((ref) => Stream.value(locations)),
        bookingRepositoryProvider.overrideWithValue(_NoBookingRepository()),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const _App(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_App)),
  );
  container.read(appLanguageProvider.notifier).setLanguage(language);
  container.read(appRouterProvider).go(address);
  await settle(tester);
  return container;
}

/// Every text of [texts] that is on screen is drawn in full: its paragraph
/// did not run out of lines (no "…"). Returns how many were found.
int expectShownInFull(WidgetTester tester, Set<String> texts, String why) {
  var found = 0;
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (!texts.contains(text)) continue;
    found++;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '$why: "$text" is cut',
    );
  }
  return found;
}

/// How many lines [text] needs where it is drawn now, without any limit;
/// null when it is not on screen.
int? linesOf(WidgetTester tester, String text) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (paragraph.text.toPlainText() != text) continue;
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: paragraph.size.width);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines;
  }
  return null;
}

/// The texts of every field error of the form, in [l10n].
Set<String> errorTexts(AppLocalizations l10n) => {
  for (final error in BookingFormError.values) bookingErrorText(l10n, error),
};

/// One field widget alone, narrow, at text size 1.3.
Future<void> pumpField(
  WidgetTester tester,
  AppLanguage language,
  Widget field,
) async {
  tester.view.physicalSize = narrow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: field,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The field that shows [error], with [text] as its error.
Widget fieldFor(BookingFormError error, String text, AppLanguage language) {
  final name = error.name;
  if (name.startsWith('name') ||
      name.startsWith('phone') ||
      name.startsWith('email')) {
    return ContactFields(
      enabled: true,
      nameKey: const ValueKey('name'),
      nameController: TextEditingController(),
      nameFocusNode: FocusNode(),
      nameError: name.startsWith('name') ? text : null,
      onNameChanged: (_) {},
      phoneKey: const ValueKey('phone'),
      phoneController: TextEditingController(),
      phoneFocusNode: FocusNode(),
      phoneError: name.startsWith('phone') ? text : null,
      onPhoneChanged: (_) {},
      whatsapp: false,
      onWhatsappChanged: (_) {},
      telegram: false,
      onTelegramChanged: (_) {},
      emailKey: const ValueKey('email'),
      emailController: TextEditingController(),
      emailFocusNode: FocusNode(),
      emailError: name.startsWith('email') ? text : null,
      onEmailChanged: (_) {},
    );
  }
  if (name.contains('Location')) {
    // A text error is shown under the "Other place" text field.
    final other = name.contains('Text');
    return LocationField(
      label: 'Label',
      locations: locations,
      language: language,
      value: other ? const BookingLocation.other('') : null,
      otherController: TextEditingController(),
      otherFocusNode: FocusNode(),
      errorText: text,
      enabled: true,
      onChanged: (_) {},
      onOtherTextChanged: (_) {},
    );
  }
  if (name.startsWith('notes')) {
    return NotesField(
      controller: TextEditingController(),
      focusNode: FocusNode(),
      length: 0,
      errorText: text,
      enabled: true,
      onChanged: (_) {},
    );
  }
  // pickup..., dropoff... and rentalTooLong: a date field.
  return DateTimeField(
    label: 'Label',
    value: null,
    errorText: text,
    enabled: true,
    onTap: () {},
  );
}

void main() {
  for (final language in languages) {
    group(language.code, () {
      testWidgets('the booking form with errors shown: no overflow, every '
          'error in full', (tester) async {
        // A layout overflow is reported as an error and fails the test.
        final container = await pumpApp(
          tester,
          language,
          AppRoutes.booking(carId),
        );
        // Invalid values: a short name, an invalid phone and e-mail, the
        // pick-up in the past and the return before it, "Other place"
        // without a text.
        container.read(bookingFormProvider(carId).notifier)
          ..setFullName('N')
          ..setPhone('12')
          ..setEmail('x')
          ..setPickup(TbilisiDateTime(2025, 12, 30, 10))
          ..setDropoff(TbilisiDateTime(2025, 12, 29, 10))
          ..setPickupLocation(const BookingLocation.other(''));
        await settle(tester);
        final l10n = lookupAppLocalizations(Locale(language.code));
        final send = find.widgetWithText(FilledButton, l10n.bookingSubmit);
        await tester.ensureVisible(send);
        await settle(tester);
        await tester.tap(send);
        await settle(tester);

        final errors = errorTexts(l10n);
        final phoneError = bookingErrorText(
          l10n,
          BookingFormError.phoneInvalid,
        );
        var shown = 0;
        int? phoneLines;
        // Scroll through the whole form; each part is checked on screen.
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 12; i++) {
          shown += expectShownInFull(tester, errors, language.code);
          phoneLines ??= linesOf(tester, phoneError);
          await tester.drag(scrollable, const Offset(0, -300));
          await settle(tester);
        }
        // At least: name, phone, e-mail, pick-up, return, the two places.
        expect(shown, greaterThanOrEqualTo(7));
        // The longest error (with the example number) fits the 6 lines of
        // the fields; a longer text would be caught here.
        expect(phoneLines, isNotNull, reason: 'the phone error is not shown');
        expect(phoneLines, lessThanOrEqualTo(6), reason: language.code);
        expect(tester.takeException(), isNull);
      });

      testWidgets('every field error text, in its own field: in full', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language.code));
        for (final error in BookingFormError.values) {
          // Not a field error: the page message of a car that is gone.
          if (error == BookingFormError.carNotAvailable) continue;
          final text = bookingErrorText(l10n, error);
          await pumpField(tester, language, fieldFor(error, text, language));
          expect(
            expectShownInFull(tester, {text}, '${language.code} $error'),
            1,
            reason: '${language.code} $error: the text is not shown',
          );
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('the filter sheet of the catalog: no overflow, nothing '
          'cut', (tester) async {
        await pumpApp(tester, language, AppRoutes.cars);
        final l10n = lookupAppLocalizations(Locale(language.code));
        await tester.tap(find.text(l10n.filters));
        await settle(tester);
        expect(find.byType(BottomSheet), findsOneWidget);
        for (final element
            in find
                .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${language.code}: "${paragraph.text.toPlainText()}"',
          );
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
