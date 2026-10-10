import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';

/// Sign-in for the admin area. This is the only file that talks to Firebase
/// Auth; screens and providers see [AdminSession] and [AdminSignInFailure].
///
/// Nothing here logs an e-mail address or a password.
class AdminAuthRepository {
  AdminAuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Who is signed in, and whether that account is an admin.
  ///
  /// It follows idTokenChanges(): Firebase reports right after listening, on
  /// sign-in, on sign-out, and each time it renews the sign-in token (about
  /// once an hour). The claims are read from the token each time, so a claim
  /// that was set or removed with the admin script shows up at the next
  /// renewal, without asking the server more often.
  Stream<AdminSession> watchSession() {
    return _auth.idTokenChanges().asyncMap((user) async {
      if (user == null) {
        return adminSessionFromClaims(signedIn: false);
      }
      // The token Firebase already has; no extra refresh is forced.
      final token = await user.getIdTokenResult();
      final claims = token.claims;
      return adminSessionFromClaims(
        signedIn: true,
        claims: claims == null ? null : Map<String, Object?>.from(claims),
      );
    });
  }

  /// Signs in with [email] and [password]. Throws an
  /// [AdminSignInException] when it does not work.
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      // Only the code: the message of Firebase can contain the e-mail.
      _logFailure('code "${error.code}"');
      throw AdminSignInException(adminSignInFailureFromCode(error.code));
    } catch (error) {
      _logFailure('an error of type ${error.runtimeType}');
      throw const AdminSignInException(AdminSignInFailure.unknown);
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// On web: keeps the sign-in only for the browser session, so closing the
  /// browser signs the admin out (the account is shared, and a computer may
  /// be shared too). Reloading the page does not sign out.
  ///
  /// Does nothing on Android and iOS: there the sign-in always stays on the
  /// device and Firebase does not let an app change that; setPersistence
  /// exists for web only, so it is never called there.
  Future<void> keepSignInForBrowserSessionOnly() async {
    if (!kIsWeb) return;
    await _auth.setPersistence(Persistence.SESSION);
  }
}

/// Called once at app start, before anything reads the session. It never
/// stops the app: a failure, or no answer within 5 seconds, is logged and
/// the app starts as usual. It needs no network.
Future<void> limitWebSignInToBrowserSession() async {
  if (!kIsWeb) return;
  try {
    await AdminAuthRepository(
      FirebaseAuth.instance,
    ).keepSignInForBrowserSessionOnly().timeout(const Duration(seconds: 5));
  } catch (error, stackTrace) {
    developer.log(
      'The web sign-in could not be limited to the browser session: '
      '${error.runtimeType}',
      name: 'AdminAuthRepository',
      level: 900, // warning
      stackTrace: stackTrace,
    );
  }
}

void _logFailure(String what) {
  developer.log(
    'Admin sign-in failed with $what',
    name: 'AdminAuthRepository',
    level: 900, // warning
  );
}

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>(
  (ref) => AdminAuthRepository(FirebaseAuth.instance),
);
