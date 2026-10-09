import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';

void main() {
  test('a wrong e-mail and a wrong password are the same failure', () {
    for (final code in [
      // What Firebase sends with e-mail enumeration protection on.
      'invalid-credential',
      'invalid-login-credentials',
      // The older codes.
      'wrong-password',
      'user-not-found',
    ]) {
      expect(
        adminSignInFailureFromCode(code),
        AdminSignInFailure.wrongCredentials,
        reason: code,
      );
    }
  });

  test('invalid-email is its own failure', () {
    expect(
      adminSignInFailureFromCode('invalid-email'),
      AdminSignInFailure.invalidEmail,
    );
  });

  test('too many attempts, no connection and a disabled account each have '
      'their own failure', () {
    expect(
      adminSignInFailureFromCode('too-many-requests'),
      AdminSignInFailure.tooManyAttempts,
    );
    expect(
      adminSignInFailureFromCode('network-request-failed'),
      AdminSignInFailure.noConnection,
    );
    expect(
      adminSignInFailureFromCode('user-disabled'),
      AdminSignInFailure.accountDisabled,
    );
  });

  test('every other code is unknown', () {
    for (final code in [
      'operation-not-allowed',
      'internal-error',
      'something-new',
      '',
      '   ',
    ]) {
      expect(
        adminSignInFailureFromCode(code),
        AdminSignInFailure.unknown,
        reason: '"$code"',
      );
    }
  });

  test('upper case, underscores and spaces around the code are accepted', () {
    expect(
      adminSignInFailureFromCode('INVALID_LOGIN_CREDENTIALS'),
      AdminSignInFailure.wrongCredentials,
    );
    expect(
      adminSignInFailureFromCode(' Too-Many-Requests '),
      AdminSignInFailure.tooManyAttempts,
    );
    expect(
      adminSignInFailureFromCode('network_request_failed'),
      AdminSignInFailure.noConnection,
    );
  });

  test('every failure that Firebase can cause has at least one code', () {
    const codes = [
      'invalid-credential',
      'invalid-email',
      'too-many-requests',
      'network-request-failed',
      'user-disabled',
      'operation-not-allowed',
    ];
    final reached = {
      for (final code in codes) adminSignInFailureFromCode(code),
    };
    // missingInput is decided by the app before any request.
    expect(reached, {
      for (final failure in AdminSignInFailure.values)
        if (failure != AdminSignInFailure.missingInput) failure,
    });
  });

  test('the exception carries only the reason', () {
    const exception = AdminSignInException(AdminSignInFailure.noConnection);
    expect(exception.failure, AdminSignInFailure.noConnection);
    expect('$exception', 'AdminSignInException(noConnection)');
    expect(
      exception,
      const AdminSignInException(AdminSignInFailure.noConnection),
    );
    expect(
      exception == const AdminSignInException(AdminSignInFailure.unknown),
      false,
    );
  });
}
