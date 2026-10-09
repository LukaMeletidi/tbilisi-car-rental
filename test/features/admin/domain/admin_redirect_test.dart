import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';

String? redirect(AdminSession session, String location) =>
    adminRedirect(session: session, location: Uri.parse(location));

/// A gate page with [from] carried in its query, properly encoded.
String withFrom(String page, String from) =>
    Uri(path: page, queryParameters: {'from': from}).toString();

const publicAddresses = [
  '/',
  '/cars/abc123',
  '/cars/abc123/book',
  '/booking-sent',
  '/administrator',
  '/cars/admin',
  '/admins',
];

const contentAddresses = ['/admin', '/admin/bookings', '/admin/bookings/abc'];

const gateAddresses = [adminLoginPath, adminNoAccessPath, adminCheckingPath];

void main() {
  test('public addresses are never redirected, for every session', () {
    for (final session in AdminSession.values) {
      for (final address in publicAddresses) {
        expect(redirect(session, address), isNull, reason: '$session $address');
        expect(
          redirect(session, '$address?from=/admin/bookings'),
          isNull,
          reason: '$session $address with from',
        );
      }
    }
  });

  test('isAdminPath: /admin and below, nothing that only looks like it', () {
    for (final path in ['/admin', '/admin/login', '/admin/bookings/abc']) {
      expect(isAdminPath(path), true, reason: path);
    }
    for (final path in publicAddresses) {
      expect(isAdminPath(path), false, reason: path);
    }
  });

  group('session not known yet', () {
    test('every admin address goes to the checking page', () {
      expect(redirect(AdminSession.unknown, '/admin'), adminCheckingPath);
      expect(redirect(AdminSession.unknown, adminLoginPath), adminCheckingPath);
      expect(
        redirect(AdminSession.unknown, adminNoAccessPath),
        adminCheckingPath,
      );
    });

    test('the checking page stays', () {
      expect(redirect(AdminSession.unknown, adminCheckingPath), isNull);
      expect(
        redirect(
          AdminSession.unknown,
          withFrom(adminCheckingPath, '/admin/bookings'),
        ),
        isNull,
      );
    });

    test('the wanted address is carried in "from"; /admin carries none', () {
      expect(
        redirect(AdminSession.unknown, '/admin/bookings/abc'),
        withFrom(adminCheckingPath, '/admin/bookings/abc'),
      );
      expect(redirect(AdminSession.unknown, '/admin'), adminCheckingPath);
    });

    test('a "from" on the login page is kept on the way to checking', () {
      expect(
        redirect(
          AdminSession.unknown,
          withFrom(adminLoginPath, '/admin/bookings'),
        ),
        withFrom(adminCheckingPath, '/admin/bookings'),
      );
    });
  });

  group('signed out', () {
    test('admin addresses go to the login page, with "from"', () {
      expect(redirect(AdminSession.signedOut, '/admin'), adminLoginPath);
      expect(
        redirect(AdminSession.signedOut, '/admin/bookings/abc'),
        withFrom(adminLoginPath, '/admin/bookings/abc'),
      );
      expect(
        redirect(AdminSession.signedOut, adminNoAccessPath),
        adminLoginPath,
      );
    });

    test('the login page stays', () {
      expect(redirect(AdminSession.signedOut, adminLoginPath), isNull);
      expect(
        redirect(
          AdminSession.signedOut,
          withFrom(adminLoginPath, '/admin/bookings'),
        ),
        isNull,
      );
    });

    test('the checking page hands its "from" on to the login page', () {
      expect(
        redirect(
          AdminSession.signedOut,
          withFrom(adminCheckingPath, '/admin/bookings'),
        ),
        withFrom(adminLoginPath, '/admin/bookings'),
      );
      expect(
        redirect(AdminSession.signedOut, adminCheckingPath),
        adminLoginPath,
      );
    });
  });

  group('signed in without the claim', () {
    test('everything under /admin goes to the no-access page', () {
      for (final address in [
        ...contentAddresses,
        adminLoginPath,
        adminCheckingPath,
        withFrom(adminLoginPath, '/admin/bookings'),
      ]) {
        expect(
          redirect(AdminSession.noAccess, address),
          adminNoAccessPath,
          reason: address,
        );
      }
    });

    test('the no-access page stays', () {
      expect(redirect(AdminSession.noAccess, adminNoAccessPath), isNull);
    });
  });

  group('admin', () {
    test('content addresses stay', () {
      for (final address in contentAddresses) {
        expect(redirect(AdminSession.admin, address), isNull, reason: address);
      }
    });

    test('on a gate page the admin goes to "from"', () {
      for (final gate in gateAddresses) {
        expect(
          redirect(AdminSession.admin, withFrom(gate, '/admin/bookings/abc')),
          '/admin/bookings/abc',
          reason: gate,
        );
      }
    });

    test('on a gate page without "from" the admin goes to /admin', () {
      for (final gate in gateAddresses) {
        expect(redirect(AdminSession.admin, gate), adminHomePath, reason: gate);
      }
    });

    test('/admin/checking with no "from" goes to /admin', () {
      expect(redirect(AdminSession.admin, '/admin/checking'), '/admin');
    });
  });

  group('"from" is ignored (the admin lands on /admin)', () {
    void ignored(String from) {
      for (final gate in gateAddresses) {
        expect(
          redirect(AdminSession.admin, withFrom(gate, from)),
          adminHomePath,
          reason: '$gate from "$from"',
        );
      }
      // And it is not carried along for a visitor who is not signed in.
      expect(
        redirect(AdminSession.signedOut, withFrom(adminCheckingPath, from)),
        adminLoginPath,
        reason: 'signed out, from "$from"',
      );
    }

    test('when it is a gate page', () {
      for (final gate in gateAddresses) {
        ignored(gate);
      }
    });

    test('when it is a public route or another site', () {
      ignored('/');
      ignored('/cars/abc123');
      ignored('https://example.com/admin/bookings');
      ignored('//example.com/admin');
      ignored('example.com');
    });

    test('when it contains ".." or "//"', () {
      ignored('/admin/../cars/abc');
      ignored('/admin//bookings');
    });

    test('when it contains "?"', () {
      ignored('/admin/bookings?status=new');
    });

    test('when it contains "#"', () {
      ignored('/admin/bookings#top');
    });

    test('when it contains a backslash', () {
      ignored(r'/admin\bookings');
      ignored(r'/admin/bookings\..\login');
    });

    test('when it is a login address that carries another "from"', () {
      ignored('/admin/login?from=/admin/x');
    });

    test('when it is empty', () {
      ignored('');
    });
  });

  test('a trailing slash is the same page: no row of the table breaks', () {
    // Decision: "/admin/" is treated as "/admin", and "/admin/login/" as
    // "/admin/login". One slash at the end is dropped before comparing.
    expect(redirect(AdminSession.admin, '/admin/'), isNull);
    expect(redirect(AdminSession.signedOut, '/admin/'), adminLoginPath);
    expect(redirect(AdminSession.unknown, '/admin/'), adminCheckingPath);
    expect(redirect(AdminSession.noAccess, '/admin/'), adminNoAccessPath);

    expect(redirect(AdminSession.signedOut, '/admin/login/'), isNull);
    expect(redirect(AdminSession.admin, '/admin/login/'), adminHomePath);
    expect(redirect(AdminSession.unknown, '/admin/login/'), adminCheckingPath);
    expect(redirect(AdminSession.noAccess, '/admin/login/'), adminNoAccessPath);

    expect(redirect(AdminSession.unknown, '/admin/checking/'), isNull);
    expect(redirect(AdminSession.noAccess, '/admin/no-access/'), isNull);
    // A content address keeps its meaning and is carried without the slash.
    expect(
      redirect(AdminSession.signedOut, '/admin/bookings/'),
      withFrom(adminLoginPath, '/admin/bookings'),
    );
  });

  test('no loop: the result of a redirect is not redirected again', () {
    final addresses = [
      ...publicAddresses,
      ...contentAddresses,
      ...gateAddresses,
      '/admin/',
      '/admin/login/',
      '/admin/bookings/',
      for (final gate in gateAddresses) ...[
        withFrom(gate, '/admin/bookings/abc'),
        withFrom(gate, '/admin/login?from=/admin/x'),
        withFrom(gate, 'https://example.com'),
      ],
    ];
    for (final session in AdminSession.values) {
      for (final address in addresses) {
        final first = redirect(session, address);
        if (first == null) continue;
        expect(
          redirect(session, first),
          isNull,
          reason: '$session: $address -> $first is redirected again',
        );
      }
    }
  });

  test('no leak: only an admin ever stays on a content address', () {
    for (final session in AdminSession.values) {
      for (final address in [...contentAddresses, '/admin/', '/admin/x/y']) {
        final stays = redirect(session, address) == null;
        expect(
          stays,
          session == AdminSession.admin,
          reason: '$session $address',
        );
      }
    }
  });

  test('a redirect never leaves the admin area', () {
    for (final session in AdminSession.values) {
      for (final from in ['https://example.com', '/cars/abc', '//x', '']) {
        for (final gate in gateAddresses) {
          final result = redirect(session, withFrom(gate, from));
          if (result == null) continue;
          expect(
            isAdminPath(Uri.parse(result).path),
            true,
            reason: '$session $gate from "$from" -> $result',
          );
        }
      }
    }
  });
}
