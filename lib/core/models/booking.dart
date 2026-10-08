import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';

/// The person who makes a booking.
class BookingCustomer {
  const BookingCustomer({
    required this.fullName,
    required this.phone,
    required this.whatsapp,
    required this.telegram,
    required this.email,
  });

  /// Reads the stored map. Throws a [FormatException] when a field is
  /// missing or has the wrong type.
  factory BookingCustomer.fromMap(Map<String, dynamic> map) {
    return BookingCustomer(
      fullName: _requireText('customer.fullName', map['fullName']),
      phone: _requireText('customer.phone', map['phone']),
      whatsapp: _requireBool('customer.whatsapp', map['whatsapp']),
      telegram: _requireBool('customer.telegram', map['telegram']),
      email: _requireText('customer.email', map['email']),
    );
  }

  /// Full name and surname, as in the passport.
  final String fullName;

  /// International format: "+" and digits only.
  final String phone;

  /// Whether the customer can be reached on WhatsApp under [phone].
  final bool whatsapp;

  /// Whether the customer can be reached on Telegram under [phone].
  final bool telegram;

  final String email;

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'phone': phone,
    'whatsapp': whatsapp,
    'telegram': telegram,
    'email': email,
  };

  @override
  bool operator ==(Object other) =>
      other is BookingCustomer &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.telegram == telegram &&
      other.email == email;

  @override
  int get hashCode => Object.hash(fullName, phone, whatsapp, telegram, email);
}

/// A customer request or a confirmed booking: one document of the
/// "bookings" collection. All times are UTC.
///
/// This class holds only what is stored. The number of charged days and the
/// "individual price" flag are not stored; they are worked out from the two
/// dates by the booking feature.
class Booking {
  const Booking({
    this.id,
    required this.customer,
    required this.carId,
    required this.pickup,
    required this.dropoff,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.extras,
    required this.notes,
    required this.totalPrice,
    required this.language,
    required this.status,
    this.createdAt,
    this.createdBy,
  });

  /// Reads a stored booking. The two dates (and createdAt, if present) must
  /// already be UTC [DateTime] values; the data layer converts them.
  ///
  /// Throws a [FormatException] when a required field is missing or has the
  /// wrong type, when a date is not UTC, when dropoff is not after pickup,
  /// or for an unknown status, extra or language.
  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    final pickup = _requireUtc('pickupDateTime', map['pickupDateTime']);
    final dropoff = _requireUtc('dropoffDateTime', map['dropoffDateTime']);
    if (!dropoff.isAfter(pickup)) {
      throw const FormatException(
        'Booking: "dropoffDateTime" must be after "pickupDateTime".',
      );
    }

    final createdAt = map['createdAt'];
    final createdBy = map['createdBy'];
    if (createdBy != null && createdBy is! String) {
      throw FormatException(
        'Booking field "createdBy" must be a text, '
        'got ${createdBy.runtimeType}.',
      );
    }

