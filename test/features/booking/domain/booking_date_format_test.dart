import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_date_format.dart';

void main() {
  test('day.month.year hours:minutes', () {
    expect(
      formatTbilisiDateTime(TbilisiDateTime(2026, 1, 10, 18)),
      '10.01.2026 18:00',
    );
  });

  test('single digits get a leading zero', () {
    expect(
      formatTbilisiDateTime(TbilisiDateTime(2026, 3, 5, 9, 7)),
      '05.03.2026 09:07',
    );
  });

  test('midnight and the last minute of a day use the 24-hour clock', () {
    expect(
      formatTbilisiDateTime(TbilisiDateTime(2026, 12, 31)),
      '31.12.2026 00:00',
    );
    expect(
      formatTbilisiDateTime(TbilisiDateTime(2026, 12, 31, 23, 59)),
      '31.12.2026 23:59',
    );
  });

  test('shows the Tbilisi numbers, not the UTC moment', () {
    // 20:30 UTC on the 10th is 00:30 on the 11th in Tbilisi.
    final value = TbilisiDateTime.fromUtc(DateTime.utc(2026, 1, 10, 20, 30));
    expect(formatTbilisiDateTime(value), '11.01.2026 00:30');
  });
}
