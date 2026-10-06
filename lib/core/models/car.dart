import 'package:tbilisi_car_rental/core/localization/app_language.dart';

enum Drivetrain { fwd, rwd, awd }

enum Transmission { automatic, manual }

enum FuelType { petrol, diesel, hybrid, electric }

/// A text stored once per language, such as a car description { ka, ru, en }.
class LocalizedText {
  const LocalizedText({this.ka = '', this.ru = '', this.en = ''});

  /// Reads { ka, ru, en }. A missing language is an empty text.
  factory LocalizedText.fromMap(Map<String, dynamic> map) {
    return LocalizedText(
      ka: _optionalString(map, 'ka'),
      ru: _optionalString(map, 'ru'),
      en: _optionalString(map, 'en'),
    );
  }

  final String ka;
  final String ru;
  final String en;

  /// The text in [language]; if that is missing, the English text;
  /// if that is missing too, an empty string.
  String forLanguage(AppLanguage language) {
    final text = switch (language) {
      AppLanguage.ka => ka,
      AppLanguage.ru => ru,
      AppLanguage.en => en,
    };
    if (text.trim().isNotEmpty) return text;
    if (en.trim().isNotEmpty) return en;
    return '';
  }

  Map<String, dynamic> toMap() => {'ka': ka, 'ru': ru, 'en': en};

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other.ka == ka &&
      other.ru == ru &&
      other.en == en;

  @override
  int get hashCode => Object.hash(ka, ru, en);
}

class Car {
  const Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.drivetrain,
    required this.transmission,
    required this.fuelType,
    required this.seats,
    required this.engineSize,
    required this.pricePerDay,
    required this.description,
    required this.photos,
    required this.active,
  });

  /// Builds a car from a Firestore document. Throws a [FormatException] when a
  /// required field is missing, has the wrong type or an unknown value.
  factory Car.fromMap(String id, Map<String, dynamic> map) {
    final seats = _requireInt(map, 'seats');
    if (seats < 1) {
      throw FormatException('Car field "seats" must be 1 or more, got $seats.');
    }
    final pricePerDay = _require<num>(map, 'pricePerDay').toDouble();
    if (pricePerDay <= 0) {
      throw FormatException(
        'Car field "pricePerDay" must be more than 0, got $pricePerDay.',
      );
    }
    final engineSize = _optionalDouble(map, 'engineSize');
    if (engineSize != null && engineSize <= 0) {
      throw FormatException(
        'Car field "engineSize" must be more than 0, got $engineSize.',
      );
    }
    return Car(
      id: id,
      brand: _requireText(map, 'brand'),
      model: _requireText(map, 'model'),
      year: _requireInt(map, 'year'),
      drivetrain: _requireEnum(Drivetrain.values, map, 'drivetrain'),
      transmission: _requireEnum(Transmission.values, map, 'transmission'),
      fuelType: _requireEnum(FuelType.values, map, 'fuelType'),
      seats: seats,
      engineSize: engineSize,
      pricePerDay: pricePerDay,
      description: _description(map),
      photos: _photos(map),
      active: _require<bool>(map, 'active'),
    );
  }

  /// Firestore document ID. Not stored inside the document.
  final String id;
  final String brand;
  final String model;
  final int year;
  final Drivetrain drivetrain;
  final Transmission transmission;
  final FuelType fuelType;

  /// Exact number of seats.
  final int seats;

  /// Engine size in litres. Optional.
  final double? engineSize;

  /// Price per day in USD.
  final double pricePerDay;
  final LocalizedText description;

  /// Photo URLs. May be empty.
  final List<String> photos;

  /// false = hidden from the public catalog (soft delete).
  final bool active;

  /// The engine size to show: hidden for electric cars and when not set.
  double? get visibleEngineSize =>
      fuelType == FuelType.electric ? null : engineSize;

  /// The document fields, without the ID.
  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'drivetrain': drivetrain.name,
      'transmission': transmission.name,
      'fuelType': fuelType.name,
      'seats': seats,
      if (engineSize != null) 'engineSize': engineSize,
      'pricePerDay': pricePerDay,
      'description': description.toMap(),
      'photos': photos,
      'active': active,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Car &&
      other.id == id &&
      other.brand == brand &&
      other.model == model &&
      other.year == year &&
      other.drivetrain == drivetrain &&
      other.transmission == transmission &&
      other.fuelType == fuelType &&
      other.seats == seats &&
      other.engineSize == engineSize &&
      other.pricePerDay == pricePerDay &&
      other.description == description &&
      _listEquals(other.photos, photos) &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    model,
    year,
    drivetrain,
    transmission,
    fuelType,
    seats,
    engineSize,
    pricePerDay,
    description,
    Object.hashAll(photos),
    active,
  );
}

T _require<T extends Object>(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is T) return value;
  throw FormatException(
    'Car field "$field" is missing or has the wrong type '
    '(expected $T, got ${value.runtimeType}).',
  );
}

/// A string that is not empty and not only spaces.
String _requireText(Map<String, dynamic> map, String field) {
  final value = _require<String>(map, field);
  if (value.trim().isEmpty) {
    throw FormatException('Car field "$field" must not be empty.');
  }
  return value;
}

/// A whole number. Firestore may return it as 2019 or 2019.0.
int _requireInt(Map<String, dynamic> map, String field) {
  final value = _require<num>(map, field);
  if (value != value.roundToDouble()) {
    throw FormatException(
      'Car field "$field" must be a whole number, got $value.',
    );
  }
  return value.toInt();
}

T _requireEnum<T extends Enum>(
  List<T> values,
  Map<String, dynamic> map,
  String field,
) {
  final name = _require<String>(map, field);
  for (final value in values) {
    if (value.name == name) return value;
  }
  final allowed = values.map((value) => value.name).join(', ');
  throw FormatException(
    'Car field "$field" has the unknown value "$name" (allowed: $allowed).',
  );
}

double? _optionalDouble(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException(
    'Car field "$field" must be a number, got ${value.runtimeType}.',
  );
}

String _optionalString(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value == null) return '';
  if (value is String) return value;
  throw FormatException(
    'Text field "$field" must be a string, got ${value.runtimeType}.',
  );
}

LocalizedText _description(Map<String, dynamic> map) {
  final value = map['description'];
  if (value == null) return const LocalizedText();
  if (value is Map) {
    return LocalizedText.fromMap({
      for (final entry in value.entries) '${entry.key}': entry.value,
    });
  }
  throw FormatException(
    'Car field "description" must be a map, got ${value.runtimeType}.',
  );
}

List<String> _photos(Map<String, dynamic> map) {
  final value = map['photos'];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException(
      'Car field "photos" must be a list, got ${value.runtimeType}.',
    );
  }
  return List.unmodifiable([
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException(
          'Car field "photos" must contain only strings, '
          'got ${item.runtimeType}.',
        ),
  ]);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
