import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_fields.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

/// Where the sending of the form stands.
enum BookingSubmitStatus {
  /// Nothing is being sent.
  idle,

  /// The request is on its way; the form is locked.
  sending,

  /// The last attempt failed; see [BookingFormState.failure].
  failed,
}

/// The booking form of one car: what the user entered so far, which errors
/// may be shown, and the state of sending.
class BookingFormState {
  const BookingFormState({
    this.input = const BookingFormInput(),
    this.touched = const {},
    this.submitAttempted = false,
    this.status = BookingSubmitStatus.idle,
    this.failure,
  }) : assert(
         (status == BookingSubmitStatus.failed) == (failure != null),
         'a failure belongs to the failed status, and only to it',
       );

  /// The raw values, exactly as entered.
  final BookingFormInput input;

  /// The fields the user has already left or changed. They show their error
  /// before the first press of Send.
  final Set<BookingFormField> touched;

  /// True after the first press of Send; from then on every field shows its
  /// error.
  final bool submitAttempted;

  final BookingSubmitStatus status;

  /// Why the last attempt failed. Set only while [status] is
  /// [BookingSubmitStatus.failed].
  final BookingCreateFailure? failure;

  bool get isSending => status == BookingSubmitStatus.sending;

  /// A copy with other values. The sending state is not changed here; see
  /// [withStatus].
  BookingFormState copyWith({
    BookingFormInput? input,
    Set<BookingFormField>? touched,
    bool? submitAttempted,
  }) {
    return BookingFormState(
      input: input ?? this.input,
      touched: touched ?? this.touched,
      submitAttempted: submitAttempted ?? this.submitAttempted,
      status: status,
      failure: failure,
    );
  }

  /// A copy with another sending state. [failure] is needed for, and only
  /// for, [BookingSubmitStatus.failed].
  BookingFormState withStatus(
    BookingSubmitStatus status, {
    BookingCreateFailure? failure,
  }) {
    return BookingFormState(
      input: input,
      touched: touched,
      submitAttempted: submitAttempted,
      status: status,
      failure: failure,
    );
  }
}
