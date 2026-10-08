import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_fields.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_state.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';

/// Records what is sent and answers as the test tells it to. No Firebase.
class FakeBookingRepository implements BookingRepository {
  final sent = <Booking>[];

  /// When set, createBooking waits for it.
  Completer<String>? pending;

  /// When set, createBooking fails with it.
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

/// The current moment in the tests: 1 January 2026, 12:00 in Tbilisi.
final fixedNow = DateTime.utc(2026, 1, 1, 8);

const carId = 'car-1';

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
  description: LocalizedText(),
  photos: [],
  active: true,
);

const locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport'),
  ),
];

final extrasPrices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 4.5,
    'boosterSeat': 3,
  },
});

late FakeBookingRepository repository;
late ProviderContainer container;
late DateTime now;

BookingFormNotifier get form =>
    container.read(bookingFormProvider(carId).notifier);

BookingFormState get state => container.read(bookingFormProvider(carId));

Future<bool> submit({AppLanguage language = AppLanguage.en}) {
  return form.submit(
    car: car,
    extrasPrices: extrasPrices,
    locations: locations,
    language: language,
  );
}

/// Pickup on the 10th at 18:00 and dropoff on the 15th at 20:00: 5 days.
void fillValidForm() {
  form
    ..setFullName('  Nino Beridze ')
    ..setPhone('+995 555 12-34-56')
    ..setWhatsapp(true)
    ..setEmail('nino@example.com')
    ..setPickup(TbilisiDateTime(2026, 1, 10, 18))
    ..setDropoff(TbilisiDateTime(2026, 1, 15, 20))
    ..setPickupLocation(const BookingLocation.fixed('tbilisiAirport'))
    ..setDropoffLocation(const BookingLocation.other('Hotel in Batumi'))
    ..setExtra(Extra.childSeat, selected: true)
    ..setNotes('Late arrival');
}

