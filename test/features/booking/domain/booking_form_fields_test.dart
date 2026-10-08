import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/booking/domain/booking_form_fields.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

void main() {
  test('every error belongs to a field, except "car not available"', () {
    for (final error in BookingFormError.values) {
      final field = fieldOfError(error);
      if (error == BookingFormError.carNotAvailable) {
        expect(field, isNull);
      } else {
        expect(field, isNotNull, reason: error.name);
      }
    }
  });

  test('every field has at least one error', () {
    final used = {
      for (final error in BookingFormError.values) ?fieldOfError(error),
    };
    expect(used, BookingFormField.values.toSet());
  });

  test('the errors are grouped by their field', () {
    expect(
      errorsByField({
        BookingFormError.nameTooShort,
        BookingFormError.rentalTooLong,
        BookingFormError.dropoffLocationTextRequired,
        BookingFormError.carNotAvailable,
      }),
      {
        BookingFormField.fullName: BookingFormError.nameTooShort,
        BookingFormField.dropoff: BookingFormError.rentalTooLong,
        BookingFormField.dropoffLocation:
            BookingFormError.dropoffLocationTextRequired,
      },
    );
  });

  group('visibleErrors', () {
    const errors = {
      BookingFormError.nameRequired,
      BookingFormError.phoneInvalid,
      BookingFormError.pickupRequired,
    };

    test('nothing is visible before a field is touched', () {
      expect(
        visibleErrors(errors, touched: const {}, submitAttempted: false),
        isEmpty,
      );
    });

    test('a touched field shows only its own error', () {
      expect(
        visibleErrors(
          errors,
          touched: const {BookingFormField.phone, BookingFormField.email},
          submitAttempted: false,
        ),
        {BookingFormField.phone: BookingFormError.phoneInvalid},
      );
    });

    test('after a Send attempt every error is visible', () {
      expect(visibleErrors(errors, touched: const {}, submitAttempted: true), {
        BookingFormField.fullName: BookingFormError.nameRequired,
        BookingFormField.phone: BookingFormError.phoneInvalid,
        BookingFormField.pickup: BookingFormError.pickupRequired,
      });
    });

    test('no errors: nothing is visible', () {
      expect(
        visibleErrors(
          const {},
          touched: BookingFormField.values.toSet(),
          submitAttempted: true,
        ),
        isEmpty,
      );
    });
  });

  group('firstFieldWithError', () {
    test('follows the order on the screen', () {
      expect(
        firstFieldWithError({
          BookingFormError.notesTooLong,
          BookingFormError.dropoffRequired,
          BookingFormError.emailInvalid,
        }),
        BookingFormField.email,
      );
      expect(
        firstFieldWithError({
          BookingFormError.dropoffLocationRequired,
          BookingFormError.pickupLocationUnknown,
        }),
        BookingFormField.pickupLocation,
      );
    });

    test('is null without errors or with only "car not available"', () {
      expect(firstFieldWithError(const {}), isNull);
      expect(firstFieldWithError({BookingFormError.carNotAvailable}), isNull);
    });
  });
}
