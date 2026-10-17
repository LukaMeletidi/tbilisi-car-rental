/// The limits of the settings documents an admin may write
/// (settings/extras and settings/company).
///
/// The Firestore rules for settings (firestore.rules) repeat these numbers
/// and lists. Change both files together; the test
/// test/rules/settings_rules_limits_test.dart fails when they differ.
///
/// The phone and the e-mail of the company use the booking limits
/// (booking_limits.dart); they are not repeated here.
library;

/// The price of one extra in USD per day: 0 ("Free") up to this. At most
/// two decimals, as for the car price.
const extraMaxPricePerDay = 100;

/// The company name: 1 to this many characters, with no space at either
/// end. Not translated.
const companyNameMaxLength = 100;

/// One language of a translated company text (address, working hours): 1
/// to this many characters, with no space at either end.
const companyTextMaxLength = 300;

/// A company link (the map, a social page): at most this many characters.
/// It starts with [companyLinkScheme], has no space in it and has a dot
/// after the scheme.
const companyLinkMaxLength = 500;
const companyLinkScheme = 'https://';

/// The fields of settings/extras. All are required.
const extrasSettingsFields = ['pricesPerDay'];

/// The fields of settings/company. Every one is optional; a field that is
/// not set is left out.
const companyFields = [
  'name',
  'phone',
  'email',
  'address',
  'workingHours',
  'mapUrl',
  'social',
];

/// The social pages the company may link to. Each is optional.
const companySocialFields = ['facebook', 'instagram', 'whatsapp', 'telegram'];

/// The languages every translated company text must have, when it is set.
const companyTextLanguages = ['ka', 'ru', 'en'];
