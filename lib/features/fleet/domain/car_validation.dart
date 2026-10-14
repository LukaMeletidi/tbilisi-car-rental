import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_input.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';

/// One problem of a field of the car form. The English text of each is in
/// admin_texts.dart (adminCarErrorText).
enum CarError {
  brandRequired,
  brandTooLong,
  modelRequired,
  modelTooLong,
  yearRequired,
  yearNotWhole,
  yearTooOld,
  yearTooNew,
  drivetrainRequired,
  transmissionRequired,
  fuelTypeRequired,
  seatsRequired,
  seatsNotWhole,
  seatsOutOfRange,
  engineSizeInvalid,
  engineSizeOutOfRange,
  priceRequired,
  priceInvalid,
  priceOutOfRange,
  descriptionKaRequired,
  descriptionKaTooLong,
  descriptionRuRequired,
  descriptionRuTooLong,
  descriptionEnRequired,
  descriptionEnTooLong,
  tooManyPhotos,
}

/// One problem of a single photo address.
enum CarPhotoError {
  /// It does not start with "https://" (the check is case-sensitive).
  notHttps,

  /// It contains a space or another whitespace character.
  hasSpace,

  /// It does not have the shape the rules accept: at least one character
  /// before and after a dot, after "https://".
  notWebAddress,

  tooLong,

  /// The same address is already earlier in the list.
  duplicate,
}

/// The result of [validateCarDraft].
class CarValidation {
  const CarValidation({this.errors = const {}, this.photoErrors = const {}});

  final Set<CarError> errors;

  /// By the position of the photo in the list.
  final Map<int, CarPhotoError> photoErrors;

  bool get hasErrors => errors.isNotEmpty || photoErrors.isNotEmpty;
}

/// The values of the form that validateCarDraft checks. The draft class
/// implements it; the validation does not import the draft, so that the
/// draft can import the validation.
abstract interface class CarFormValues {
  String get brand;
  String get model;
  String get year;
  Drivetrain? get drivetrain;
  Transmission? get transmission;
  FuelType? get fuelType;
  String get seats;
  String get engineSize;
  String get pricePerDay;
  String get descriptionKa;
  String get descriptionRu;
  String get descriptionEn;
  List<String> get photos;
}

/// The same pattern as isCarPhoto in firestore.rules.
final carPhotoPattern = RegExp(r'^https://\S+\.\S+$');

final _whole = RegExp(r'^[0-9]{1,6}$');

/// A whole number of digits only, after trimming; null otherwise. "2019.0"
/// is not one.
int? parseWholeInput(String text) {
  final value = text.trim();
  if (!_whole.hasMatch(value)) return null;
  return int.parse(value);
}

/// The problem of one photo address, after trimming, or null.
CarPhotoError? carPhotoProblem(String address) {
  final photo = address.trim();
  if (!photo.startsWith(carPhotoScheme)) return CarPhotoError.notHttps;
  if (RegExp(r'\s').hasMatch(photo)) return CarPhotoError.hasSpace;
  if (!carPhotoPattern.hasMatch(photo)) return CarPhotoError.notWebAddress;
  if (photo.runes.length > carPhotoMaxLength) return CarPhotoError.tooLong;
  return null;
}

/// Every problem of [values], judged after trimming, as the save will send
/// it. [now] gives the newest allowed year: the year of [now] in UTC plus
/// carYearsAhead, as the rules use the clock of the server in UTC.
///
/// The checks are those of firestore.rules; the comparing test keeps the
/// numbers equal. A text is counted in characters (runes), as the rules
/// count it.
CarValidation validateCarDraft(CarFormValues values, {required DateTime now}) {
  final errors = <CarError>{};
  final photoErrors = <int, CarPhotoError>{};

  void text(String value, int max, CarError required, CarError tooLong) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      errors.add(required);
    } else if (trimmed.runes.length > max) {
      errors.add(tooLong);
    }
  }

  text(
    values.brand,
    carNameMaxLength,
    CarError.brandRequired,
    CarError.brandTooLong,
  );
  text(
    values.model,
    carNameMaxLength,
    CarError.modelRequired,
    CarError.modelTooLong,
  );

  if (values.year.trim().isEmpty) {
    errors.add(CarError.yearRequired);
  } else {
    final year = parseWholeInput(values.year);
    final newest = now.toUtc().year + carYearsAhead;
    if (year == null) {
      errors.add(CarError.yearNotWhole);
    } else if (year < carMinYear) {
      errors.add(CarError.yearTooOld);
    } else if (year > newest) {
      errors.add(CarError.yearTooNew);
    }
  }

  if (values.drivetrain == null) errors.add(CarError.drivetrainRequired);
  if (values.transmission == null) errors.add(CarError.transmissionRequired);
  if (values.fuelType == null) errors.add(CarError.fuelTypeRequired);

  if (values.seats.trim().isEmpty) {
    errors.add(CarError.seatsRequired);
  } else {
    final seats = parseWholeInput(values.seats);
    if (seats == null) {
      errors.add(CarError.seatsNotWhole);
    } else if (seats < carMinSeats || seats > carMaxSeats) {
      errors.add(CarError.seatsOutOfRange);
    }
  }

  if (values.engineSize.trim().isNotEmpty) {
    final size = parseDecimalInput(values.engineSize);
    if (size == null) {
      errors.add(CarError.engineSizeInvalid);
    } else if (size <= 0 || size > carMaxEngineSize) {
      errors.add(CarError.engineSizeOutOfRange);
    }
  }

  if (values.pricePerDay.trim().isEmpty) {
    errors.add(CarError.priceRequired);
  } else {
    final price = parseDecimalInput(values.pricePerDay);
    if (price == null) {
      errors.add(CarError.priceInvalid);
    } else if (price <= 0 || price > carMaxPricePerDay) {
      errors.add(CarError.priceOutOfRange);
    }
  }

  text(
    values.descriptionKa,
    carDescriptionMaxLength,
    CarError.descriptionKaRequired,
    CarError.descriptionKaTooLong,
  );
  text(
    values.descriptionRu,
    carDescriptionMaxLength,
    CarError.descriptionRuRequired,
    CarError.descriptionRuTooLong,
  );
  text(
    values.descriptionEn,
    carDescriptionMaxLength,
    CarError.descriptionEnRequired,
    CarError.descriptionEnTooLong,
  );

  if (values.photos.length > carMaxPhotos) errors.add(CarError.tooManyPhotos);
  final seen = <String>{};
  for (var i = 0; i < values.photos.length; i++) {
    final photo = values.photos[i].trim();
    final problem =
        carPhotoProblem(photo) ??
        (seen.add(photo) ? null : CarPhotoError.duplicate);
    if (problem != null) photoErrors[i] = problem;
  }

  return CarValidation(
    errors: Set.unmodifiable(errors),
    photoErrors: Map.unmodifiable(photoErrors),
  );
}
