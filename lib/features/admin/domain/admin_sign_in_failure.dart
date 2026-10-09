/// Why a sign-in did not work. The screen shows its own English text for
/// each value; the raw code of Firebase is never shown.
enum AdminSignInFailure {
  /// The e-mail or the password field is empty. Checked before any request.
  missingInput,

  /// The e-mail is not written like an e-mail address.
  invalidEmail,

  /// The e-mail or the password is wrong. Firebase does not say which one
  /// (e-mail enumeration protection), and neither does the app.
  wrongCredentials,

  /// Too many attempts; Firebase blocks this device for a while.
  tooManyAttempts,

  /// No connection to the server.
  noConnection,

  /// The account was disabled in the console.
  accountDisabled,

  /// Anything else. The code is logged for the developer.
  unknown,
}

/// The failure for an error [code] of Firebase Auth, such as
/// "invalid-credential".
///
/// With e-mail enumeration protection on, a wrong e-mail and a wrong
/// password both arrive as "invalid-credential". The older codes
/// "wrong-password" and "user-not-found", and "invalid-login-credentials",
/// mean the same here. Upper case and "_" are accepted, because some
/// platforms report the code that way.
AdminSignInFailure adminSignInFailureFromCode(String code) {
  switch (code.trim().toLowerCase().replaceAll('_', '-')) {
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'wrong-password':
    case 'user-not-found':
      return AdminSignInFailure.wrongCredentials;
    case 'invalid-email':
      return AdminSignInFailure.invalidEmail;
    case 'too-many-requests':
      return AdminSignInFailure.tooManyAttempts;
    case 'network-request-failed':
      return AdminSignInFailure.noConnection;
    case 'user-disabled':
      return AdminSignInFailure.accountDisabled;
    default:
      return AdminSignInFailure.unknown;
  }
}

/// Reported when a sign-in did not work. It carries only the reason: never
/// the e-mail, the password or a Firebase error type.
class AdminSignInException implements Exception {
  const AdminSignInException(this.failure);

  final AdminSignInFailure failure;

  @override
  bool operator ==(Object other) =>
      other is AdminSignInException && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'AdminSignInException(${failure.name})';
}
