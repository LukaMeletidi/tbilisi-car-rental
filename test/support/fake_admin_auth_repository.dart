import 'dart:async';

import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';

/// Stands in for Firebase Auth in tests. Nothing here contacts Firebase.
///
/// The router reads the admin session at start, so every test that builds
/// the real router needs this in place of the real repository.
class FakeAdminAuthRepository implements AdminAuthRepository {
  /// [initial] is reported at once, as Firebase does for a visitor it
  /// already knows. With null the session stays "unknown" until [report].
  FakeAdminAuthRepository({AdminSession? initial = AdminSession.signedOut}) {
    if (initial != null) _sessions.add(initial);
  }

  final _sessions = StreamController<AdminSession>();

  /// Every sign-in attempt that reached the repository.
  final signIns = <({String email, String password})>[];
  var signOuts = 0;
  var persistenceCalls = 0;

  /// When set, signIn waits for it.
  Completer<void>? pending;

  /// When set, signIn fails with it.
  Object? error;

  /// What the session becomes after a successful sign-in.
  AdminSession sessionAfterSignIn = AdminSession.admin;

  /// Makes Firebase "answer" with [session].
  void report(AdminSession session) => _sessions.add(session);

  void close() => unawaited(_sessions.close());

  @override
  Stream<AdminSession> watchSession() => _sessions.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add((email: email, password: password));
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
    _sessions.add(sessionAfterSignIn);
  }

  @override
  Future<void> signOut() async {
    signOuts += 1;
    _sessions.add(AdminSession.signedOut);
  }

  @override
  Future<void> keepSignInForBrowserSessionOnly() async {
    persistenceCalls += 1;
  }
}
