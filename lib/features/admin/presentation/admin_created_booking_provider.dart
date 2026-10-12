import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

/// A one-time marker: the ID of the booking the "new booking" form has
/// just created, or null.
///
/// The form sets it right before it opens the detail of that booking. The
/// detail takes it when it has really found the booking, and then says
/// "Saved" with the notice it already has. So "Saved" is shown once, for
/// that booking only.
///
/// It holds a document ID and nothing else. It is forgotten when the
/// detail of that booking is left, and whenever the session is not admin:
/// build() watches the session.
class AdminCreatedBookingNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Read only to start anew, empty, on every change of the session.
    ref.watch(adminSessionProvider);
    return null;
  }

  /// Remembers that the booking [id] was just created. Ignored when
  /// nobody is signed in as an admin.
  void mark(String id) {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    state = id;
  }

  /// Whether the booking [id] is the one that was just created. When it
  /// is, the marker is taken: a second call answers false.
  bool take(String id) {
    if (state != id) return false;
    state = null;
    return true;
  }

  /// Forgets the marker when it is the one of [id]; the marker of another
  /// booking is left alone. Safe to call while this provider goes away.
  void clearIf(String id) {
    if (!ref.mounted) return;
    if (state == id) state = null;
  }
}

final adminCreatedBookingProvider =
    NotifierProvider<AdminCreatedBookingNotifier, String?>(
      AdminCreatedBookingNotifier.new,
    );
