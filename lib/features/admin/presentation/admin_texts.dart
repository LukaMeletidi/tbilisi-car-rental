/// The texts of the admin area. The admin area is English only, so they are
/// plain constants here and not in the translation files.
library;

import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';

const adminSignInTitle = 'Admin sign-in';
const adminEmailLabel = 'E-mail';
const adminPasswordLabel = 'Password';
const adminShowPassword = 'Show the password';
const adminHidePassword = 'Hide the password';
const adminSignInButton = 'Sign in';
const adminSigningIn = 'Signing in…';
const adminSignOutButton = 'Sign out';

const adminNoAccessText = 'This account has no admin access.';

const adminHomeTitle = 'Admin';
const adminHomeSignedIn = 'Signed in as an administrator.';
const adminHomeComingNext = 'The bookings list comes in the next step.';

/// The text shown for a failed sign-in. The raw code of Firebase is never
/// shown, and a wrong e-mail is not told apart from a wrong password.
String adminSignInFailureText(AdminSignInFailure failure) {
  switch (failure) {
    case AdminSignInFailure.missingInput:
      return 'Enter your e-mail and password.';
    case AdminSignInFailure.invalidEmail:
      return 'This e-mail address is not valid.';
    case AdminSignInFailure.wrongCredentials:
      return 'The e-mail or the password is wrong.';
    case AdminSignInFailure.tooManyAttempts:
      return 'Too many attempts. Wait a few minutes and try again.';
    case AdminSignInFailure.noConnection:
      return 'No connection. Check your internet and try again.';
    case AdminSignInFailure.accountDisabled:
      return 'This account is disabled.';
    case AdminSignInFailure.unknown:
      return 'Sign-in did not work. Please try again.';
  }
}
