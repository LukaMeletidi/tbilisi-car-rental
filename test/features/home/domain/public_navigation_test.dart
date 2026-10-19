import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/home/domain/public_navigation.dart';

void main() {
  test('the tabs, in the order of the bottom bar and the branches', () {
    expect(PublicTab.values, [
      PublicTab.home,
      PublicTab.cars,
      PublicTab.about,
      PublicTab.faq,
    ]);
  });

  test('the first page of each tab', () {
    expect(publicTabPath(PublicTab.home), '/');
    expect(publicTabPath(PublicTab.cars), '/cars');
    expect(publicTabPath(PublicTab.about), '/about');
    expect(publicTabPath(PublicTab.faq), '/faq');
  });

  test('every first page belongs to its own tab', () {
    for (final tab in PublicTab.values) {
      expect(publicTabOf(publicTabPath(tab)), tab, reason: tab.name);
    }
  });

  test('a tab page, also with the last slash', () {
    expect(publicTabOf('/cars/'), PublicTab.cars);
    expect(publicTabOf('/about/'), PublicTab.about);
    expect(publicTabOf('/faq/'), PublicTab.faq);
  });

  test('every other address is no tab page (no bottom bar)', () {
    for (final path in [
      '/cars/abc',
      '/cars/abc/book',
      '/booking-sent',
      '/admin',
      '/admin/login',
      '/carsx',
      '/aboutus',
      '/zzz',
    ]) {
      expect(publicTabOf(path), isNull, reason: path);
    }
  });

  test('Android Back: Cars, Contact and FAQ go to Home', () {
    for (final path in ['/cars', '/about', '/faq', '/faq/']) {
      expect(
        publicSystemBackTarget(isWeb: false, path: path),
        PublicTab.home,
        reason: path,
      );
    }
  });

  test('Android Back: on Home and off the tabs the router decides', () {
    for (final path in ['/', '/cars/abc', '/booking-sent', '/admin']) {
      expect(
        publicSystemBackTarget(isWeb: false, path: path),
        isNull,
        reason: path,
      );
    }
  });

  test('on the web nothing is ever intercepted', () {
    for (final path in ['/', '/cars', '/about', '/faq', '/cars/abc']) {
      expect(
        publicSystemBackTarget(isWeb: true, path: path),
        isNull,
        reason: path,
      );
    }
  });
}
