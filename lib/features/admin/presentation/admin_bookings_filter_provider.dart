import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

/// What the admin chose for the bookings list: status, search and order.
///
/// It lives in memory only; nothing is written to the device, and nothing
/// here is logged (the search text can be a name or a phone number).
///
/// build() watches the admin session, so every change of the session builds
/// the choice anew: it is back to "all statuses, empty search, newest first"
/// after Sign out, and equally when the session ends by itself. While the
/// session is not admin the choice cannot be changed at all. Leaving the
/// list and coming back while signed in keeps the choice.
class AdminBookingsFilterNotifier extends Notifier<AdminBookingsFilter> {
  @override
  AdminBookingsFilter build() {
    ref.watch(adminSessionProvider);
    return const AdminBookingsFilter();
  }

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  /// Shows only [status]; null shows all statuses.
  void setStatus(BookingStatus? status) {
    if (_isAdmin) state = state.withStatus(status);
  }

  void setSearch(String search) {
    if (_isAdmin) state = state.withSearch(search);
  }

  void setSort(AdminBookingsSort sort) {
    if (_isAdmin) state = state.withSort(sort);
  }

  /// All statuses and an empty search. The order is kept.
  void clear() {
    if (_isAdmin) state = state.cleared();
  }
}

final adminBookingsFilterProvider =
    NotifierProvider<AdminBookingsFilterNotifier, AdminBookingsFilter>(
      AdminBookingsFilterNotifier.new,
    );

/// The loaded bookings as the list shows them with the current choice.
class AdminBookingsView {
  const AdminBookingsView({
    required this.visible,
    required this.counts,
    required this.loadedCount,
  });

  /// The bookings that match the choice, in the chosen order.
  final List<Booking> visible;

  /// How many loaded bookings match the search, per status.
  final Map<BookingStatus, int> counts;

  /// How many bookings are loaded; the filter and the counts cover only
  /// these.
  final int loadedCount;

  /// The number on the "All" chip.
  int get total => counts.values.fold(0, (sum, count) => sum + count);
}

/// Applies the choice to the loaded bookings. It asks Firestore for nothing.
/// The current time for the pickup order comes from [clockProvider].
final adminBookingsViewProvider = Provider.autoDispose<AdminBookingsView>((
  ref,
) {
  final bookings = ref.watch(
    adminBookingsProvider.select((state) => state.bookings),
  );
  final filter = ref.watch(adminBookingsFilterProvider);
  return AdminBookingsView(
    visible: visibleBookings(
      bookings,
      filter: filter,
      now: ref.read(clockProvider)(),
    ),
    counts: countByStatus(bookings, search: filter.search),
    loadedCount: bookings.length,
  );
});
