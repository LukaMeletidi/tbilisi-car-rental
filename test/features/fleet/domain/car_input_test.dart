import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/fleet/domain/car_input.dart';

void main() {
  group('parseDecimalInput', () {
    test('whole numbers and up to two decimals', () {
      expect(parseDecimalInput('45'), 45.0);
      expect(parseDecimalInput('45.5'), 45.5);
      expect(parseDecimalInput('45.50'), 45.5);
      expect(parseDecimalInput('0.01'), 0.01);
      expect(parseDecimalInput('2000'), 2000.0);
    });

    test('a comma is the decimal point too', () {
      expect(parseDecimalInput('45,5'), 45.5);
      expect(parseDecimalInput('1,6'), 1.6);
    });

    test('spaces at either end are ignored', () {
      expect(parseDecimalInput(' 45 '), 45.0);
    });

    test('anything else is null', () {
      for (final text in [
        '',
        '  ',
        '45.555',
        '45.',
        '.5',
        '-45',
        '+45',
        '4 5',
        '45a',
        '1e3',
        '45.5.5',
        '45,,5',
      ]) {
        expect(parseDecimalInput(text), isNull, reason: '"$text"');
      }
    });
  });

  group('formatDecimalInput', () {
    test('no trailing zeros and no needless point', () {
      expect(formatDecimalInput(45.0), '45');
      expect(formatDecimalInput(45.5), '45.5');
      expect(formatDecimalInput(45.25), '45.25');
      expect(formatDecimalInput(1.6), '1.6');
      expect(formatDecimalInput(2.0), '2');
      expect(formatDecimalInput(2000.0), '2000');
      expect(formatDecimalInput(100.0), '100');
    });

    test('a value with more than two decimals is shown in full, not '
        'rounded', () {
      expect(formatDecimalInput(45.555), '45.555');
      expect(formatDecimalInput(1.234), '1.234');
      // And the validation then refuses it.
      expect(parseDecimalInput(formatDecimalInput(45.555)), isNull);
    });

    test('a formatted value reads back as the same number', () {
      for (final value in [45.0, 45.5, 45.25, 0.01, 1.6, 1999.99]) {
        expect(parseDecimalInput(formatDecimalInput(value)), value);
      }
    });
  });
}