void main() {
  setUp(() {
    repository = FakeBookingRepository();
    now = fixedNow;
    container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  group('the draft', () {
    test('starts empty, idle and without errors to show', () {
      expect(state.input.fullName, '');
      expect(state.input.pickup, isNull);
      expect(state.input.extras, isEmpty);
      expect(state.touched, isEmpty);
      expect(state.submitAttempted, false);
      expect(state.status, BookingSubmitStatus.idle);
      expect(state.failure, isNull);
    });

    test('each setter changes its own value', () {
      fillValidForm();
      form.setTelegram(true);

      final input = state.input;
      expect(input.fullName, '  Nino Beridze ');
      expect(input.phone, '+995 555 12-34-56');
      expect(input.whatsapp, true);
      expect(input.telegram, true);
      expect(input.email, 'nino@example.com');
      expect(input.pickup, TbilisiDateTime(2026, 1, 10, 18));
      expect(input.dropoff, TbilisiDateTime(2026, 1, 15, 20));
      expect(
        input.pickupLocation,
        const BookingLocation.fixed('tbilisiAirport'),
      );
      expect(
        input.dropoffLocation,
        const BookingLocation.other('Hotel in Batumi'),
      );
      expect(input.extras, {Extra.childSeat});
      expect(input.notes, 'Late arrival');
    });

    test('an extra can be selected and removed again', () {
      form
        ..setExtra(Extra.snowChains, selected: true)
        ..setExtra(Extra.childSeat, selected: true)
        ..setExtra(Extra.snowChains, selected: true);
      expect(state.input.extras, {Extra.snowChains, Extra.childSeat});

      form.setExtra(Extra.snowChains, selected: false);
      expect(state.input.extras, {Extra.childSeat});
    });

    test('touched fields are remembered', () {
      form
        ..markTouched(BookingFormField.phone)
        ..markTouched(BookingFormField.phone)
        ..markTouched(BookingFormField.email);
      expect(state.touched, {BookingFormField.phone, BookingFormField.email});
    });

    test('each car has its own draft', () {
      form.setFullName('Nino');
      final other = container.read(bookingFormProvider('car-2'));
      expect(other.input.fullName, '');
      expect(state.input.fullName, 'Nino');
    });

    test('validate uses the moment of the clock provider', () {
      fillValidForm();
      expect(form.validate(car: car, locations: locations), isEmpty);

      // One minute after the chosen pickup (18:00 Tbilisi is 14:00 UTC).
      now = DateTime.utc(2026, 1, 10, 14, 1);
      expect(form.validate(car: car, locations: locations), {
        BookingFormError.pickupNotInFuture,
      });
    });
  });

  group('submit', () {
    test('an invalid form sends nothing and marks the attempt', () async {
      form.setFullName('Nino');

      expect(await submit(), false);
      expect(repository.sent, isEmpty);
      expect(state.submitAttempted, true);
      expect(state.status, BookingSubmitStatus.idle);
      expect(state.input.fullName, 'Nino');
      expect(container.read(sentBookingProvider), isNull);
    });

    test('a valid form sends one booking, built from the draft', () async {
      fillValidForm();

      expect(await submit(language: AppLanguage.ka), true);
      expect(repository.sent, hasLength(1));

      final booking = repository.sent.single;
      expect(booking.customer.fullName, 'Nino Beridze');
      expect(booking.customer.phone, '+995555123456');
      expect(booking.carId, carId);
      expect(booking.pickup, DateTime.utc(2026, 1, 10, 14));
      expect(booking.dropoff, DateTime.utc(2026, 1, 15, 16));
      expect(booking.extras, {Extra.childSeat});
      // 5 days * (45 + 4) = 245
      expect(booking.totalPriceCents, 24500);
      expect(booking.language, AppLanguage.ka);
      expect(booking.status, BookingStatus.newBooking);
    });

    test('success stores the sent booking and empties the draft', () async {
      fillValidForm();
      await submit();

      final sent = container.read(sentBookingProvider)!;
      expect(sent.id, 'document-1');
      expect(sent.booking, repository.sent.single);
      expect(sent.car, car);

      expect(state.input.fullName, '');
      expect(state.input.pickup, isNull);
      expect(state.submitAttempted, false);
      expect(state.status, BookingSubmitStatus.idle);
    });

    test('while sending: the state is sending and a second press does '
        'nothing', () async {
      fillValidForm();
      repository.pending = Completer<String>();

      final first = submit();
      expect(state.status, BookingSubmitStatus.sending);
      expect(state.isSending, true);

      expect(await submit(), false);
      expect(repository.sent, hasLength(1));

      repository.pending!.complete('document-x');
      expect(await first, true);
      expect(container.read(sentBookingProvider)!.id, 'document-x');
    });

    test('while sending the draft cannot be changed', () async {
      fillValidForm();
      repository.pending = Completer<String>();
      final first = submit();

      form
        ..setFullName('Somebody Else')
        ..setExtra(Extra.snowChains, selected: true);
      expect(state.input.fullName, '  Nino Beridze ');
      expect(state.input.extras, {Extra.childSeat});

      repository.pending!.complete('document-x');
      await first;
    });

    for (final failure in BookingCreateFailure.values) {
      test('${failure.name}: the failed state keeps the draft', () async {
        fillValidForm();
        repository.error = BookingCreateException(failure);

        expect(await submit(), false);
        expect(state.status, BookingSubmitStatus.failed);
        expect(state.failure, failure);
        expect(state.input.fullName, '  Nino Beridze ');
        expect(container.read(sentBookingProvider), isNull);
      });
    }

    test('an unexpected error becomes the unknown failure', () async {
      fillValidForm();
      repository.error = StateError('broken');

      expect(await submit(), false);
      expect(state.status, BookingSubmitStatus.failed);
      expect(state.failure, BookingCreateFailure.unknown);
    });

    test('a new Send after a failure sends again and can succeed', () async {
      fillValidForm();
      repository.error = const BookingCreateException(
        BookingCreateFailure.noConnection,
      );
      expect(await submit(), false);

      repository.error = null;
      expect(await submit(), true);
      expect(repository.sent, hasLength(2));
      expect(state.status, BookingSubmitStatus.idle);
      expect(state.failure, isNull);
      expect(container.read(sentBookingProvider)!.id, 'document-2');
    });

    test('an invalid form after a failure clears the failure', () async {
      fillValidForm();
      repository.error = const BookingCreateException(
        BookingCreateFailure.rejected,
      );
      await submit();

      form.setEmail('not an e-mail');
      expect(await submit(), false);
      expect(state.status, BookingSubmitStatus.idle);
      expect(state.failure, isNull);
      expect(repository.sent, hasLength(1));
    });

    test('the pickup is checked against the clock at the moment of '
        'sending', () async {
      fillValidForm();
      now = DateTime.utc(2026, 1, 10, 14, 1);

      expect(await submit(), false);
      expect(repository.sent, isEmpty);
    });

    test('throws for a car that is not the car of the form', () {
      fillValidForm();
      expect(
        () => container
            .read(bookingFormProvider('car-2').notifier)
            .submit(
              car: car,
              extrasPrices: extrasPrices,
              locations: locations,
              language: AppLanguage.en,
            ),
        throwsArgumentError,
      );
    });
  });

  group('sentBookingProvider', () {
    test('is empty at first and after clear()', () async {
      expect(container.read(sentBookingProvider), isNull);

      fillValidForm();
      await submit();
      expect(container.read(sentBookingProvider), isNotNull);

      container.read(sentBookingProvider.notifier).clear();
      expect(container.read(sentBookingProvider), isNull);
    });
  });
}
