/// The reserved id for a free-text place. No location in settings may use it.
const otherLocationId = 'other';

/// The shape of a location id: a letter first, then letters, digits, "_" or
/// "-"; at most 64 characters. The Firestore rules for bookings use the same
/// pattern; a test compares them.
const locationIdPattern = r'^[A-Za-z][A-Za-z0-9_-]{0,63}$';

/// Whether [id] has the shape of a location id (see [locationIdPattern]).
bool isValidLocationId(String id) => RegExp(locationIdPattern).hasMatch(id);

/// Where a car is picked up or dropped off: one of the fixed places from
/// settings, or "other" with a free text (anywhere in Georgia).
class BookingLocation {
  /// A fixed place; [id] is a location id from settings.
  const BookingLocation.fixed(this.id) : text = null;

  /// Any other place, described by the customer in [text].
  const BookingLocation.other(String this.text) : id = otherLocationId;

  /// Reads the stored map { id, text }. Throws a [FormatException] when the
  /// id is missing, when "other" has no text, or when a fixed place has one.
  factory BookingLocation.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
        'Booking location: "id" is missing or not a text.',
      );
    }
    final text = map['text'];
    if (id == otherLocationId) {
      if (text is! String || text.trim().isEmpty) {
        throw const FormatException(
          'Booking location: "other" needs a "text".',
        );
      }
      return BookingLocation.other(text);
    }
    if (text != null) {
      throw FormatException(
        'Booking location: the fixed place "$id" must not have a "text".',
      );
    }
    return BookingLocation.fixed(id);
  }

  /// A location id from settings, or [otherLocationId].
  final String id;

  /// The customer's description; only set for "other".
  final String? text;

  bool get isOther => id == otherLocationId;

  Map<String, dynamic> toMap() => {'id': id, if (text != null) 'text': text};

  @override
  bool operator ==(Object other) =>
      other is BookingLocation && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}
