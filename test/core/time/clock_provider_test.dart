import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/time/clock_provider.dart';

void main() {
  test('gives the current moment as a UTC date', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = DateTime.now().toUtc();
    final now = container.read(clockProvider)();
    final after = DateTime.now().toUtc();

    expect(now.isUtc, true);
    expect(now.isBefore(before), false);
    expect(now.isAfter(after), false);
  });

  test('can be replaced by a fixed moment', () {
    final fixed = DateTime.utc(2026, 1, 1, 8);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => fixed)],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider)(), fixed);
  });
}