    return Booking(
      id: id,
      customer: BookingCustomer.fromMap(_requireMap('customer', map)),
      carId: _requireText('carId', map['carId']),
      pickup: pickup,
      dropoff: dropoff,
      pickupLocation: BookingLocation.fromMap(
        _requireMap('pickupLocation', map),
      ),
      dropoffLocation: BookingLocation.fromMap(
        _requireMap('dropoffLocation', map),
      ),
      extras: _requireExtras(map['extras']),
      notes: _requireString('notes', map['notes']),
      totalPrice: _requirePrice(map['totalPrice']),
      language: _requireLanguage(map['language']),
      status: BookingStatus.parse(_requireString('status', map['status'])),
      createdAt: createdAt == null ? null : _requireUtc('createdAt', createdAt),
      createdBy: createdBy as String?,
    );
  }

  /// Firestore document ID. Null until the booking is saved.
  final String? id;

  final BookingCustomer customer;
  final String carId;

  /// Pickup moment, UTC.
  final DateTime pickup;

  /// Dropoff moment, UTC.
  final DateTime dropoff;

  final BookingLocation pickupLocation;
  final BookingLocation dropoffLocation;

  /// The selected extras; each at most once.
  final Set<Extra> extras;

  /// Special requests. May be empty.
  final String notes;

  /// The total in USD, with at most two decimals. Stored once and never
  /// recomputed on display.
  final double totalPrice;

  /// The language the customer used, so staff know how to answer.
  final AppLanguage language;

  final BookingStatus status;

  /// When the booking was created, UTC. Set by the server; null until saved.
  final DateTime? createdAt;

  /// Staff name, only for bookings created by an admin.
  final String? createdBy;

  /// [totalPrice] in whole US cents.
  int get totalPriceCents => (totalPrice * 100).round();

  /// The fields a client sends. Without the ID and without createdAt: the
  /// data layer adds createdAt as "server time".
  Map<String, dynamic> toMap() {
    return {
      'customer': customer.toMap(),
      'carId': carId,
      'pickupDateTime': pickup,
      'dropoffDateTime': dropoff,
      'pickupLocation': pickupLocation.toMap(),
      'dropoffLocation': dropoffLocation.toMap(),
      'extras': [
        for (final extra in Extra.values)
          if (extras.contains(extra)) extra.name,
      ],
      'notes': notes,
      'totalPrice': totalPrice,
      'language': language.code,
      'status': status.storedName,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Booking &&
      other.id == id &&
      other.customer == customer &&
      other.carId == carId &&
      other.pickup == pickup &&
      other.dropoff == dropoff &&
      other.pickupLocation == pickupLocation &&
      other.dropoffLocation == dropoffLocation &&
      other.extras.length == extras.length &&
      other.extras.containsAll(extras) &&
      other.notes == notes &&
      other.totalPrice == totalPrice &&
      other.language == language &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.createdBy == createdBy;

  @override
  int get hashCode => Object.hash(
    id,
    customer,
    carId,
    pickup,
    dropoff,
    pickupLocation,
    dropoffLocation,
    Object.hashAllUnordered(extras),
    notes,
    totalPrice,
    language,
    status,
    createdAt,
    createdBy,
  );
}

String _requireString(String field, Object? value) {
  if (value is String) return value;
  throw FormatException(
    'Booking field "$field" is missing or not a text '
    '(got ${value.runtimeType}).',
  );
}

/// A text that is not empty and not only spaces.
String _requireText(String field, Object? value) {
  final text = _requireString(field, value);
  if (text.trim().isEmpty) {
    throw FormatException('Booking field "$field" must not be empty.');
  }
  return text;
}

bool _requireBool(String field, Object? value) {
  if (value is bool) return value;
  throw FormatException(
    'Booking field "$field" is missing or not true/false '
    '(got ${value.runtimeType}).',
  );
}

Map<String, dynamic> _requireMap(String field, Map<String, dynamic> map) {
  final value = map[field];
  if (value is! Map) {
    throw FormatException(
      'Booking field "$field" is missing or not a map '
      '(got ${value.runtimeType}).',
    );
  }
  return {for (final entry in value.entries) '${entry.key}': entry.value};
}

DateTime _requireUtc(String field, Object? value) {
  if (value is! DateTime) {
    throw FormatException(
      'Booking field "$field" is missing or not a date '
      '(got ${value.runtimeType}).',
    );
  }
  if (!value.isUtc) {
    throw FormatException('Booking field "$field" must be a UTC date.');
  }
  return value;
}

Set<Extra> _requireExtras(Object? value) {
  if (value is! List) {
    throw FormatException(
      'Booking field "extras" is missing or not a list '
      '(got ${value.runtimeType}).',
    );
  }
  final extras = <Extra>{};
  for (final item in value) {
    final extra = Extra.values.where((extra) => extra.name == item);
    if (extra.isEmpty) {
      throw FormatException('Booking field "extras": unknown extra "$item".');
    }
    extras.add(extra.first);
  }
  return Set.unmodifiable(extras);
}

/// A price in USD: a whole or decimal number, 0 or more, with at most two
/// decimals.
double _requirePrice(Object? value) {
  if (value is! num) {
    throw FormatException(
      'Booking field "totalPrice" is missing or not a number '
      '(got ${value.runtimeType}).',
    );
  }
  if (!value.isFinite || value < 0) {
    throw FormatException(
      'Booking field "totalPrice" must be 0 or more, got $value.',
    );
  }
  final cents = value * 100;
  final wholeCents = cents.round();
  if ((cents - wholeCents).abs() > 1e-6) {
    throw FormatException(
      'Booking field "totalPrice" has more than two decimals: $value.',
    );
  }
  return wholeCents / 100;
}

AppLanguage _requireLanguage(Object? value) {
  for (final language in AppLanguage.values) {
    if (language.code == value) return language;
  }
  throw FormatException('Booking field "language": unknown value "$value".');
}
