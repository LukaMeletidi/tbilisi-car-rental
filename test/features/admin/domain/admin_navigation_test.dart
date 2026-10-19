import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_navigation.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';

const rail = AdminNavigationKind.rail;
const bar = AdminNavigationKind.bottomBar;

/// Every kind of admin address, with what it should give:
/// (path, section, section root, navigation on wide, navigation on phone).
const table = [
  ('/admin', AdminSection.bookings, true, true, true),
  ('/admin/', AdminSection.bookings, true, true, true),
  ('/admin/bookings/abc', AdminSection.bookings, false, true, false),
  ('/admin/bookings/abc/', AdminSection.bookings, false, true, false),
  ('/admin/bookings/new', AdminSection.bookings, false, false, false),
  ('/admin/bookings/new/', AdminSection.bookings, false, false, false),
  ('/admin/bookings/abc/edit', AdminSection.bookings, false, false, false),
  ('/admin/bookings/new/edit', AdminSection.bookings, false, false, false),
  ('/admin/cars', AdminSection.cars, true, true, true),
  ('/admin/cars/', AdminSection.cars, true, true, true),
  ('/admin/cars/abc', AdminSection.cars, false, false, false),
  ('/admin/cars/new', AdminSection.cars, false, false, false),
  ('/admin/cars/abc/edit', AdminSection.cars, false, false, false),
  (adminLoginPath, null, false, false, false),
  (adminNoAccessPath, null, false, false, false),
  (adminCheckingPath, null, false, false, false),
  ('/admin/bookings', null, false, false, false),
  ('/admin/unknown', null, false, false, false),
  ('/admin/carsx', null, false, false, false),
  ('/', null, false, false, false),
  ('/cars/abc', null, false, false, false),
  ('/administrator', null, false, false, false),
];

