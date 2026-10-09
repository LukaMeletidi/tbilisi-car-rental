import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';

/// The bookings list, and the root of the admin area.
const adminHomePath = '/admin';

/// The sign-in page.
const adminLoginPath = '/admin/login';

/// The page for a signed-in account that has no admin claim.
const adminNoAccessPath = '/admin/no-access';

/// A page with only a spinner, shown while the session is not known yet.
const adminCheckingPath = '/admin/checking';

/// Whether [path] belongs to the admin area.
bool isAdminPath(String path) =>
    path == adminHomePath || path.startsWith('$adminHomePath/');

// "/admin/" and "/admin/login/" are the same pages as "/admin" and
// "/admin/login": one slash at the end is dropped before anything is
// compared.
String _withoutTrailingSlash(String path) =>
    path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

// The three pages that are not admin content: they are shown instead of it.
bool _isGatePath(String path) =>
    path == adminLoginPath ||
    path == adminNoAccessPath ||
    path == adminCheckingPath;

// An address inside the admin area that a visitor may be sent on to. Only a
// plain admin path is accepted: never a gate page, never an address outside
// the admin area, and nothing with a query, a fragment, a backslash, ".."
// or "//". So "from" cannot lead anywhere else, and it cannot carry another
// "from" inside it.
String? _allowedTarget(String? rawPath) {
  if (rawPath == null) return null;
  const forbidden = ['?', '#', r'\', '..', '//'];
  if (forbidden.any(rawPath.contains)) return null;
  final path = _withoutTrailingSlash(rawPath);
  if (path == adminHomePath) return null;
  if (!isAdminPath(path) || _isGatePath(path)) return null;
  return path;
}

String _withFrom(String path, String? from) {
  if (from == null) return path;
  return Uri(path: path, queryParameters: {'from': from}).toString();
}

/// Where the router must send a visitor of [location], or null to stay.
///
/// Only addresses of the admin area are ever redirected; the public routes
/// (the catalog, a car, the booking form, the thank-you screen) always get
/// null. This only chooses pages: the Firestore rules protect the data.
///
/// - Session not known yet: every admin address goes to the checking page,
///   which shows only a spinner. No login page flashes and no admin page is
///   built. The address that was asked for travels along as "from".
/// - Signed out: to the login page, with "from".
/// - Signed in without the claim: to the "no admin access" page.
/// - Admin: content addresses stay; from one of the three gate pages the
///   admin goes on to "from", or to the bookings list.
String? adminRedirect({required AdminSession session, required Uri location}) {
  final path = _withoutTrailingSlash(location.path);
  if (!isAdminPath(path)) return null;

  // Where the visitor wanted to go: the page itself, or, on a gate page,
  // the address carried in "from".
  final wanted = _isGatePath(path)
      ? _allowedTarget(location.queryParameters['from'])
      : _allowedTarget(path);

  switch (session) {
    case AdminSession.unknown:
      return path == adminCheckingPath
          ? null
          : _withFrom(adminCheckingPath, wanted);
    case AdminSession.signedOut:
      return path == adminLoginPath ? null : _withFrom(adminLoginPath, wanted);
    case AdminSession.noAccess:
      return path == adminNoAccessPath ? null : adminNoAccessPath;
    case AdminSession.admin:
      return _isGatePath(path) ? (wanted ?? adminHomePath) : null;
  }
}
