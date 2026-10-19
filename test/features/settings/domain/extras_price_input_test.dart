import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';

Map<Extra, String> allPrices(String text) => {
  for (final extra in Extra.values) extra: text,
};

void main() {
  group('extraPriceProblem', () {
    test('nothing typed: required', () {
      expect(extraPriceProblem(''), ExtraPriceProblem.required);
      expect(extraPriceProblem('   '), ExtraPriceProblem.required);
    });

    test('valid prices: 0 to 100, at most two decimals, comma or point', () {
      for (final text in ['0', '5', '4,5', '4.50', '99.99', '100', ' 7 ']) {
        expect(extraPriceProblem(text), isNull, reason: text);
      }
    });

    test('above 100: too high', () {
      expect(extraPriceProblem('100.01'), ExtraPriceProblem.tooHigh);
      expect(extraPriceProblem('2000'), ExtraPriceProblem.tooHigh);
    });

    test('anything else: invalid', () {
      for (final text in ['-1', '1.234', 'abc', r'5 $', '5.', '.5', '1e2']) {
        expect(
          extraPriceProblem(text),
          ExtraPriceProblem.invalid,
          reason: text,
        );
      }
    });
  });

  group('extraPriceText', () {
    test('a whole price has no decimals, a half price one', () {
      expect(extraPriceText(5), '5');
      expect(extraPriceText(4.5), '4.5');
      expect(extraPriceText(99.99), '99.99');
    });

    test('a stored price with more decimals is shown in full', () {
      expect(extraPriceText(4.555), '4.555');
      expect(
        extraPriceProblem(extraPriceText(4.555)),
        ExtraPriceProblem.invalid,
      );
    });

    test('a stored price above 100 is reported as too high', () {
      expect(extraPriceProblem(extraPriceText(150)), ExtraPriceProblem.tooHigh);
    });
  });

  group('extrasPricesFromInput', () {
    test('builds the four prices', () {
      final prices = extrasPricesFromInput({
        Extra.snowChains: '5',
        Extra.childSeat: '4,5',
        Extra.infantSeat: '0',
        Extra.boosterSeat: '100',
      });
      expect(prices.priceOf(Extra.snowChains), 5);
      expect(prices.priceOf(Extra.childSeat), 4.5);
      expect(prices.priceOf(Extra.infantSeat), 0);
      expect(prices.priceOf(Extra.boosterSeat), 100);
    });

    test('a stored 5 and a typed 5 are the same prices', () {
      final stored = ExtrasPrices.fromMap({
        'pricesPerDay': {for (final extra in Extra.values) extra.name: 5},
      });
      expect(extrasPricesFromInput(allPrices('5')), stored);
      expect(extrasPricesFromInput(allPrices('5.00')), stored);
    });

    test('throws when an extra is missing', () {
      expect(
        () => extrasPricesFromInput({Extra.snowChains: '5'}),
        throwsArgumentError,
      );
    });

    test('throws when a price has a problem', () {
      expect(
        () => extrasPricesFromInput(allPrices('100.01')),
        throwsArgumentError,
      );
    });
  });
}
