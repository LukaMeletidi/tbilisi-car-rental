import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

/// A one-time notice for the bookings list: a booking has just been
/// deleted ("Booking deleted."), or was found to be deleted already.
///
/// The detail sets it right before it returns to the list. The list shows
/// it until the admin closes it. It is kept in memory only and holds no
/// data of the booking. It is forgotten when the list is left, when
/// another booking or the "new booking" form is opened, and whenever the
/// session is not admin: build() watches the session.
class AdminDeletedNoticeNotifier extends Notifier<AdminDeletedNotice?> {
  @override
  AdminDeletedNotice? build() {
    // Read only to start anew, empty, on every change of the session.
    ref.watch(adminSessionProvider);
    return null;
  }

  /// Sets the notice. Ignored when nobody is signed in as an admin.
  void show(AdminDeletedNotice notice) {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    state = notice;
  }

  /// Removes the notice. Safe to call while this provider goes away.
  void clear() {
    if (!ref.mounted) return;
    if (state != null) state = null;
  }
}

final adminDeletedNoticeProvider =
    NotifierProvider<AdminDeletedNoticeNotifier, AdminDeletedNotice?>(
      AdminDeletedNoticeNotifier.new,
    );
