/// Reported when a car cannot be shown to the public: it does not exist, it
/// is hidden (not active), or its document cannot be read as a car.
class CarNotAvailableException implements Exception {
  const CarNotAvailableException();

  @override
  String toString() => 'CarNotAvailableException';
}
