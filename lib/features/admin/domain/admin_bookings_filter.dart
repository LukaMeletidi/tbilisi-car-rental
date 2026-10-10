/// Filtering and sorting of the admin bookings list.
///
/// Everything here works on the bookings that are already loaded; nothing
/// asks Firestore. So a filter, a count or a sort covers only the loaded
/// bookings, and the screen says so while older ones can still be loaded.
///
/// Pure Dart: the current time is always passed in, and nothing is logged.
/// The search text can hold a customer's name or phone number.
library;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';

/// How the list is ordered.
enum AdminBookingsSort {
  /// By the time the request was received, newest first. The default.
  newestFirst,

  /// By the time the request was received, oldest first.
  oldestFirst,

  /// By the pickup date: the soonest coming pickup first. Bookings whose
  /// pickup is already past come after all coming ones, the most recent
  /// past pickup first.
  pickupDate,
}

/// What the admin chose: a status (or all), a search text and an order.
class AdminBookingsFilter {
  const AdminBookingsFilter({
    this.status,
    this.search = '',
    this.sort = AdminBookingsSort.newestFirst,
  });

  /// Only bookings with this status; null means all.
  final BookingStatus? status;

  /// What was typed into the search field, exactly as typed.
  final String search;

  final AdminBookingsSort sort;

  /// True when a status is chosen or something is being searched for. The
  /// order is not a filter.
  bool get isFiltering => status != null || searchWords(search).isNotEmpty;

  AdminBookingsFilter withStatus(BookingStatus? status) =>
      AdminBookingsFilter(status: status, search: search, sort: sort);

  AdminBookingsFilter withSearch(String search) =>
      AdminBookingsFilter(status: status, search: search, sort: sort);

  AdminBookingsFilter withSort(AdminBookingsSort sort) =>
      AdminBookingsFilter(status: status, search: search, sort: sort);

  /// All statuses and no search; the order is kept.
  AdminBookingsFilter cleared() => AdminBookingsFilter(sort: sort);

  @override
  bool operator ==(Object other) =>
      other is AdminBookingsFilter &&
      other.status == status &&
      other.search == search &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(status, search, sort);

  /// For logs and test messages. The search text itself is left out on
  /// purpose: it can be a customer's name or phone number.
  @override
  String toString() =>
      'AdminBookingsFilter(status: ${status?.name ?? 'all'}, '
      'search: ${search.isEmpty ? 'empty' : '${search.length} characters'}, '
      'sort: ${sort.name})';
}

final _whitespace = RegExp(r'\s+');
final _notADigit = RegExp('[^0-9]');
final _digit = RegExp('[0-9]');

// Digits and the signs people type inside a phone number.
final _onlyPhoneCharacters = RegExp(r'^[0-9+\s\-().]+$');

/// The words of a search text: lower case, split at spaces, no empty ones.
/// "  Nino   BER " gives ["nino", "ber"].
List<String> searchWords(String search) => [
  for (final word in search.trim().toLowerCase().split(_whitespace))
    if (word.isNotEmpty) word,
];

/// Only the digits of [text]: "+995 555 12-34-56" gives "995555123456".
String digitsOf(String text) => text.replaceAll(_notADigit, '');

/// Whether [search] is written like a phone number or a part of one: only
/// digits, "+", spaces, hyphens, dots and brackets, with at least one digit.
bool isPhoneSearch(String search) =>
    _onlyPhoneCharacters.hasMatch(search) && _digit.hasMatch(search);

/// Whether [booking] matches the search text.
///
/// - An empty text (or only spaces) matches every booking.
/// - A text written like a phone number is compared as digits: its digits
///   must appear, in one piece, in the digits of the customer's phone.
///   Spaces and signs are ignored on both sides, so "555 12" and "55512"
///   both find "+995555123456".
/// - Otherwise every word must be found: in the customer's name, ignoring
///   upper and lower case, or, for a word with digits, as digits in the
///   phone. So "nino 3456" finds Nino with a phone ending in 3456.
///
/// Only the name and the phone are searched; not the e-mail, the notes or
/// the car.
bool matchesSearch(Booking booking, String search) {
  final words = searchWords(search);
  if (words.isEmpty) return true;

  final phone = digitsOf(booking.customer.phone);
  if (isPhoneSearch(search)) return phone.contains(digitsOf(search));

  final name = booking.customer.fullName.toLowerCase();
  return words.every((word) {
    if (name.contains(word)) return true;
    final digits = digitsOf(word);
    return digits.isNotEmpty && phone.contains(digits);
  });
}

/// How many of [bookings] have each status, counting only those that match
/// [search]. Every status is in the result, with 0 when there are none.
///
/// The chosen status is deliberately not applied: each chip shows how many
/// bookings a tap on it would show.
Map<BookingStatus, int> countByStatus(
  List<Booking> bookings, {
  String search = '',
}) {
  final counts = {for (final status in BookingStatus.values) status: 0};
  for (final booking in bookings) {
    if (!matchesSearch(booking, search)) continue;
    counts[booking.status] = counts[booking.status]! + 1;
  }
  return counts;
}

/// The bookings to show: those of [bookings] that match the status and the
/// search of [filter], in its order.
///
/// [now] is the current moment in UTC; the pickup order needs it to tell
/// coming pickups from past ones. The order is stable: bookings that are
/// equal for the chosen order keep the order they were loaded in. The given
/// list is not changed.
List<Booking> visibleBookings(
  List<Booking> bookings, {
  required AdminBookingsFilter filter,
  required DateTime now,
}) {
  final matching = [
    for (final booking in bookings)
      if ((filter.status == null || booking.status == filter.status) &&
          matchesSearch(booking, filter.search))
        booking,
  ];
  return sortBookings(matching, sort: filter.sort, now: now);
}

/// [bookings] in the order [sort]; see [AdminBookingsSort]. Stable, and the
/// given list is not changed.
///
/// A booking without a received time (it is just being saved) counts as the
/// newest.
List<Booking> sortBookings(
  List<Booking> bookings, {
  required AdminBookingsSort sort,
  required DateTime now,
}) {
  final int Function(Booking a, Booking b) compare;
  switch (sort) {
    case AdminBookingsSort.newestFirst:
      compare = (a, b) => _compareReceived(b, a);
    case AdminBookingsSort.oldestFirst:
      compare = _compareReceived;
    case AdminBookingsSort.pickupDate:
      compare = (a, b) => _comparePickup(a, b, now);
  }

  // List.sort does not promise to keep equal items in order, so the place
  // in the loaded list is the tie-breaker.
  final indexed = [
    for (var i = 0; i < bookings.length; i++) (index: i, booking: bookings[i]),
  ];
  indexed.sort((a, b) {
    final result = compare(a.booking, b.booking);
    return result != 0 ? result : a.index.compareTo(b.index);
  });
  return [for (final item in indexed) item.booking];
}

// Older first. No received time counts as later than every real time.
int _compareReceived(Booking a, Booking b) {
  final first = a.createdAt;
  final second = b.createdAt;
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  return first.compareTo(second);
}

// Coming pickups first, the soonest on top; then past pickups, the most
// recent on top. A pickup exactly at [now] still counts as coming.
int _comparePickup(Booking a, Booking b, DateTime now) {
  final firstIsPast = a.pickup.isBefore(now);
  final secondIsPast = b.pickup.isBefore(now);
  if (firstIsPast != secondIsPast) return firstIsPast ? 1 : -1;
  return firstIsPast
      ? b.pickup.compareTo(a.pickup)
      : a.pickup.compareTo(b.pickup);
}
