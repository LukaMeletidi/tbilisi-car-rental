import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';

/// The current admin session. It starts as [AdminSession.unknown] and then
/// follows what Firebase Auth reports.
///
/// An error of the stream becomes [AdminSession.signedOut], never admin. A
/// signed-in admin who loses the connection at the moment of such an error
/// may therefore see the login page. That is accepted: no data is shown, and
/// the Firestore rules decide what can be read.
class AdminSessionNotifier extends Notifier<AdminSession> {
  @override
  AdminSession build() {
    final subscription = ref
        .watch(adminAuthRepositoryProvider)
        .watchSession()
        .listen(
          (session) => state = session,
          onError: (Object error, StackTrace stackTrace) {
            developer.log(
              'The admin session could not be read: ${error.runtimeType}',
              name: 'AdminSessionNotifier',
              level: 900, // warning
              stackTrace: stackTrace,
            );
            state = AdminSession.signedOut;
          },
        );
    ref.onDispose(subscription.cancel);
    return AdminSession.unknown;
  }
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSession>(
      AdminSessionNotifier.new,
    );
