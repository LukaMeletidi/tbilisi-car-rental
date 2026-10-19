import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';

void main() {
  group('AppRoutes.car', () {
    test('builds the address of a car', () {
      expect(AppRoutes.car('abc123'), '/cars/abc123');
    });

    test('encodes characters that are not safe in an address', () {
      expect(AppRoutes.car('a b'), '/cars/a%20b');
      expect(AppRoutes.car('a/b'), '/cars/a%2Fb');
    });
  });

  group('AppRoutes.booking', () {
    test('is the address of the car followed by /book', () {
      expect(AppRoutes.booking('abc123'), '/cars/abc123/book');
      expect(AppRoutes.booking('a b'), '/cars/a%20b/book');
    });
  });

  test('the thank-you screen is below the catalog', () {
    expect(AppRoutes.bookingSent, '/booking-sent');
  });

  test('the four tabs of the public app (Phase 6b)', () {
    expect(AppRoutes.home, '/');
    expect(AppRoutes.cars, '/cars');
    expect(AppRoutes.about, '/about');
    expect(AppRoutes.faq, '/faq');
    // The car page lies below the Cars tab.
    expect(AppRoutes.car('abc'), '${AppRoutes.cars}/abc');
  });
}
