import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The texts of one ARB file, without the "@" entries.
Map<String, String> arbTexts(String language) {
  final map =
      jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in map.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

AppLocalizations l10n(String language) =>
    lookupAppLocalizations(Locale(language));

/// The terms decided in step 7.3a: one word each for pick-up and return in
/// every language, as Home and the FAQ use them.
void main() {
  test('ka: the pick-up term is მიღება in the booking texts', () {
    final ka = l10n('ka');
    for (final text in [
      ka.bookingPickupDateTime,
      ka.bookingPickupLocation,
      ka.bookingErrorPickupRequired,
      ka.bookingErrorPickupNotInFuture,
      ka.bookingErrorDropoffNotAfterPickup,
      ka.bookingSentPickup,
    ]) {
      expect(text, contains('მიღებ'), reason: text);
    }
    expect(ka.faq3Question, contains('მივიღო'));
    expect(ka.faq3Answer, contains('ავტომობილის მიღება'));
  });

  test('ka: the old words are gone from every text', () {
    final ka = arbTexts('ka');
    for (final MapEntry(:key, :value) in ka.entries) {
      expect(value, isNot(contains('აყვან')), reason: key);
      expect(value, isNot(contains('ელ. ფოსტ')), reason: key);
      expect(value, isNot(contains('წაღება')), reason: key);
      expect(value, isNot(contains('ავიღო')), reason: key);
    }
    expect(l10n('ka').extraChildSeat, 'საბავშვო სავარძელი');
  });

  test('en: "Pickup" and "Dropoff" no longer appear; Pick-up and Return', () {
    final en = arbTexts('en');
    for (final MapEntry(:key, :value) in en.entries) {
      final lower = value.toLowerCase();
      expect(lower, isNot(contains('pickup')), reason: key);
      expect(lower, isNot(contains('dropoff')), reason: key);
    }
    final texts = l10n('en');
    expect(texts.bookingPickupDateTime, 'Pick-up date and time');
    expect(texts.bookingDropoffDateTime, 'Return date and time');
    expect(texts.bookingSentPickup, 'Pick-up');
    expect(texts.bookingSentDropoff, 'Return');
    expect(texts.bookingFullName, 'First name and surname');
  });

  test('the booking button asks for a request', () {
    expect(l10n('en').makeBooking, 'Request a booking');
    expect(l10n('ka').makeBooking, 'დაჯავშნის მოთხოვნა');
    expect(l10n('ru').makeBooking, 'Оставить заявку');
  });

  test('ru: "Попробуйте позже" in every load error', () {
    final ru = l10n('ru');
    for (final text in [
      ru.catalogError,
      ru.carError,
      ru.bookingFormLoadError,
      ru.aboutContactsError,
    ]) {
      expect(text, endsWith('Попробуйте позже.'), reason: text);
    }
    for (final value in arbTexts('ru').values) {
      expect(value, isNot(contains('Повторите попытку')));
    }
  });
}
