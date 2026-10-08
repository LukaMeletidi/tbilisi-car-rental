import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';

Map<String, dynamic> validPrices() => {
  'snowChains': 5,
  'childSeat': 4,
  'infantSeat': 4.5,
  'boosterSeat': 3,
};

Map<String, dynamic> document(Map<String, dynamic> prices) => {
  'pricesPerDay': prices,
};

void main() {
  test('reads a price for every extra, whole or decimal', () {
    final prices = ExtrasPrices.fromMap(document(validPrices()));

    expect(prices.priceOf(Extra.snowChains), 5.0);
    expect(prices.priceOf(Extra.childSeat), 4.0);
    expect(prices.priceOf(Extra.infantSeat), 4.5);
    expect(prices.priceOf(Extra.boosterSeat), 3.0);
    expect(prices.pricesPerDay.keys, containsAll(Extra.values));
  });

  test('accepts a price of 0', () {
    final prices = ExtrasPrices.fromMap(
      document(validPrices()..['boosterSeat'] = 0),
    );
    expect(prices.priceOf(Extra.boosterSeat), 0.0);
  });

  test('throws when the document does not exist', () {
    expect(() => ExtrasPrices.fromMap(null), throwsFormatException);
  });

  test('throws when pricesPerDay is missing or not a map', () {
    expect(() => ExtrasPrices.fromMap({}), throwsFormatException);
    expect(
      () => ExtrasPrices.fromMap({'pricesPerDay': 5}),
      throwsFormatException,
    );
  });

  test('throws when the price of any extra is missing', () {
    for (final extra in Extra.values) {
      expect(
        () => ExtrasPrices.fromMap(document(validPrices()..remove(extra.name))),
        throwsFormatException,
        reason: 'missing ${extra.name}',
      );
    }
  });

  test('throws when a price is not a number', () {
    expect(
      () => ExtrasPrices.fromMap(document(validPrices()..['childSeat'] = '4')),
      throwsFormatException,
    );
  });

  test('throws when a price is negative', () {
    expect(
      () => ExtrasPrices.fromMap(document(validPrices()..['childSeat'] = -1)),
      throwsFormatException,
    );
  });

  test('throws for an unknown extra name', () {
    expect(
      () => ExtrasPrices.fromMap(document(validPrices()..['snowchains'] = 5)),
      throwsFormatException,
    );
  });

  test('the price map cannot be changed', () {
    final prices = ExtrasPrices.fromMap(document(validPrices()));
    expect(
      () => prices.pricesPerDay[Extra.childSeat] = 0,
      throwsUnsupportedError,
    );
  });

  test('values with the same prices are equal', () {
    final a = ExtrasPrices.fromMap(document(validPrices()));
    final b = ExtrasPrices.fromMap(document(validPrices()));
    final c = ExtrasPrices.fromMap(document(validPrices()..['childSeat'] = 9));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
  });
}
