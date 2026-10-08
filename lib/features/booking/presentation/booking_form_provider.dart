import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_repository.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_builder.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_fields.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_state.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';

/// The booking form of the car [carId]: the draft and the sending.
///
/// The draft is kept in memory until it is sent or the app is closed, so
/// going back to the car and returning does not lose it. While a request is
/// being sent the draft cannot be changed.
///
/// The current moment always comes from [clockProvider].
class BookingFormNotifier extends Notifier<BookingFormState> {
  BookingFormNotifier(this.carId);

  final String carId;

  @override
  BookingFormState build() => const BookingFormState();

  void setFullName(String value) => _edit((i) => i.copyWith(fullName: value));

  void setPhone(String value) => _edit((i) => i.copyWith(phone: value));

  void setWhatsapp(bool value) => _edit((i) => i.copyWith(whatsapp: value));

  void setTelegram(bool value) => _edit((i) => i.copyWith(telegram: value));

  void setEmail(String value) => _edit((i) => i.copyWith(email: value));

  void setPickup(TbilisiDateTime value) =>
      _edit((i) => i.copyWith(pickup: value));

  void setDropoff(TbilisiDateTime value) =>
      _edit((i) => i.copyWith(dropoff: value));

  /// A fixed place, or "other" with the text typed so far (may be empty).
  void setPickupLocation(BookingLocation value) =>
      _edit((i) => i.copyWith(pickupLocation: value));

  void setDropoffLocation(BookingLocation value) =>
      _edit((i) => i.copyWith(dropoffLocation: value));

  void setExtra(Extra extra, {required bool selected}) {
    _edit((i) {
      final extras = {...i.extras};
      selected ? extras.add(extra) : extras.remove(extra);
      return i.copyWith(extras: Set.unmodifiable(extras));
    });
  }

  void setNotes(String value) => _edit((i) => i.copyWith(notes: value));

  /// The user has left or changed [field]; it may show its error from now.
  void markTouched(BookingFormField field) {
    if (state.touched.contains(field)) return;
    state = state.copyWith(
      touched: Set.unmodifiable({...state.touched, field}),
    );
  }

  /// Every problem of the draft at this moment.
  Set<BookingFormError> validate({
    required Car car,
    required List<PickupLocation> locations,
  }) {
    return validateBookingForm(
      state.input,
      car: car,
      locations: locations,
      now: ref.read(clockProvider)(),
    );
  }

  /// Checks the draft and, when it is valid, sends it.
  ///
  /// Returns true when the server confirmed the booking: it is then in
  /// [sentBookingProvider] and the draft is empty again. Returns false when
  /// the draft has errors (every field then shows its error), when the
  /// sending failed (see [BookingFormState.failure]), or when a request is
  /// already being sent; a second press sends nothing.
  ///
  /// Throws an [ArgumentError] when [car] is not the car of this form.
  Future<bool> submit({
    required Car car,
    required ExtrasPrices extrasPrices,
    required List<PickupLocation> locations,
    required AppLanguage language,
  }) async {
    if (car.id != carId) {
      throw ArgumentError.value(car.id, 'car', 'is not the car "$carId"');
    }
    if (state.isSending) return false;

    final now = ref.read(clockProvider)();
    final errors = validateBookingForm(
      state.input,
      car: car,
      locations: locations,
      now: now,
    );
    if (errors.isNotEmpty) {
      state = state
          .copyWith(submitAttempted: true)
          .withStatus(BookingSubmitStatus.idle);
      return false;
    }

    final booking = buildBooking(
      input: state.input,
      car: car,
      extrasPrices: extrasPrices,
      locations: locations,
      language: language,
      now: now,
    );
    state = state
        .copyWith(submitAttempted: true)
        .withStatus(BookingSubmitStatus.sending);

    final String id;
    try {
      id = await ref.read(bookingRepositoryProvider).createBooking(booking);
    } catch (error) {
      state = state.withStatus(
        BookingSubmitStatus.failed,
        failure: error is BookingCreateException
            ? error.failure
            : BookingCreateFailure.unknown,
      );
      return false;
    }

    ref
        .read(sentBookingProvider.notifier)
        .set(SentBooking(id: id, booking: booking, car: car));
    state = const BookingFormState();
    return true;
  }

  void _edit(BookingFormInput Function(BookingFormInput input) change) {
    if (state.isSending) return;
    state = state.copyWith(input: change(state.input));
  }
}

/// One form per car ID.
final bookingFormProvider =
    NotifierProvider.family<BookingFormNotifier, BookingFormState, String>(
      BookingFormNotifier.new,
    );