void main() {
  test('the sections, in the order of the router branches', () {
    expect(AdminSection.values, [
      AdminSection.bookings,
      AdminSection.calendar,
      AdminSection.cars,
      AdminSection.settings,
    ]);
    expect(adminSectionPath(AdminSection.bookings), '/admin');
    expect(adminSectionPath(AdminSection.cars), '/admin/cars');
    expect(adminCarsPath, '/admin/cars');
  });

  test('every first page belongs to its own section', () {
    for (final section in AdminSection.values) {
      final path = adminSectionPath(section);
      expect(adminSectionOf(path), section);
      expect(isAdminSectionRoot(path), true);
    }
  });

  test('the section of every admin address', () {
    for (final row in table) {
      expect(adminSectionOf(row.$1), row.$2, reason: row.$1);
    }
  });

  test('the first page of a section', () {
    for (final row in table) {
      expect(isAdminSectionRoot(row.$1), row.$3, reason: row.$1);
    }
  });

  test('which page shows the rail (wide screens)', () {
    for (final row in table) {
      expect(adminShowsNavigation(row.$1, rail), row.$4, reason: row.$1);
    }
  });

  test('which page shows the bottom bar (phones)', () {
    for (final row in table) {
      expect(adminShowsNavigation(row.$1, bar), row.$5, reason: row.$1);
    }
  });

  test('a form never shows the navigation, on any width', () {
    for (final path in [
      '/admin/bookings/new',
      '/admin/bookings/abc/edit',
      '/admin/cars/new',
      '/admin/cars/abc/edit',
    ]) {
      for (final kind in AdminNavigationKind.values) {
        expect(adminShowsNavigation(path, kind), false, reason: '$path $kind');
      }
    }
  });

  test('the rail from 600 pixels wide, the bottom bar below', () {
    expect(adminRailMinWidth, 600);
    expect(adminNavigationKind(320), bar);
    expect(adminNavigationKind(599), bar);
    expect(adminNavigationKind(599.9), bar);
    expect(adminNavigationKind(600), rail);
    expect(adminNavigationKind(1200), rail);
  });

  group('the Calendar section (step 5.5a)', () {
    test('its first page, with and without the last slash', () {
      expect(adminCalendarPath, '/admin/calendar');
      expect(adminSectionPath(AdminSection.calendar), '/admin/calendar');
      for (final path in ['/admin/calendar', '/admin/calendar/']) {
        expect(adminSectionOf(path), AdminSection.calendar, reason: path);
        expect(isAdminSectionRoot(path), true, reason: path);
        expect(adminShowsNavigation(path, rail), true, reason: path);
        expect(adminShowsNavigation(path, bar), true, reason: path);
      }
    });

    test('a page below it is Calendar, not a first page, no navigation', () {
      expect(adminSectionOf('/admin/calendar/x'), AdminSection.calendar);
      expect(isAdminSectionRoot('/admin/calendar/x'), false);
      for (final kind in AdminNavigationKind.values) {
        expect(adminShowsNavigation('/admin/calendar/x', kind), false);
      }
    });

    test('a look-alike address is no section', () {
      expect(adminSectionOf('/admin/calendarx'), isNull);
      expect(isAdminSectionRoot('/admin/calendarx'), false);
    });

    test('Android Back on Calendar goes to Bookings; never on the web', () {
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/calendar'),
        AdminSection.bookings,
      );
      expect(
        adminSystemBackTarget(isWeb: true, path: '/admin/calendar'),
        isNull,
      );
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/calendar/x'),
        isNull,
      );
    });
  });

  group('the Settings section (step 6.5)', () {
    test('its first page, with and without the last slash', () {
      expect(adminSettingsPath, '/admin/settings');
      expect(adminSectionPath(AdminSection.settings), '/admin/settings');
      expect(AdminSection.settings.index, 3);
      for (final path in ['/admin/settings', '/admin/settings/']) {
        expect(adminSectionOf(path), AdminSection.settings, reason: path);
        expect(isAdminSectionRoot(path), true, reason: path);
        expect(adminShowsNavigation(path, rail), true, reason: path);
        expect(adminShowsNavigation(path, bar), true, reason: path);
      }
    });

    test('its two pages: Settings, not a first page, no navigation', () {
      for (final path in [
        '/admin/settings/extras',
        '/admin/settings/company',
        '/admin/settings/company/',
      ]) {
        expect(adminSectionOf(path), AdminSection.settings, reason: path);
        expect(isAdminSectionRoot(path), false, reason: path);
        for (final kind in AdminNavigationKind.values) {
          expect(adminShowsNavigation(path, kind), false, reason: path);
        }
      }
    });

    test('an unknown page below it: Settings, not a first page', () {
      expect(adminSectionOf('/admin/settings/x'), AdminSection.settings);
      expect(isAdminSectionRoot('/admin/settings/x'), false);
    });

    test('a look-alike address is no section', () {
      expect(adminSectionOf('/admin/settingsx'), isNull);
      expect(isAdminSectionRoot('/admin/settingsx'), false);
      expect(adminSectionOf('/admin/setting'), isNull);
    });

    test('Android Back on Settings goes to Bookings; never on the web', () {
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/settings'),
        AdminSection.bookings,
      );
      expect(
        adminSystemBackTarget(isWeb: true, path: '/admin/settings'),
        isNull,
      );
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/settings/extras'),
        isNull,
      );
    });
  });

  group('adminSystemBackTarget', () {
    test('on the web it never intercepts anything', () {
      for (final row in table) {
        expect(
          adminSystemBackTarget(isWeb: true, path: row.$1),
          isNull,
          reason: row.$1,
        );
      }
    });

    test('elsewhere: from the first page of Cars to Bookings', () {
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/cars'),
        AdminSection.bookings,
      );
      expect(
        adminSystemBackTarget(isWeb: false, path: '/admin/cars/'),
        AdminSection.bookings,
      );
    });

    test('elsewhere: the router decides on every other page', () {
      for (final path in [
        '/admin',
        '/admin/bookings/abc',
        '/admin/bookings/new',
        '/admin/bookings/abc/edit',
        '/admin/cars/abc',
        adminLoginPath,
        '/admin/unknown',
        '/',
      ]) {
        expect(
          adminSystemBackTarget(isWeb: false, path: path),
          isNull,
          reason: path,
        );
      }
    });
  });
}
