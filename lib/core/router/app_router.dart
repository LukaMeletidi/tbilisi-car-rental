import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_navigation.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_shell.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_screen.dart';
import 'package:tbilisi_car_rental/features/home/domain/public_navigation.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/not_found_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/public_shell.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_settings_screen.dart';

/// Route paths in one place, so screens never hard-code URL strings.
abstract final class AppRoutes {
  /// The Home tab of the public app.
  static const home = publicHomePath;

  /// The Cars tab: the catalog with its search and filter.
  static const cars = publicCarsPath;

  /// The Contact tab (About us and the contacts).
  static const about = publicAboutPath;

  /// The FAQ tab.
  static const faq = publicFaqPath;

  /// Path pattern of the car detail screen, below [cars].
  static const carPattern = ':carId';

  /// The address of one car, for example "/cars/abc123".
  static String car(String carId) => '$cars/${Uri.encodeComponent(carId)}';

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

  /// The Calendar section of the admin area.
  static const adminCalendar = adminCalendarPath;

  /// The Cars section of the admin area.
  static const adminCars = adminCarsPath;

  /// Path pattern of the "new car" form, below [adminCars]. It has one
  /// part and the edit form two, so the two never match the same address.
  static const adminCarNewPattern = 'new';

  /// The address of the "new car" form: "/admin/cars/new".
  static const adminCarNew = '$adminCars/$adminCarNewPattern';

  /// Path pattern of the edit form of one car, below [adminCars].
  static const adminCarEditPattern = ':carId/edit';

  /// The address of the edit form of one car: "/admin/cars/abc123/edit".
  static String adminCarEdit(String carId) =>
      '$adminCars/${Uri.encodeComponent(carId)}/edit';

  /// The Settings section of the admin area.
  static const adminSettings = adminSettingsPath;

  /// Path pattern of the Extras & Prices page, below [adminSettings].
  static const adminSettingsExtrasPattern = 'extras';

  /// The address of the Extras & Prices page: "/admin/settings/extras".
  static const adminSettingsExtras =
      '$adminSettings/$adminSettingsExtrasPattern';

  /// Path pattern of the Company Info page, below [adminSettings].
  static const adminSettingsCompanyPattern = 'company';

  /// The address of the Company Info page: "/admin/settings/company".
  static const adminSettingsCompany =
      '$adminSettings/$adminSettingsCompanyPattern';
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

