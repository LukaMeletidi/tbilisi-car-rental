/// The limits of a car document, as an admin may write it.
///
/// The Firestore rules for cars (firestore.rules) repeat these numbers.
/// Change both files together; the test
/// test/rules/car_rules_limits_test.dart fails when they differ.
library;

/// The brand and the model: 1 to this many characters each, with no space at
/// either end.
const carNameMaxLength = 40;

/// The oldest year of a car. The newest is "this year plus
/// [carYearsAhead]", by the clock of the server.
const carMinYear = 1990;
const carYearsAhead = 1;

/// Seats: 1 to this many.
const carMinSeats = 1;
const carMaxSeats = 9;

/// Price per day in USD: more than 0, up to this. Decimals are allowed.
const carMaxPricePerDay = 2000;

/// Engine size in litres: optional; when set, more than 0 and up to this.
const carMaxEngineSize = 8;

/// The description in each of the three languages: 1 to this many
/// characters, with no space at either end.
const carDescriptionMaxLength = 1000;

/// Photos: none to this many addresses, none of them twice.
const carMaxPhotos = 10;

/// One photo address: at most this many characters. It starts with
/// [carPhotoScheme], has no space in it and has a dot after the scheme.
const carPhotoMaxLength = 500;
const carPhotoScheme = 'https://';

/// The fields of a car document. A document with any other field is refused.
/// [carOptionalFields] may be left out; every other one is required.
const carFields = [
  'brand',
  'model',
  'year',
  'drivetrain',
  'transmission',
  'fuelType',
  'seats',
  'engineSize',
  'pricePerDay',
  'description',
  'photos',
  'active',
  'popular',
];
const carOptionalFields = ['engineSize', 'popular'];

/// Home shows at most this many popular cars (the visible ones that are
/// marked). The rules cannot count them; this limit is in the app only.
const homePopularMax = 3;

/// The languages every description must have.
const carDescriptionLanguages = ['ka', 'ru', 'en'];
