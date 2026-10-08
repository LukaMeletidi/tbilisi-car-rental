import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));
  final ka = lookupAppLocalizations(const Locale('ka'));
  final languages = {'en': en, 'ru': ru, 'ka': ka};

  for (final MapEntry(key: code, value: l10n) in languages.entries) {
    group(code, () {
      test('every form error has a text', () {
        for (final error in BookingFormError.values) {
          expect(
            bookingErrorText(l10n, error).trim(),
            isNotEmpty,
            reason: error.name,
          );
        }
      });

      test('no text still shows a placeholder in braces', () {
        final texts = [
          for (final error in BookingFormError.values)
            bookingErrorText(l10n, error),
          for (final failure in BookingCreateFailure.values)
            bookingFailureText(l10n, failure),
          individualPriceNote(l10n),
        ];
        for (final text in texts) {
          expect(text.contains('{'), false, reason: text);
          expect(text.contains('}'), false, reason: text);
        }
      });

      test('every extra has a name; the three seats have an age', () {
        for (final extra in Extra.values) {
          expect(extraName(l10n, extra).trim(), isNotEmpty);
        }
        expect(extraAgeText(l10n, Extra.snowChains), isNull);
        expect(extraAgeText(l10n, Extra.childSeat), contains('1–4'));
        expect(extraAgeText(l10n, Extra.infantSeat), contains('0–12'));
        expect(extraAgeText(l10n, Extra.boosterSeat), contains('3–16'));
      });

      test('every failure has its own text', () {
        final texts = {
          for (final failure in BookingCreateFailure.values)
            bookingFailureText(l10n, failure),
        };
        expect(texts, hasLength(BookingCreateFailure.values.length));
        expect(texts.every((text) => text.trim().isNotEmpty), true);
      });

      test('the numbers in the texts come from the constants', () {
        expect(
          bookingErrorText(l10n, BookingFormError.nameTooLong),
          contains('$bookingNameMaxLength'),
        );
        expect(
          bookingErrorText(l10n, BookingFormError.emailTooLong),
          contains('$bookingEmailMaxLength'),
        );
        expect(
          bookingErrorText(l10n, BookingFormError.pickupLocationTextTooLong),
          contains('$bookingOtherLocationMaxLength'),
        );
        expect(
          bookingErrorText(l10n, BookingFormError.dropoffLocationTextTooLong),
          contains('$bookingOtherLocationMaxLength'),
        );
        expect(
          bookingErrorText(l10n, BookingFormError.notesTooLong),
          contains('$bookingNotesMaxLength'),
        );
        expect(
          bookingErrorText(l10n, BookingFormError.rentalTooLong),
          contains('$bookingMaxRentalDays'),
        );
        expect(individualPriceNote(l10n), contains('$standardRentalMaxDays'));
        expect(
          bookingErrorText(l10n, BookingFormError.phoneInvalid),
          contains(bookingPhoneExample),
        );
      });

      test('an extra price: "Free" for 0, otherwise the price per day', () {
        expect(extraPriceText(l10n, 0), l10n.extraFree);
        expect(extraPriceText(l10n, 5), l10n.pricePerDay('5'));
        expect(extraPriceText(l10n, 4.5), l10n.pricePerDay('4.50'));
      });
    });
  }

  test('English texts', () {
    expect(
      bookingErrorText(en, BookingFormError.notesTooLong),
      'At most 500 characters',
    );
    expect(
      bookingErrorText(en, BookingFormError.rentalTooLong),
      'A rental can be at most 365 days',
    );
    expect(
      bookingErrorText(en, BookingFormError.phoneInvalid),
      'Use the international format, for example +995 555 12 34 56',
    );
    expect(
      individualPriceNote(en),
      'For rentals longer than 7 days, the price is individual — our team '
      'will contact you to confirm the final price.',
    );
    expect(
      bookingFailureText(en, BookingCreateFailure.rejected),
      'The request was not accepted. Check your details and the dates, or '
      'choose another car.',
    );
    expect(extraPriceText(en, 5), '\$5 / day');
    expect(extraPriceText(en, 0), 'Free');
    expect(en.tbilisiTimeLabel, 'Tbilisi time (GMT+4)');
  });

  test('the Tbilisi time label names GMT+4 in every language', () {
    for (final l10n in languages.values) {
      expect(l10n.tbilisiTimeLabel, contains('(GMT+4)'));
    }
  });

  test('the pickup and dropoff errors of a place share one text', () {
    expect(
      bookingErrorText(en, BookingFormError.pickupLocationRequired),
      bookingErrorText(en, BookingFormError.dropoffLocationRequired),
    );
    expect(
      bookingErrorText(en, BookingFormError.pickupLocationUnknown),
      bookingErrorText(en, BookingFormError.dropoffLocationUnknown),
    );
    expect(
      bookingErrorText(en, BookingFormError.pickupLocationTextRequired),
      bookingErrorText(en, BookingFormError.dropoffLocationTextRequired),
    );
  });

  group('the notes counter', () {
    test('appears from 400 characters', () {
      expect(bookingNotesCounterFrom, 400);
      expect(showsNotesCounter(0), false);
      expect(showsNotesCounter(399), false);
      expect(showsNotesCounter(400), true);
      expect(showsNotesCounter(501), true);
    });

    test('shows the length and the limit', () {
      expect(notesCounterText(430), '430 / 500');
      expect(notesCounterText(501), '501 / 500');
    });
  });
}