  // The navigator of the whole app. Pages that must not show the public
  // bottom bar (the car, the booking form, the thank-you page and the
  // admin area) are put on it, above the public shell.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  // A push (Home -> a popular car, the app's only one) also shows its
  // address in the browser and adds a browser history entry, so the
  // browser's Back returns to Home as the app's back arrow does.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    // Decides for every address. It only ever moves a visitor of the admin
    // area; for a public address it always answers "stay". The rules for it
    // are pure Dart and tested in admin_redirect.dart.
    redirect: (context, state) => adminRedirect(
      session: ref.read(adminSessionProvider),
      location: state.uri,
    ),
    // A router error (an address no route matches is caught by the last
    // route below): the same public "not found" page.
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // The public app (Phase 6b): a frame with the bottom bar
      // (PublicShell) and one branch per PublicTab, in its order. Each
      // branch keeps its pages while another tab is shown (indexedStack),
      // so the catalog keeps its search, filter and scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PublicShell(navigationShell: navigationShell, path: state.uri.path),
        branches: [
          // PublicTab.home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  // Above the shell, without the bottom bar. Its system
                  // Back leads to the catalog (BookingSentScreen), never
                  // back into the form.
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: AppRoutes.bookingSentPattern,
                    builder: (context, state) => const BookingSentScreen(),
                  ),
                  ..._adminRoutes(rootNavigatorKey),
                ],
              ),
            ],
          ),
          // PublicTab.cars
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cars,
                builder: (context, state) => const CatalogScreen(),
                routes: [
                  // Above the shell, without the bottom bar; below the
                  // catalog, so Back returns to the catalog.
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: AppRoutes.carPattern,
                    builder: (context, state) =>
                        CarDetailScreen(carId: state.pathParameters['carId']!),
                    routes: [
                      // Below the car, so Back returns to the car.
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: AppRoutes.bookingPattern,
                        builder: (context, state) => BookingFormScreen(
                          carId: state.pathParameters['carId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // PublicTab.about
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.about,
                builder: (context, state) => const AboutScreen(),
              ),
            ],
          ),
          // PublicTab.faq
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.faq,
                builder: (context, state) => const FaqScreen(),
              ),
            ],
          ),
        ],
      ),
      // Every address that no route above matches: the public "not found"
      // page, on the root navigator (no bottom bar). It must stay the LAST
      // top-level route, because routes are tried in order; the admin area
      // and its own catch-all lie inside the shell and are tried first.
      // This route gives an ordinary match, so Android's system Back reaches
      // the page's PopScope; with errorBuilder alone go_router has no match
      // to pop from. errorBuilder stays for real router errors.
      GoRoute(
        path: '/:rest(.*)',
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// The admin area, below Home as before Phase 6b (so the system Back from
/// its first page still leads to the public start), but on the navigator
/// [root], above the public shell: it never shows the public bottom bar.
List<RouteBase> _adminRoutes(GlobalKey<NavigatorState> root) => [
  // The admin area: a frame with the navigation (AdminShell) and
  // one branch per AdminSection, in its order. Each branch keeps
  // its own pages while another one is shown (indexedStack), so
  // the bookings list keeps its filter and search.
  // The gate pages (login, no access, checking) are side by side
  // with this frame, NOT inside it: a visitor who is not an admin
  // must never see the navigation or have the bookings list built.
  StatefulShellRoute.indexedStack(
    parentNavigatorKey: root,
    builder: (context, state, navigationShell) =>
        AdminShell(navigationShell: navigationShell, path: state.uri.path),
    branches: [
      // AdminSection.bookings
      StatefulShellBranch(
        routes: [
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
        ],
      ),
      // AdminSection.calendar
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: _below(AppRoutes.adminCalendar),
            builder: (context, state) => const AdminCalendarScreen(),
          ),
        ],
      ),
      // AdminSection.cars
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: _below(AppRoutes.adminCars),
            builder: (context, state) => const AdminCarsScreen(),
            routes: [
              // Below the list, so Back returns to the list. Forms:
              // adminShowsNavigation hides the navigation here.
              GoRoute(
                path: AppRoutes.adminCarNewPattern,
                builder: (context, state) => const AdminCarNewScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminCarEditPattern,
                builder: (context, state) =>
                    AdminCarEditScreen(carId: state.pathParameters['carId']!),
              ),
            ],
          ),
        ],
      ),
      // AdminSection.settings
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: _below(AppRoutes.adminSettings),
            builder: (context, state) => const AdminSettingsScreen(),
            routes: [
              // Below Settings, so Back returns to Settings. Forms
              // from steps 6.6 and 6.7: adminShowsNavigation hides
              // the navigation here. Any other address below
              // Settings is the admin "not found" page.
              GoRoute(
                path: AppRoutes.adminSettingsExtrasPattern,
                builder: (context, state) => const AdminExtrasPricesScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminSettingsCompanyPattern,
                builder: (context, state) => const AdminCompanyInfoScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    parentNavigatorKey: root,
    path: _below(AppRoutes.adminLogin),
    builder: (context, state) => const AdminLoginScreen(),
  ),
  GoRoute(
    parentNavigatorKey: root,
    path: _below(AppRoutes.adminNoAccess),
    builder: (context, state) => const AdminNoAccessScreen(),
  ),
  GoRoute(
    parentNavigatorKey: root,
    path: _below(AppRoutes.adminChecking),
    builder: (context, state) => const AdminCheckingScreen(),
  ),
  // Every other address under /admin: the admin "not found" page.
  // It must stay the LAST admin route, because routes are tried in
  // order. The redirect runs first, so only an admin ever sees it.
  // An unknown public address does not match here and gets the public
  // NotFoundScreen of the last top-level route.
  GoRoute(
    parentNavigatorKey: root,
    path: '${_below(AppRoutes.admin)}/:rest(.*)',
    builder: (context, state) => const AdminNotFoundScreen(),
  ),
];
