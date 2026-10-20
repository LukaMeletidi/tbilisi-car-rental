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

  /// An amount in US dollars, such as a total.
  ///
  /// In en, this message translates to:
  /// **'\${amount}'**
  String priceAmount(String amount);

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

  /// No description provided for @bookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking request'**
  String get bookingTitle;

  /// No description provided for @bookingSectionContact.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get bookingSectionContact;

  /// No description provided for @bookingFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name and surname'**
  String get bookingFullName;

  /// No description provided for @bookingFullNameHelper.
  ///
  /// In en, this message translates to:
  /// **'As in your passport'**
  String get bookingFullNameHelper;

  /// No description provided for @bookingPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get bookingPhone;

  /// No description provided for @bookingWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'I use WhatsApp on this number'**
  String get bookingWhatsapp;

  /// No description provided for @bookingTelegram.
  ///
  /// In en, this message translates to:
  /// **'I use Telegram on this number'**
  String get bookingTelegram;

  /// No description provided for @bookingEmail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get bookingEmail;

  /// No description provided for @bookingSectionDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get bookingSectionDates;

  /// No description provided for @bookingPickupDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup date and time'**
  String get bookingPickupDateTime;

  /// No description provided for @bookingDropoffDateTime.
  ///
  /// In en, this message translates to:
  /// **'Dropoff date and time'**
  String get bookingDropoffDateTime;

  /// Shown with every date and time field.
  ///
  /// In en, this message translates to:
  /// **'Tbilisi time (GMT+4)'**
  String get tbilisiTimeLabel;

  /// No description provided for @bookingSectionLocations.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get bookingSectionLocations;

  /// No description provided for @bookingPickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup place'**
  String get bookingPickupLocation;

  /// No description provided for @bookingDropoffLocation.
  ///
  /// In en, this message translates to:
  /// **'Dropoff place'**
  String get bookingDropoffLocation;

  /// No description provided for @bookingLocationOther.
  ///
  /// In en, this message translates to:
  /// **'Other place'**
  String get bookingLocationOther;

  /// No description provided for @bookingLocationOtherText.
  ///
  /// In en, this message translates to:
  /// **'Address or place in Georgia'**
  String get bookingLocationOtherText;

  /// No description provided for @bookingSectionExtras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get bookingSectionExtras;

  /// No description provided for @extraSnowChains.
  ///
  /// In en, this message translates to:
  /// **'Snow chains'**
  String get extraSnowChains;

  /// No description provided for @extraChildSeat.
  ///
  /// In en, this message translates to:
  /// **'Child seat'**
  String get extraChildSeat;

  /// Age range the seat is meant for.
  ///
  /// In en, this message translates to:
  /// **'1–4 years'**
  String get extraChildSeatAge;

  /// No description provided for @extraInfantSeat.
  ///
  /// In en, this message translates to:
  /// **'Infant seat'**
  String get extraInfantSeat;

  /// Age range the seat is meant for.
  ///
  /// In en, this message translates to:
  /// **'0–12 months'**
  String get extraInfantSeatAge;

  /// No description provided for @extraBoosterSeat.
  ///
  /// In en, this message translates to:
  /// **'Booster seat'**
  String get extraBoosterSeat;

  /// Age range the seat is meant for.
  ///
  /// In en, this message translates to:
  /// **'3–16 years'**
  String get extraBoosterSeatAge;

  /// Shown instead of a price for an extra that costs 0.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get extraFree;

  /// No description provided for @bookingSectionNotes.
  ///
  /// In en, this message translates to:
  /// **'Special requests'**
  String get bookingSectionNotes;

  /// No description provided for @bookingNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. For example: two child seats'**
  String get bookingNotesHint;

  /// No description provided for @bookingSectionPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get bookingSectionPrice;

  /// No description provided for @bookingChooseDates.
  ///
  /// In en, this message translates to:
  /// **'Choose the dates to see the price'**
  String get bookingChooseDates;

  /// No description provided for @bookingRentalDays.
  ///
  /// In en, this message translates to:
  /// **'Rental days'**
  String get bookingRentalDays;

  /// No description provided for @bookingTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bookingTotal;

  /// No description provided for @bookingEstimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get bookingEstimatedTotal;

  /// days = the longest rental with a normal price (7).
  ///
  /// In en, this message translates to:
  /// **'For rentals longer than {days} days, the price is individual — our team will contact you to confirm the final price.'**
  String bookingIndividualPriceNote(int days);

  /// No description provided for @bookingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get bookingSubmit;

  /// No description provided for @bookingSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get bookingSending;

  /// No description provided for @bookingCheckFields.
  ///
  /// In en, this message translates to:
  /// **'Please check the marked fields'**
  String get bookingCheckFields;

  /// No description provided for @bookingFormLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the booking form. Please try again later.'**
  String get bookingFormLoadError;

  /// No description provided for @bookingErrorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get bookingErrorNameRequired;

  /// No description provided for @bookingErrorNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'The name is too short'**
  String get bookingErrorNameTooShort;

  /// max = the limit of the field.
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String bookingErrorTooLong(int max);

  /// No description provided for @bookingErrorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get bookingErrorPhoneRequired;

  /// example = a phone number such as +995 555 12 34 56.
  ///
  /// In en, this message translates to:
  /// **'Use the international format, for example {example}'**
  String bookingErrorPhoneInvalid(String example);

  /// No description provided for @bookingErrorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your e-mail'**
  String get bookingErrorEmailRequired;

  /// No description provided for @bookingErrorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail address'**
  String get bookingErrorEmailInvalid;

  /// No description provided for @bookingErrorPickupRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the pickup date and time'**
  String get bookingErrorPickupRequired;

  /// No description provided for @bookingErrorPickupNotInFuture.
  ///
  /// In en, this message translates to:
  /// **'The pickup time must be in the future'**
  String get bookingErrorPickupNotInFuture;

  /// No description provided for @bookingErrorDropoffRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the dropoff date and time'**
  String get bookingErrorDropoffRequired;

  /// No description provided for @bookingErrorDropoffNotAfterPickup.
  ///
  /// In en, this message translates to:
  /// **'The dropoff must be later than the pickup'**
  String get bookingErrorDropoffNotAfterPickup;

  /// days = the longest rental the form accepts (365).
  ///
  /// In en, this message translates to:
  /// **'A rental can be at most {days} days'**
  String bookingErrorRentalTooLong(int days);

  /// No description provided for @bookingErrorLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a place'**
  String get bookingErrorLocationRequired;

  /// No description provided for @bookingErrorLocationUnknown.
  ///
  /// In en, this message translates to:
  /// **'This place is no longer available. Choose another one.'**
  String get bookingErrorLocationUnknown;

  /// No description provided for @bookingErrorLocationTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the address or place'**
  String get bookingErrorLocationTextRequired;

  /// No description provided for @bookingFailedRejected.
  ///
  /// In en, this message translates to:
  /// **'The request was not accepted. Check your details and the dates, or choose another car.'**
  String get bookingFailedRejected;

  /// No description provided for @bookingFailedNoConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not send the request. Check your internet connection and try again.'**
  String get bookingFailedNoConnection;

  /// No description provided for @bookingFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get bookingFailedUnknown;

  /// No description provided for @bookingSentThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your trust — our representative will contact you shortly to confirm the details.'**
  String get bookingSentThanks;

  /// Title of the summary on the thank-you screen.
  ///
  /// In en, this message translates to:
  /// **'Your request'**
  String get bookingSentSummaryTitle;

  /// No description provided for @bookingSentCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get bookingSentCar;

  /// No description provided for @bookingSentPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get bookingSentPickup;

  /// No description provided for @bookingSentDropoff.
  ///
  /// In en, this message translates to:
  /// **'Dropoff'**
  String get bookingSentDropoff;

  /// Shown in the summary when no extra was chosen.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get bookingSentNoExtras;

  /// Shown instead of a place name that cannot be looked up.
  ///
  /// In en, this message translates to:
  /// **'A place from our list'**
  String get bookingSentUnknownPlace;

  /// No description provided for @bookingSentWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get bookingSentWhatsapp;

  /// No description provided for @bookingSentTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get bookingSentTelegram;

  /// Bottom navigation: the Home tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Bottom navigation: the tab with the list of cars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get tabCars;

  /// Bottom navigation: the tab with the About us and contact page.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get tabContact;

  /// Bottom navigation: the tab with the frequently asked questions.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get tabFaq;

  /// Title of the About us and contact page.
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get aboutTitle;

  /// Title of the FAQ page.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get faqTitle;

  /// Shown on a page whose content is not ready yet.
  ///
  /// In en, this message translates to:
  /// **'This page is coming soon.'**
  String get pageComingSoon;

  /// Home: the large title on the hero photo.
  ///
  /// In en, this message translates to:
  /// **'Autopark'**
  String get homeHeroTitle;

  /// Home: the subtitle below the hero title.
  ///
  /// In en, this message translates to:
  /// **'Car catalog'**
  String get homeHeroSubtitle;

  /// Home: the title above the popular cars.
  ///
  /// In en, this message translates to:
  /// **'The most popular cars'**
  String get homeTopCarsTitle;

  /// Home: the title of the rental process steps.
  ///
  /// In en, this message translates to:
  /// **'The process of car rental and delivery'**
  String get homeProcessTitle;

  /// Home: the title of rental process step 1.
  ///
  /// In en, this message translates to:
  /// **'Choosing a car'**
  String get homeProcess1Title;

  /// Home: the text of rental process step 1.
  ///
  /// In en, this message translates to:
  /// **'Take a look at our catalog and select the appropriate model.'**
  String get homeProcess1Text;

  /// Home: the title of rental process step 2.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get homeProcess2Title;

  /// Home: the text of rental process step 2.
  ///
  /// In en, this message translates to:
  /// **'Fill out the form on the website or contact us by phone.'**
  String get homeProcess2Text;

  /// Home: the title of rental process step 3.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get homeProcess3Title;

  /// Home: the text of rental process step 3.
  ///
  /// In en, this message translates to:
  /// **'Our manager will contact you to clarify the details.'**
  String get homeProcess3Text;

  /// Home: the title of rental process step 4.
  ///
  /// In en, this message translates to:
  /// **'Getting a car'**
  String get homeProcess4Title;

  /// Home: the text of rental process step 4.
  ///
  /// In en, this message translates to:
  /// **'Meeting at a place convenient for you, signing the contract and handing over the keys.'**
  String get homeProcess4Text;

  /// Home: the title of the benefits cards.
  ///
  /// In en, this message translates to:
  /// **'We are interested in having you choose us again next time'**
  String get homeBenefitsTitle;

  /// Home: the title of benefits card 1.
  ///
  /// In en, this message translates to:
  /// **'24/7 service'**
  String get homeBenefit1Title;

  /// Home: the text of benefits card 1.
  ///
  /// In en, this message translates to:
  /// **'Our clients receive not only car rental, but also individual attention 24/7. A personal manager is always available to resolve issues during the entire rental period.'**
  String get homeBenefit1Text;

  /// Home: the title of benefits card 2.
  ///
  /// In en, this message translates to:
  /// **'Complete security'**
  String get homeBenefit2Title;

  /// Home: the text of benefits card 2.
  ///
  /// In en, this message translates to:
  /// **'All cars in our fleet are insured, providing you with peace of mind and confidence on any trip.'**
  String get homeBenefit2Text;

  /// Home: the title of benefits card 3.
  ///
  /// In en, this message translates to:
  /// **'High quality cars'**
  String get homeBenefit3Title;

  /// Home: the text of benefits card 3.
  ///
  /// In en, this message translates to:
  /// **'Our cars are always in excellent technical condition, equipped with winter tires in winter for your safety.'**
  String get homeBenefit3Text;

  /// Home: the title of the conditions cards.
  ///
  /// In en, this message translates to:
  /// **'The best conditions for a comfortable trip'**
  String get homeTermsTitle;

  /// Home: the title of conditions card 1.
  ///
  /// In en, this message translates to:
  /// **'Minimum deposit'**
  String get homeTerms1Title;

  /// Home: the text of conditions card 1.
  ///
  /// In en, this message translates to:
  /// **'When renting a car, you need to make a deposit, the amount of which depends on the type of transmission of the car.'**
  String get homeTerms1Text;

  /// Home: the title of conditions card 2.
  ///
  /// In en, this message translates to:
  /// **'Age from 21 years old'**
  String get homeTerms2Title;

  /// Home: the text of conditions card 2.
  ///
  /// In en, this message translates to:
  /// **'Driving experience minimum 2 years: insurance requirements are standard, without additional conditions.'**
  String get homeTerms2Text;

  /// Home: the title of conditions card 3.
  ///
  /// In en, this message translates to:
  /// **'Honest risk sharing'**
  String get homeTerms3Title;

  /// Home: the text of conditions card 3.
  ///
  /// In en, this message translates to:
  /// **'For maximum peace of mind for tenants, all vehicles are covered by mandatory third-party civil liability insurance, and many also have full insurance coverage.'**
  String get homeTerms3Text;

  /// Home: the title of the traffic rules cards.
  ///
  /// In en, this message translates to:
  /// **'Features of traffic in Georgia'**
  String get homeTrafficTitle;

  /// Home: the title of traffic rules card 1.
  ///
  /// In en, this message translates to:
  /// **'Up to 60 km/h'**
  String get homeTraffic1Title;

  /// Home: the text of traffic rules card 1.
  ///
  /// In en, this message translates to:
  /// **'In populated areas'**
  String get homeTraffic1Text;

  /// Home: the title of traffic rules card 2.
  ///
  /// In en, this message translates to:
  /// **'Up to 90 km/h'**
  String get homeTraffic2Title;

  /// Home: the text of traffic rules card 2.
  ///
  /// In en, this message translates to:
  /// **'Outside the settlements'**
  String get homeTraffic2Text;

  /// Home: the title of traffic rules card 3.
  ///
  /// In en, this message translates to:
  /// **'Up to 110 km/h'**
  String get homeTraffic3Title;

  /// Home: the text of traffic rules card 3.
  ///
  /// In en, this message translates to:
  /// **'On motorways'**
  String get homeTraffic3Text;

  /// FAQ page: the heading above the questions.
  ///
  /// In en, this message translates to:
  /// **'Answers to popular customer questions'**
  String get faqPageHeading;

  /// FAQ page: question 1.
  ///
  /// In en, this message translates to:
  /// **'What documents are required to rent a car?'**
  String get faq1Question;

  /// FAQ page: the answer to question 1, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'To rent a car, you will need a valid driver\'s license, passport and international driver\'s license (if your country is not included in the agreed list).'**
  String get faq1Answer;

  /// FAQ page: question 2.
  ///
  /// In en, this message translates to:
  /// **'Where is the best place to refuel in Georgia?'**
  String get faq2Question;

  /// FAQ page: the answer to question 2, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'On each five-kilometer stretch of road you will find small gas stations, and larger ones are located 10-15 km away. The vast majority of stations operate around the clock. Various types of fuel are available to you, including diesel, 92nd, 95th and 98th gasoline.'**
  String get faq2Answer;

  /// FAQ page: question 3.
  ///
  /// In en, this message translates to:
  /// **'How do I get a rental car?'**
  String get faq3Question;

  /// FAQ page: the answer to question 3, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'After successful booking, you can pick up the car at the specified location. Our representative will provide you with a car, check the necessary documents and tell you about the features of use.'**
  String get faq3Answer;

  /// FAQ page: question 4.
  ///
  /// In en, this message translates to:
  /// **'Have plans changed: the cancellation process and related payments?'**
  String get faq4Question;

  /// FAQ page: the answer to question 4, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'If your plans have changed, you can cancel your reservation by contacting our support service. Depending on the date and reason for cancellation, certain payments may apply.'**
  String get faq4Answer;

  /// FAQ page: question 5.
  ///
  /// In en, this message translates to:
  /// **'The impact of flight cancellation or postponement on car booking?'**
  String get faq5Question;

  /// FAQ page: the answer to question 5, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'If your flight is cancelled or rescheduled, please contact us as soon as possible. We will try to adapt your order according to the new schedule.'**
  String get faq5Answer;

  /// FAQ page: question 6.
  ///
  /// In en, this message translates to:
  /// **'What expenses can I incur when renting a car?'**
  String get faq6Question;

  /// FAQ page: the answer to question 6, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'Expenses may include fuel, payment of fines for traffic violations and additional services if they are not included in the main package.'**
  String get faq6Answer;

  /// FAQ page: question 7.
  ///
  /// In en, this message translates to:
  /// **'What happens if you break the lease?'**
  String get faq7Question;

  /// FAQ page: the answer to question 7, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'Violation of the lease agreement may result in unilateral termination of the agreement, fines under the agreement and legal consequences in accordance with the legislation of Georgia.'**
  String get faq7Answer;

  /// FAQ page: question 8.
  ///
  /// In en, this message translates to:
  /// **'The procedure for paying for a car rental: when and how is it performed?'**
  String get faq8Question;

  /// FAQ page: the answer to question 8, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'The rent is paid at the time of signing the contract. We accept payments by cards, online transfers, and cryptocurrency — in any currency.'**
  String get faq8Answer;

  /// FAQ page: question 9.
  ///
  /// In en, this message translates to:
  /// **'How should cars be returned after the rental?'**
  String get faq9Question;

  /// FAQ page: the answer to question 9, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'It is necessary to return the car in the same condition in which it was received, with the same fuel level. Our cars are available for rent in a clean condition.'**
  String get faq9Answer;

  /// FAQ page: question 10.
  ///
  /// In en, this message translates to:
  /// **'What is the amount of the prepayment?'**
  String get faq10Question;

  /// FAQ page: the answer to question 10, shown when it is opened.
  ///
  /// In en, this message translates to:
  /// **'The amount of the prepayment depends on the date of booking, the rental period and the selected car model. Details are discussed personally at the time of booking.'**
  String get faq10Answer;

  /// Contact tab: the "About us" paragraph.
  ///
  /// In en, this message translates to:
  /// **'Our company has been serving customers for years, offering high-quality, impeccably maintained, and clean vehicles. Our team of professionals is always ready to assist you 24/7. We provide not only high-quality cars but also excellent service and a friendly atmosphere. Our managers are always available to help you.'**
  String get aboutText;

  /// Contact tab: the heading above the company contact details.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get aboutContactsTitle;

  /// Contact tab: the label of the phone number.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get aboutPhoneLabel;

  /// Contact tab: the label of the e-mail address.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get aboutEmailLabel;

  /// Contact tab: the label of the address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get aboutAddressLabel;

  /// Contact tab: the label of the working hours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get aboutWorkingHoursLabel;

  /// Contact tab: opens the map link when no address is set.
  ///
  /// In en, this message translates to:
  /// **'Show on the map'**
  String get aboutShowOnMap;

  /// Contact tab: the tooltip of the copy button next to a contact.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get aboutCopy;

  /// Contact tab: shown after a contact was copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get aboutCopied;

  /// Contact tab: shown when a link could not be opened; it was copied.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. The text was copied.'**
  String get aboutOpenFailed;

  /// Contact tab: shown when the contact details cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load the contact details. Please try again later.'**
  String get aboutContactsError;

  /// Contact tab: the link to the Facebook page.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get aboutFacebook;

  /// Contact tab: the link to the Instagram page.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get aboutInstagram;

  /// Contact tab: the WhatsApp link.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get aboutWhatsapp;

  /// Contact tab: the Telegram link.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get aboutTelegram;
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
