import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ka.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ka'),
    Locale('ru'),
  ];

  /// App name, shown in the browser tab and the app bar.
  ///
  /// In en, this message translates to:
  /// **'Tbilisi Car Rental'**
  String get appTitle;

  /// Tooltip of the language menu in the app bar.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// Shown when there are no active cars at all.
  ///
  /// In en, this message translates to:
  /// **'No cars available yet'**
  String get catalogEmpty;

  /// Shown when the list of cars cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load the cars. Please try again later.'**
  String get catalogError;

  /// Button under an error message.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Screen-reader text for the placeholder shown instead of a car photo.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get noPhoto;

  /// Price per day in US dollars.
  ///
  /// In en, this message translates to:
  /// **'\${price} / day'**
  String pricePerDay(String price);

  /// Number of seats in a car.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{count} seats}}'**
  String seatsCount(int count);

  /// No description provided for @transmissionAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get transmissionAutomatic;

  /// No description provided for @transmissionManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get transmissionManual;

  /// No description provided for @fuelPetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuelPetrol;

  /// No description provided for @fuelDiesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get fuelDiesel;

  /// No description provided for @fuelHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get fuelHybrid;

  /// No description provided for @fuelElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelElectric;

  /// Button above the list and title of the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// Filters button when some filters are set.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersWithCount(int count);

  /// No description provided for @filterSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get filterSeats;

  /// No description provided for @filterFuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel type'**
  String get filterFuelType;

  /// No description provided for @filterTransmission.
  ///
  /// In en, this message translates to:
  /// **'Transmission'**
  String get filterTransmission;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @catalogNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No cars match your filters'**
  String get catalogNoMatch;

  /// Button that closes the filter sheet; count = matching cars.
  ///
  /// In en, this message translates to:
  /// **'Show cars ({count})'**
  String showCars(int count);

  /// Hint in the catalog search field.
  ///
  /// In en, this message translates to:
  /// **'Brand or model'**
  String get searchHint;

  /// Tooltip of the x in the search field; also a button label.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @catalogNoSearchMatch.
  ///
  /// In en, this message translates to:
  /// **'No cars match your search'**
  String get catalogNoSearchMatch;

  /// No description provided for @makeBooking.
  ///
  /// In en, this message translates to:
  /// **'Make a booking'**
  String get makeBooking;

  /// TEMPORARY, removed in step 2.7: under the disabled button.
  ///
  /// In en, this message translates to:
  /// **'Online booking is coming soon'**
  String get bookingComingSoon;

  /// No description provided for @carNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This car is not available'**
  String get carNotAvailable;

  /// No description provided for @backToCars.
  ///
  /// In en, this message translates to:
  /// **'Back to the cars'**
  String get backToCars;

  /// No description provided for @carError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the car. Please try again later.'**
  String get carError;

  /// No description provided for @descriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionTitle;

  /// Screen-reader text for the dots of the photo gallery.
  ///
  /// In en, this message translates to:
  /// **'Photo {current} of {total}'**
  String photoPosition(int current, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ka', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ka':
      return AppLocalizationsKa();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
