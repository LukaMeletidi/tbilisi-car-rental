/// The stage of a booking. A customer request and a confirmed booking are the
/// same document at different stages.
enum BookingStatus {
  /// Submitted by a customer; nobody has handled it yet. Stored as "new".
  newBooking('new'),

  /// An admin contacted the customer; the order is still in progress.
  pending('pending'),

  /// A real booking. Only these appear on the calendar and count for
  /// conflicts.
  confirmed('confirmed'),

  cancelled('cancelled');

  const BookingStatus(this.storedName);

  /// The text stored in Firestore.
  final String storedName;

  /// The status for a stored text. Case-sensitive. Throws a
  /// [FormatException] for any other text.
  static BookingStatus parse(String storedName) {
    for (final status in values) {
      if (status.storedName == storedName) return status;
    }
    final allowed = values.map((status) => status.storedName).join(', ');
    throw FormatException(
      'Unknown booking status "$storedName" (allowed: $allowed).',
    );
  }
}
