import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_place_text.dart';

const locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport', ru: 'Аэропорт Тбилиси'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Tbilisi Office'),
  ),
];

String? text(
  BookingLocation location, {
  List<PickupLocation>? known = locations,
  AppLanguage language = AppLanguage.en,
}) => bookingPlaceText(location, locations: known, language: language);

void main() {
  test('a fixed place gives its name in the language', () {
    const airport = BookingLocation.fixed('tbilisiAirport');
    expect(text(airport), 'Tbilisi Airport');
    expect(text(airport, language: AppLanguage.ru), 'Аэропорт Тбилиси');
  });

  test('a missing translation falls back to the English name', () {
    const office = BookingLocation.fixed('tbilisiOffice');
    expect(text(office, language: AppLanguage.ka), 'Tbilisi Office');
  });

  test('"other" gives the typed text, also without settings', () {
    const hotel = BookingLocation.other('  Hotel in Batumi ');
    expect(text(hotel), 'Hotel in Batumi');
    expect(text(hotel, known: null), 'Hotel in Batumi');
  });

  test('null when the settings are not loaded', () {
    expect(
      text(const BookingLocation.fixed('tbilisiAirport'), known: null),
      isNull,
    );
  });

  test('null when the place is no longer in settings', () {
    expect(text(const BookingLocation.fixed('kutaisiAirport')), isNull);
    expect(
      text(const BookingLocation.fixed('tbilisiAirport'), known: const []),
      isNull,
    );
  });

  test('null for an empty text, so no line is ever empty', () {
    expect(text(const BookingLocation.other('   ')), isNull);
    expect(
      text(
        const BookingLocation.fixed('empty'),
        known: const [PickupLocation(id: 'empty', name: LocalizedText())],
      ),
      isNull,
    );
  });

  test('the id of a place is never the result', () {
    for (final location in const [
      BookingLocation.fixed('tbilisiAirport'),
      BookingLocation.fixed('kutaisiAirport'),
    ]) {
      expect(text(location), isNot(location.id));
      expect(text(location, known: null), isNot(location.id));
    }
  });
}
