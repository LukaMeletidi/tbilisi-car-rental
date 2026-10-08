import 'package:tbilisi_car_rental/core/models/localized_text.dart';

/// A fixed pickup or drop-off place, from the document settings/locations.
class PickupLocation {
  const PickupLocation({required this.id, required this.name});

  /// Stable ID stored in bookings, for example "tbilisiAirport".
  final String id;

  /// The name in ka, ru and en. The English name is always present.
  final LocalizedText name;

  @override
  bool operator ==(Object other) =>
      other is PickupLocation && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Reads the document settings/locations. [data] is null when the document
/// does not exist. Throws a [FormatException] when the list is missing or
/// empty, or when a location has no ID, a repeated ID or no English name.
List<PickupLocation> parsePickupLocations(Map<String, dynamic>? data) {
  if (data == null) {
    throw const FormatException('settings/locations does not exist.');
  }
  final raw = data['items'];
  if (raw is! List) {
    throw FormatException(
      'settings/locations: "items" must be a list, got ${raw.runtimeType}.',
    );
  }
  if (raw.isEmpty) {
    throw const FormatException('settings/locations: "items" is empty.');
  }

  final locations = <PickupLocation>[];
  final seenIds = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) {
      throw FormatException('settings/locations: item $i must be a map.');
    }
    final id = item['id'];
    if (id is! String || id.trim().isEmpty) {
      throw FormatException(
        'settings/locations: item $i has no "id" (a non-empty string).',
      );
    }
    if (!seenIds.add(id)) {
      throw FormatException(
        'settings/locations: the id "$id" is used more than once.',
      );
    }
    final rawName = item['name'];
    if (rawName is! Map) {
      throw FormatException(
        'settings/locations: "$id" has no "name" map with ka, ru and en.',
      );
    }
    final name = LocalizedText.fromMap({
      for (final entry in rawName.entries) '${entry.key}': entry.value,
    });
    if (name.en.trim().isEmpty) {
      throw FormatException(
        'settings/locations: "$id" has no English name.',
      );
    }
    locations.add(PickupLocation(id: id, name: name));
  }
  return List.unmodifiable(locations);
}
