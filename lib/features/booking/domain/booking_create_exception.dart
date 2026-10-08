/// Why a booking could not be created.
enum BookingCreateFailure {
  /// The server refused the request: for example the car was just hidden, or
  /// the clock of the device is wrong.
  rejected,

  /// The server did not confirm in time, or there is no connection. In rare
  /// cases the request may still have arrived.
  noConnection,

  /// Anything else.
  unknown,
}

/// Reported when a booking could not be created. Screens show a text for
/// [failure]; they never see a Firestore error type.
class BookingCreateException implements Exception {
  const BookingCreateException(this.failure);

  final BookingCreateFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BookingCreateException && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'BookingCreateException(${failure.name})';
}
