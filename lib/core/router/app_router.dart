import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';

/// Route paths in one place, so screens never hard-code URL strings.
abstract final class AppRoutes {
  static const home = '/';

  /// Path pattern of the car detail screen, below [home].
  static const carPattern = 'cars/:carId';

  /// The address of one car, for example "/cars/abc123".
  static String car(String carId) => '/cars/${Uri.encodeComponent(carId)}';

  /// Path pattern of the booking form, below the car detail screen.
  static const bookingPattern = 'book';

  /// The address of the booking form of one car: "/cars/abc123/book".
  static String booking(String carId) => '${car(carId)}/$bookingPattern';

  /// Path pattern of the thank-you screen, below [home].
  static const bookingSentPattern = 'booking-sent';

  /// The address of the thank-you screen shown after a request was sent.
  static const bookingSent = '/$bookingSentPattern';

  /// The admin area. Its addresses are defined with the redirect rules in
  /// admin_redirect.dart; nothing in the public app links to them.
  static const admin = adminHomePath;
  static const adminLogin = adminLoginPath;
  static const adminNoAccess = adminNoAccessPath;
  static const adminChecking = adminCheckingPath;

  /// Path pattern of the detail of one booking, below [admin].
  static const adminBookingPattern = 'bookings/:bookingId';

  /// The address of one booking of the admin area:
  /// "/admin/bookings/abc123".
  static String adminBooking(String bookingId) =>
      '$admin/bookings/${Uri.encodeComponent(bookingId)}';

  /// Path pattern of the "new booking" form, below [admin]. Its last part
  /// would also pass as a booking ID, so its route must come BEFORE
  /// [adminBookingPattern]: routes are tried in order.
  static const adminBookingNewPattern = 'bookings/$adminNewBookingPathSegment';

  /// The address of the "new booking" form: "/admin/bookings/new".
  static const adminBookingNew = '$admin/$adminBookingNewPattern';

  /// Path pattern of the edit form of one booking, below its detail.
  static const adminBookingEditPattern = 'edit';

  /// The address of the edit form of one booking:
  /// "/admin/bookings/abc123/edit".
  static String adminBookingEdit(String bookingId) =>
      '${adminBooking(bookingId)}/$adminBookingEditPattern';
}

/// Tells the router to run its redirect again. The router listens to it;
/// it is notified whenever the admin session changes (sign-in, sign-out, a
/// renewed token with other claims).
class _RouterRefresh extends ChangeNotifier {
  void sessionChanged() => notifyListeners();
}

/// Whether the booking ID of the address is the reserved word "new". No
/// booking has that ID: it is the address of the "new booking" form.
bool _isReservedId(GoRouterState state) =>
    state.pathParameters['bookingId'] == adminNewBookingPathSegment;

/// "/admin/login" becomes "admin/login": the pattern of a route below [home].
String _below(String path) => path.substring(1);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  // Also starts the session provider, so the session is being read from
  // the first moment on.
  ref.listen(adminSessionProvider, (previous, next) {
    refresh.sessionChanged();
  });

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    // Decides for every address. It only ever moves a visitor of the admin
    // area; for a public address it always answers "stay". The rules for it
    // are pure Dart and tested in admin_redirect.dart.
    redirect: (context, state) => adminRedirect(
      session: ref.read(adminSessionProvider),
      location: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const CatalogScreen(),
        routes: [
          GoRoute(
            path: AppRoutes.carPattern,
            builder: (context, state) =>
                CarDetailScreen(carId: state.pathParameters['carId']!),
            routes: [
              // Below the car, so Back returns to the car.
              GoRoute(
                path: AppRoutes.bookingPattern,
                builder: (context, state) =>
                    BookingFormScreen(carId: state.pathParameters['carId']!),
              ),
            ],
          ),
          // Below the catalog, so Back leads to the catalog and never back
          // into the form.
          GoRoute(
            path: AppRoutes.bookingSentPattern,
            builder: (context, state) => const BookingSentScreen(),
          ),
          // The admin area. The gate pages (login, no access, checking)
          // are side by side with the admin page, NOT below it: a page
          // below "/admin" has the bookings list built underneath it, and
          // that must never happen for a visitor who is not an admin.
          GoRoute(
            path: _below(AppRoutes.admin),
            builder: (context, state) => const AdminBookingsScreen(),
            routes: [
              // Admin content, so it IS below the list: Back returns to
              // the list. The redirect runs first, so only an admin ever
              // gets here. Opening this address directly also builds the
              // list underneath, which starts the list's listener.
              // The "new booking" form. It MUST stay before the detail:
              // "new" would match ":bookingId" too.
              GoRoute(
                path: AppRoutes.adminBookingNewPattern,
                builder: (context, state) => const AdminBookingNewScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminBookingPattern,
                builder: (context, state) => _isReservedId(state)
                    ? const AdminNotFoundScreen()
                    : AdminBookingDetailScreen(
                        bookingId: state.pathParameters['bookingId']!,
                      ),
                routes: [
                  // Below the detail, so Back returns to the detail.
                  // Opening this address directly builds the list and
                  // the detail underneath, with their listeners.
                  GoRoute(
                    path: AppRoutes.adminBookingEditPattern,
                    // "/admin/bookings/new/edit" would be the edit form
                    // of a booking called "new"; there is none.
                    builder: (context, state) => _isReservedId(state)
                        ? const AdminNotFoundScreen()
                        : AdminBookingEditScreen(
                            bookingId: state.pathParameters['bookingId']!,
                          ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: _below(AppRoutes.adminLogin),
            builder: (context, state) => const AdminLoginScreen(),
          ),
          GoRoute(
            path: _below(AppRoutes.adminNoAccess),
            builder: (context, state) => const AdminNoAccessScreen(),
          ),
          GoRoute(
            path: _below(AppRoutes.adminChecking),
            builder: (context, state) => const AdminCheckingScreen(),
          ),
          // Every other address under /admin: the admin "not found" page.
          // It must stay the LAST admin route, because routes are tried in
          // order. The redirect runs first, so only an admin ever sees it.
          // An unknown public address does not match and keeps go_router's
          // own "Page Not Found" screen.
          GoRoute(
            path: '${_below(AppRoutes.admin)}/:rest(.*)',
            builder: (context, state) => const AdminNotFoundScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
