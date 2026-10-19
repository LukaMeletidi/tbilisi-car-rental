import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_input.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';

/// What the car form holds while the admin types. Numbers are kept as the
/// typed text, so that "4." or an empty field can be shown and checked; they
/// become numbers only in [carFromDraft], after the validation passed.
class CarDraft implements CarFormValues {
  const CarDraft({
    this.brand = '',
    this.model = '',
    this.year = '',
    this.drivetrain,
    this.transmission,
    this.fuelType,
    this.seats = '',
    this.engineSize = '',
    this.pricePerDay = '',
    this.descriptionKa = '',
    this.descriptionRu = '',
    this.descriptionEn = '',
    this.photos = const [],
    this.active = false,
    this.popular = false,
  });

  /// The draft of a stored car, for the edit form.
  ///
  /// An old car entered by hand may lack the description or the photos:
  /// Car.fromMap reads them as empty, so here they become empty fields that
  /// the form must fill before a save is allowed (photos may stay empty).
  factory CarDraft.fromCar(Car car) {
    return CarDraft(
      brand: car.brand,
      model: car.model,
      year: '${car.year}',
      drivetrain: car.drivetrain,
      transmission: car.transmission,
      fuelType: car.fuelType,
      seats: '${car.seats}',
      engineSize: car.engineSize == null
          ? ''
          : formatDecimalInput(car.engineSize!),
      pricePerDay: formatDecimalInput(car.pricePerDay),
      descriptionKa: car.description.ka,
      descriptionRu: car.description.ru,
      descriptionEn: car.description.en,
      photos: List.unmodifiable(car.photos),
      active: car.active,
      popular: car.popular,
    );
  }

  @override
  final String brand;
  @override
  final String model;
  @override
  final String year;
  @override
  final Drivetrain? drivetrain;
  @override
  final Transmission? transmission;
  @override
  final FuelType? fuelType;
  @override
  final String seats;

  /// Empty means "no engine size".
  @override
  final String engineSize;
  @override
  final String pricePerDay;
  @override
  final String descriptionKa;
  @override
  final String descriptionRu;
  @override
  final String descriptionEn;

  /// The photo addresses in their order. May be empty.
  @override
  final List<String> photos;

  /// A new car starts hidden (false); the form has a switch.
  final bool active;

  /// Marked "Popular" (Home shows at most 3 visible marked cars). A new car
  /// starts unmarked.
  final bool popular;

  CarDraft copyWith({
    String? brand,
    String? model,
    String? year,
    Drivetrain? drivetrain,
    Transmission? transmission,
    FuelType? fuelType,
    String? seats,
    String? engineSize,
    String? pricePerDay,
    String? descriptionKa,
    String? descriptionRu,
    String? descriptionEn,
    List<String>? photos,
    bool? active,
    bool? popular,
  }) {
    return CarDraft(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      drivetrain: drivetrain ?? this.drivetrain,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      seats: seats ?? this.seats,
      engineSize: engineSize ?? this.engineSize,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      descriptionKa: descriptionKa ?? this.descriptionKa,
      descriptionRu: descriptionRu ?? this.descriptionRu,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      photos: photos == null ? this.photos : List.unmodifiable(photos),
      active: active ?? this.active,
      popular: popular ?? this.popular,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CarDraft &&
      other.brand == brand &&
      other.model == model &&
      other.year == year &&
      other.drivetrain == drivetrain &&
      other.transmission == transmission &&
      other.fuelType == fuelType &&
      other.seats == seats &&
      other.engineSize == engineSize &&
      other.pricePerDay == pricePerDay &&
      other.descriptionKa == descriptionKa &&
      other.descriptionRu == descriptionRu &&
      other.descriptionEn == descriptionEn &&
      _sameList(other.photos, photos) &&
      other.active == active &&
      other.popular == popular;

  @override
  int get hashCode => Object.hash(
    brand,
    model,
    year,
    drivetrain,
    transmission,
    fuelType,
    seats,
    engineSize,
    pricePerDay,
    descriptionKa,
    descriptionRu,
    descriptionEn,
    Object.hashAll(photos),
    active,
    popular,
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The car that a VALID draft describes, for the document [id]. Texts are
/// trimmed; year and seats become whole numbers (int), so that they are
/// stored as integers on every platform; an empty engine size is left out.
///
/// Throws an ArgumentError when [draft] does not pass validateCarDraft:
/// the screen must never get this far with errors. The error names no value
/// of the draft.
Car carFromDraft(String id, CarDraft draft, {required DateTime now}) {
  if (validateCarDraft(draft, now: now).hasErrors) {
    throw ArgumentError('The car draft is not valid.');
  }
  return Car(
    id: id,
    brand: draft.brand.trim(),
    model: draft.model.trim(),
    year: parseWholeInput(draft.year)!,
    drivetrain: draft.drivetrain!,
    transmission: draft.transmission!,
    fuelType: draft.fuelType!,
    seats: parseWholeInput(draft.seats)!,
    engineSize: parseDecimalInput(draft.engineSize),
    pricePerDay: parseDecimalInput(draft.pricePerDay)!,
    description: LocalizedText(
      ka: draft.descriptionKa.trim(),
      ru: draft.descriptionRu.trim(),
      en: draft.descriptionEn.trim(),
    ),
    photos: List.unmodifiable([for (final photo in draft.photos) photo.trim()]),
    active: draft.active,
    popular: draft.popular,
  );
}

/// The Firestore fields of [car]: exactly the keys the rules allow. year and
/// seats are Dart ints, so they are sent as integers on Android and on web;
/// pricePerDay and engineSize are doubles, which the rules accept whole or
/// not. No engineSize key when the car has none, and no popular key when the
/// car is not marked (the rules: absent means not popular).
Map<String, dynamic> carDocument(Car car) => car.toMap();
