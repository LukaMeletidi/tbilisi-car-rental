import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';

/// Where a sign-in attempt stands.
enum AdminSignInStatus {
  /// Nothing is running.
  idle,

  /// The request is on its way.
  working,

  /// The last attempt failed; see [AdminSignInState.failure].
  failed,
}

/// The state of the sign-in form. It holds only the status and the reason
/// of a failure: never the e-mail and never the password.
class AdminSignInState {
  const AdminSignInState({this.status = AdminSignInStatus.idle, this.failure})
    : assert(
        (status == AdminSignInStatus.failed) == (failure != null),
        'a failure belongs to the failed status, and only to it',
      );

  final AdminSignInStatus status;

  /// Why the last attempt failed. Set only while [status] is
  /// [AdminSignInStatus.failed].
  final AdminSignInFailure? failure;

  bool get isWorking => status == AdminSignInStatus.working;

  @override
  String toString() =>
      'AdminSignInState(${status.name}'
      '${failure == null ? '' : ', ${failure!.name}'})';
}

/// Signs the admin in and out.
///
/// The e-mail and the password are only passed through to the repository.
/// They are not kept in the state, in a field or in a log.
class AdminSignInNotifier extends Notifier<AdminSignInState> {
  @override
  AdminSignInState build() => const AdminSignInState();

  /// Returns true when the sign-in worked. Returns false when a field is
  /// empty, when the sign-in failed (see [AdminSignInState.failure]), or
  /// when an attempt is already running; a second press sends nothing.
  ///
  /// The e-mail is trimmed; the password is sent exactly as typed.
  Future<bool> signIn({required String email, required String password}) async {
    if (state.isWorking) return false;

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      state = const AdminSignInState(
        status: AdminSignInStatus.failed,
        failure: AdminSignInFailure.missingInput,
      );
      return false;
    }

    state = const AdminSignInState(status: AdminSignInStatus.working);
    AdminSignInFailure? failure;
    try {
      await ref
          .read(adminAuthRepositoryProvider)
          .signIn(email: trimmedEmail, password: password);
    } on AdminSignInException catch (error) {
      failure = error.failure;
    } catch (_) {
      failure = AdminSignInFailure.unknown;
    }
    // The login page may be gone by now.
    if (!ref.mounted) return failure == null;

    state = failure == null
        ? const AdminSignInState()
        : AdminSignInState(status: AdminSignInStatus.failed, failure: failure);
    return failure == null;
  }

  Future<void> signOut() => ref.read(adminAuthRepositoryProvider).signOut();
}

final adminSignInProvider =
    NotifierProvider.autoDispose<AdminSignInNotifier, AdminSignInState>(
      AdminSignInNotifier.new,
    );
