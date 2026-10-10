import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';

/// How many bookings the admin list loads at first, and how many more each
/// "Load more" adds.
const adminBookingsPageSize = 50;

/// A Firestore document reduced to plain Dart: its ID and its fields, with
/// the dates already turned into UTC [DateTime] values.
typedef RawBookingDocument = ({String id, Map<String, dynamic> data});

/// One answer of the bookings query, before it is read as bookings.
class RawBookingsResult {
  const RawBookingsResult({required this.documents, required this.fromCache});

  /// Newest first, as the query returned them.
  final List<RawBookingDocument> documents;

  /// True when this answer came from the copy saved on the device and not
  /// from the server.
  final bool fromCache;
}

/// A booking document that could not be read: its ID and the reason. The
/// reason names the field that is wrong; it never holds the document.
class UnreadableBooking {
  const UnreadableBooking({required this.id, required this.reason});

  final String id;
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is UnreadableBooking && other.id == id && other.reason == reason;

  @override
  int get hashCode => Object.hash(id, reason);
}

/// The result of [parseBookings].
class ParsedBookings {
  const ParsedBookings({required this.bookings, required this.unreadable});

  /// The readable bookings, in the order of the documents.
  final List<Booking> bookings;

  /// The documents that were skipped, in the order of the documents.
  final List<UnreadableBooking> unreadable;
}

/// Turns raw documents into bookings, keeping their order.
///
/// A document that cannot be read as a booking is left out and listed in
/// [ParsedBookings.unreadable], so the screen can say how many were
/// skipped. It never stops the other bookings from loading. [onSkipped] is
/// called for each one, for logging.
ParsedBookings parseBookings(
  List<RawBookingDocument> documents, {
  void Function(String id, Object error, StackTrace stackTrace)? onSkipped,
}) {
  final bookings = <Booking>[];
  final unreadable = <UnreadableBooking>[];
  for (final document in documents) {
    try {
      bookings.add(Booking.fromMap(document.id, document.data));
    } catch (error, stackTrace) {
      unreadable.add(
        UnreadableBooking(id: document.id, reason: _reasonOf(error)),
      );
      onSkipped?.call(document.id, error, stackTrace);
    }
  }
  return ParsedBookings(
    bookings: List.unmodifiable(bookings),
    unreadable: List.unmodifiable(unreadable),
  );
}

String _reasonOf(Object error) =>
    error is FormatException ? error.message : '${error.runtimeType}';

/// What is known about the car of a booking.
enum AdminCarState {
  /// The car is in the catalog.
  active,

  /// The car exists but is hidden from the public.
  hidden,

  /// No car has this ID any more.
  notFound,

  /// The cars are not loaded (yet), so nothing can be said.
  notLoaded,
}

/// The car of a booking, for a row of the admin list.
class AdminCarLabel {
  const AdminCarLabel(this.state, [this.title]);

  final AdminCarState state;

  /// "Toyota Prius, 2019". Set for [AdminCarState.active] and
  /// [AdminCarState.hidden], otherwise null.
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is AdminCarLabel && other.state == state && other.title == title;

  @override
  int get hashCode => Object.hash(state, title);
}

/// Looks the car of a booking up by [carId] in [carsById], which holds every
/// car, also the hidden ones. [carsById] is null while the cars are not
/// loaded.
AdminCarLabel adminCarLabel(String carId, Map<String, Car>? carsById) {
  if (carsById == null) return const AdminCarLabel(AdminCarState.notLoaded);
  final car = carsById[carId];
  if (car == null) return const AdminCarLabel(AdminCarState.notFound);
  return AdminCarLabel(
    car.active ? AdminCarState.active : AdminCarState.hidden,
    carTitle(car),
  );
}

/// Why the bookings could not be loaded.
enum AdminBookingsFailure {
  /// The Firestore rules refused: this account is not (or no longer) an
  /// admin.
  permissionDenied,

  /// Anything else, for example no connection and nothing saved.
  other,
}

/// The failure for an error [code] of Firestore, such as
/// "permission-denied".
AdminBookingsFailure adminBookingsFailureFromCode(String code) {
  return code == 'permission-denied'
      ? AdminBookingsFailure.permissionDenied
      : AdminBookingsFailure.other;
}

/// Reported when the bookings or the cars could not be loaded. It carries
/// only the reason, never a Firestore error type.
class AdminBookingsException implements Exception {
  const AdminBookingsException(this.failure);

  final AdminBookingsFailure failure;

  @override
  String toString() => 'AdminBookingsException(${failure.name})';
}

/// How long the list must have been showing saved data, without a break,
/// before the screen says "offline".
const offlineNoteDelay = Duration(seconds: 3);

/// Since when the answers have come from the saved copy without a break.
///
/// [previous] is the value so far, [fromCache] says where the newest answer
/// came from, and [now] is the current moment. An answer from the server
/// ends the streak (null); the first answer from the saved copy starts it.
DateTime? fromCacheSinceAfter({
  required DateTime? previous,
  required bool fromCache,
  required DateTime now,
}) {
  if (!fromCache) return null;
  return previous ?? now;
}

/// Whether the screen shows "Offline: showing saved data".
///
/// Not for the first answer from the saved copy: when the list opens,
/// Firestore often shows the saved copy for a moment before the server
/// answers. Only when the answers have come from the saved copy for
/// [offlineNoteDelay] without a break.
bool shouldShowOfflineNote({
  required DateTime? fromCacheSince,
  required DateTime now,
}) {
  if (fromCacheSince == null) return false;
  return !now.isBefore(fromCacheSince.add(offlineNoteDelay));
}
