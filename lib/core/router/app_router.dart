import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';
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
}

/// Tells the router to run its redirect again. The router listens to it;
/// it is notified whenever the admin session changes (sign-in, sign-out, a
/// renewed token with other claims).
class _RouterRefresh extends ChangeNotifier {
  void sessionChanged() => notifyListeners();
}

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
          // The admin area. The four pages are side by side, NOT one below
          // the other: a page below "/admin" would have the admin page
          // built underneath it, also for a visitor who is not signed in.
          GoRoute(
            path: _below(AppRoutes.admin),
            builder: (context, state) => const AdminBookingsScreen(),
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
