import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';

/// The text to show for the place of a booking, or null when there is none.
///
/// For "other" it is the address the customer typed. For a fixed place it is
/// the name from [locations] in [language] (English when that translation is
/// missing).
///
/// Null means the name cannot be looked up: [locations] is null (the
/// settings are not loaded), the place is no longer in the list, or the text
/// is empty. The caller then shows a neutral text; the stored id is never
/// shown to a customer.
String? bookingPlaceText(
  BookingLocation location, {
  required List<PickupLocation>? locations,
  required AppLanguage language,
}) {
  if (location.isOther) return _orNull(location.text ?? '');
  if (locations == null) return null;
  for (final known in locations) {
    if (known.id == location.id) {
      return _orNull(known.name.forLanguage(language));
    }
  }
  return null;
}

String? _orNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}
