import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';

AdminSession signedInWith(Map<String, Object?>? claims) =>
    adminSessionFromClaims(signedIn: true, claims: claims);

void main() {
  test('nobody signed in is signedOut, whatever the claims say', () {
    expect(adminSessionFromClaims(signedIn: false), AdminSession.signedOut);
    expect(
      adminSessionFromClaims(signedIn: false, claims: {'admin': true}),
      AdminSession.signedOut,
    );
  });

  test('admin: true is admin', () {
    expect(signedInWith({'admin': true}), AdminSession.admin);
  });

  test('no claims, an empty map and other claims only are noAccess', () {
    expect(signedInWith(null), AdminSession.noAccess);
    expect(signedInWith({}), AdminSession.noAccess);
    expect(signedInWith({'team': 'a', 'iat': 1}), AdminSession.noAccess);
  });

  test('admin false, the text "true", the number 1 and null are noAccess', () {
    for (final value in <Object?>[false, 'true', 'TRUE', 1, 1.0, null, []]) {
      expect(
        signedInWith({'admin': value}),
        AdminSession.noAccess,
        reason: 'admin: $value (${value.runtimeType})',
      );
    }
  });

  test('a claim with another spelling does not count', () {
    expect(signedInWith({'Admin': true}), AdminSession.noAccess);
    expect(signedInWith({'isAdmin': true}), AdminSession.noAccess);
    expect(signedInWith({'admin ': true}), AdminSession.noAccess);
  });

  test('other claims next to admin: true do not matter', () {
    expect(
      signedInWith({'admin': true, 'team': 'a', 'email_verified': false}),
      AdminSession.admin,
    );
  });

  test('the session is never unknown once Firebase has answered', () {
    for (final signedIn in [true, false]) {
      for (final claims in <Map<String, Object?>?>[
        null,
        {},
        {'admin': true},
      ]) {
        expect(
          adminSessionFromClaims(signedIn: signedIn, claims: claims),
          isNot(AdminSession.unknown),
        );
      }
    }
  });
}
