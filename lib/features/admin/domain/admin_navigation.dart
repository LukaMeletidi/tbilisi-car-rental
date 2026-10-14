/// The navigation of the admin area: its sections, which page shows the
/// navigation, and where Android's system Back goes. Pure Dart.
library;

import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_redirect.dart';

/// The sections of the admin area, in the order of the navigation. The
/// index of a section is the index of its branch in the router.
enum AdminSection { bookings, cars }

/// The first page of the Cars section.
const adminCarsPath = '$adminHomePath/cars';

/// Below this width the navigation is a bottom bar, from it on a side rail.
const adminRailMinWidth = 600.0;

enum AdminNavigationKind { bottomBar, rail }

AdminNavigationKind adminNavigationKind(double width) =>
    width >= adminRailMinWidth
    ? AdminNavigationKind.rail
    : AdminNavigationKind.bottomBar;

String _withoutTrailingSlash(String path) =>
    path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

/// The section the address [path] belongs to, or null for a gate page or an
/// address outside the two sections (those pages have no navigation).
AdminSection? adminSectionOf(String path) {
  final p = _withoutTrailingSlash(path);
  if (p == adminCarsPath || p.startsWith('$adminCarsPath/')) {
    return AdminSection.cars;
  }
  if (p == adminHomePath || p.startsWith('$adminHomePath/bookings/')) {
    return AdminSection.bookings;
  }
  return null;
}

/// The first page of [section].
String adminSectionPath(AdminSection section) {
  switch (section) {
    case AdminSection.bookings:
      return adminHomePath;
    case AdminSection.cars:
      return adminCarsPath;
  }
}

/// Whether [path] is the first page of a section.
bool isAdminSectionRoot(String path) {
  final p = _withoutTrailingSlash(path);
  return p == adminHomePath || p == adminCarsPath;
}

final _bookingDetail = RegExp(r'^/admin/bookings/[^/]+$');

/// Whether the page at [path] shows the navigation of [kind].
///
/// A FORM never shows it, on any width: the new-booking and the edit pages
/// (and later the car forms). A click on the rail or the bar is not a Back,
/// so it would not ask "Discard your changes?" and typed data would be lost.
///
/// - Phone (bottom bar): only on the first page of a section, the bookings
///   list and Cars.
/// - Wide (rail): on the bookings list, on the detail of a booking and on
///   Cars.
/// - Never on a gate page, on the "not found" page or outside the admin area.
bool adminShowsNavigation(String path, AdminNavigationKind kind) {
  final p = _withoutTrailingSlash(path);
  if (isAdminSectionRoot(p)) return true;
  if (kind == AdminNavigationKind.bottomBar) return false;
  if (p == '$adminHomePath/bookings/$adminNewBookingPathSegment') return false;
  return _bookingDetail.hasMatch(p);
}

/// Where Android's system Back goes, or null when the shell leaves it to
/// the router (which then leaves the admin area, as before).
///
/// Only on Android and other non-web platforms: on the web the browser's
/// Back works by its history and must never be intercepted, so [isWeb]
/// always gives null. Otherwise: on the first page of a section other than
/// Bookings, Back goes to Bookings; everywhere else the router decides.
AdminSection? adminSystemBackTarget({
  required bool isWeb,
  required String path,
}) {
  if (isWeb) return null;
  if (!isAdminSectionRoot(path)) return null;
  final section = adminSectionOf(path);
  if (section == null || section == AdminSection.bookings) return null;
  return AdminSection.bookings;
}
