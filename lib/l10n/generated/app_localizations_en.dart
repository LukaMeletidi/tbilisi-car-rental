// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tbilisi Car Rental';

  @override
  String get languageLabel => 'Language';

  @override
  String get catalogEmpty => 'No cars available yet';

  @override
  String get catalogError => 'Could not load the cars. Please try again later.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noPhoto => 'No photo';

  @override
  String pricePerDay(String price) {
    return '\$$price / day';
  }

  @override
  String priceAmount(String amount) {
    return '\$$amount';
  }

  @override
  String seatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get transmissionAutomatic => 'Automatic';

  @override
  String get transmissionManual => 'Manual';

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelElectric => 'Electric';

  @override
  String get filters => 'Filters';

  @override
  String filtersWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get filterSeats => 'Seats';

  @override
  String get filterFuelType => 'Fuel type';

  @override
  String get filterTransmission => 'Transmission';

  @override
  String get filterAny => 'Any';

  @override
  String get filterReset => 'Reset';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get catalogNoMatch => 'No cars match your filters';

  @override
  String showCars(int count) {
    return 'Show cars ($count)';
  }

  @override
  String get searchHint => 'Brand or model';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get catalogNoSearchMatch => 'No cars match your search';

  @override
  String get makeBooking => 'Make a booking';

  @override
  String get carNotAvailable => 'This car is not available';

  @override
  String get backToCars => 'Back to the cars';

  @override
  String get carError => 'Could not load the car. Please try again later.';

  @override
  String get descriptionTitle => 'Description';

  @override
  String photoPosition(int current, int total) {
    return 'Photo $current of $total';
  }

  @override
  String get bookingTitle => 'Booking request';

  @override
  String get bookingSectionContact => 'Your details';

  @override
  String get bookingFullName => 'Full name and surname';

  @override
  String get bookingFullNameHelper => 'As in your passport';

  @override
  String get bookingPhone => 'Phone number';

  @override
  String get bookingWhatsapp => 'I use WhatsApp on this number';

  @override
  String get bookingTelegram => 'I use Telegram on this number';

  @override
  String get bookingEmail => 'E-mail';

  @override
  String get bookingSectionDates => 'Dates';

  @override
  String get bookingPickupDateTime => 'Pickup date and time';

  @override
  String get bookingDropoffDateTime => 'Dropoff date and time';

  @override
  String get tbilisiTimeLabel => 'Tbilisi time (GMT+4)';

  @override
  String get bookingSectionLocations => 'Places';

  @override
  String get bookingPickupLocation => 'Pickup place';

  @override
  String get bookingDropoffLocation => 'Dropoff place';

  @override
  String get bookingLocationOther => 'Other place';

  @override
  String get bookingLocationOtherText => 'Address or place in Georgia';

  @override
  String get bookingSectionExtras => 'Extras';

  @override
  String get extraSnowChains => 'Snow chains';

  @override
  String get extraChildSeat => 'Child seat';

  @override
  String get extraChildSeatAge => '1–4 years';

  @override
  String get extraInfantSeat => 'Infant seat';

  @override
  String get extraInfantSeatAge => '0–12 months';

  @override
  String get extraBoosterSeat => 'Booster seat';

  @override
  String get extraBoosterSeatAge => '3–16 years';

  @override
  String get extraFree => 'Free';

  @override
  String get bookingSectionNotes => 'Special requests';

  @override
  String get bookingNotesHint => 'Optional. For example: two child seats';

  @override
  String get bookingSectionPrice => 'Price';

  @override
  String get bookingChooseDates => 'Choose the dates to see the price';

  @override
  String get bookingRentalDays => 'Rental days';

  @override
  String get bookingTotal => 'Total';

  @override
  String get bookingEstimatedTotal => 'Estimated total';

  @override
  String bookingIndividualPriceNote(int days) {
    return 'For rentals longer than $days days, the price is individual — our team will contact you to confirm the final price.';
  }

  @override
  String get bookingSubmit => 'Send request';

  @override
  String get bookingSending => 'Sending…';

  @override
  String get bookingCheckFields => 'Please check the marked fields';

  @override
  String get bookingFormLoadError =>
      'Could not load the booking form. Please try again later.';

  @override
  String get bookingErrorNameRequired => 'Enter your full name';

  @override
  String get bookingErrorNameTooShort => 'The name is too short';

  @override
  String bookingErrorTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String get bookingErrorPhoneRequired => 'Enter your phone number';

  @override
  String bookingErrorPhoneInvalid(String example) {
    return 'Use the international format, for example $example';
  }

  @override
  String get bookingErrorEmailRequired => 'Enter your e-mail';

  @override
  String get bookingErrorEmailInvalid => 'Enter a valid e-mail address';

  @override
  String get bookingErrorPickupRequired => 'Choose the pickup date and time';

  @override
  String get bookingErrorPickupNotInFuture =>
      'The pickup time must be in the future';

  @override
  String get bookingErrorDropoffRequired => 'Choose the dropoff date and time';

  @override
  String get bookingErrorDropoffNotAfterPickup =>
      'The dropoff must be later than the pickup';

  @override
  String bookingErrorRentalTooLong(int days) {
    return 'A rental can be at most $days days';
  }

  @override
  String get bookingErrorLocationRequired => 'Choose a place';

  @override
  String get bookingErrorLocationUnknown =>
      'This place is no longer available. Choose another one.';

  @override
  String get bookingErrorLocationTextRequired => 'Enter the address or place';

  @override
  String get bookingFailedRejected =>
      'The request was not accepted. Check your details and the dates, or choose another car.';

  @override
  String get bookingFailedNoConnection =>
      'Could not send the request. Check your internet connection and try again.';

  @override
  String get bookingFailedUnknown => 'Something went wrong. Please try again.';

  @override
  String get bookingSentThanks =>
      'Thank you for your trust — our representative will contact you shortly to confirm the details.';

  @override
  String get bookingSentSummaryTitle => 'Your request';

  @override
  String get bookingSentCar => 'Car';

  @override
  String get bookingSentPickup => 'Pickup';

  @override
  String get bookingSentDropoff => 'Dropoff';

  @override
  String get bookingSentNoExtras => 'None';

  @override
  String get bookingSentUnknownPlace => 'A place from our list';

  @override
  String get bookingSentWhatsapp => 'WhatsApp';

  @override
  String get bookingSentTelegram => 'Telegram';

  @override
  String get tabHome => 'Home';

  @override
  String get tabCars => 'Cars';

  @override
  String get tabContact => 'Contact';

  @override
  String get tabFaq => 'FAQ';

  @override
  String get aboutTitle => 'About us';

  @override
  String get homeHeroTitle => 'Autopark';

  @override
  String get homeHeroSubtitle => 'Car catalog';

  @override
  String get homeTopCarsTitle => 'The most popular cars';

  @override
  String get homeProcessTitle => 'The process of car rental and delivery';

  @override
  String get homeProcess1Title => 'Choosing a car';

  @override
  String get homeProcess1Text =>
      'Take a look at our catalog and select the appropriate model.';

  @override
  String get homeProcess2Title => 'Booking';

  @override
  String get homeProcess2Text =>
      'Fill out the form on the website or contact us by phone.';

  @override
  String get homeProcess3Title => 'Confirmation';

  @override
  String get homeProcess3Text =>
      'Our manager will contact you to clarify the details.';

  @override
  String get homeProcess4Title => 'Getting a car';

  @override
  String get homeProcess4Text =>
      'Meeting at a place convenient for you, signing the contract and handing over the keys.';

  @override
  String get homeBenefitsTitle =>
      'We are interested in having you choose us again next time';

  @override
  String get homeBenefit1Title => '24/7 service';

  @override
  String get homeBenefit1Text =>
      'Our clients receive not only car rental, but also individual attention 24/7. A personal manager is always available to resolve issues during the entire rental period.';

  @override
  String get homeBenefit2Title => 'Complete security';

  @override
  String get homeBenefit2Text =>
      'All cars in our fleet are insured, providing you with peace of mind and confidence on any trip.';

  @override
  String get homeBenefit3Title => 'High quality cars';

  @override
  String get homeBenefit3Text =>
      'Our cars are always in excellent technical condition, equipped with winter tires in winter for your safety.';

  @override
  String get homeTermsTitle => 'The best conditions for a comfortable trip';

  @override
  String get homeTerms1Title => 'Minimum deposit';

  @override
  String get homeTerms1Text =>
      'When renting a car, you need to make a deposit, the amount of which depends on the type of transmission of the car.';

  @override
  String get homeTerms2Title => 'Age from 21 years old';

  @override
  String get homeTerms2Text =>
      'Driving experience minimum 2 years: insurance requirements are standard, without additional conditions.';

  @override
  String get homeTerms3Title => 'Honest risk sharing';

  @override
  String get homeTerms3Text =>
      'For maximum peace of mind for tenants, all vehicles are covered by mandatory third-party civil liability insurance, and many also have full insurance coverage.';

  @override
  String get homeTrafficTitle => 'Features of traffic in Georgia';

  @override
  String get homeTraffic1Title => 'Up to 60 km/h';

  @override
  String get homeTraffic1Text => 'In populated areas';

  @override
  String get homeTraffic2Title => 'Up to 90 km/h';

  @override
  String get homeTraffic2Text => 'Outside the settlements';

  @override
  String get homeTraffic3Title => 'Up to 110 km/h';

  @override
  String get homeTraffic3Text => 'On motorways';

  @override
  String get faqPageHeading => 'Answers to popular customer questions';

  @override
  String get faq1Question => 'What documents are required to rent a car?';

  @override
  String get faq1Answer =>
      'To rent a car, you will need a valid driver\'s license, passport and international driver\'s license (if your country is not included in the agreed list).';

  @override
  String get faq2Question => 'Where is the best place to refuel in Georgia?';

  @override
  String get faq2Answer =>
      'On each five-kilometer stretch of road you will find small gas stations, and larger ones are located 10-15 km away. The vast majority of stations operate around the clock. Various types of fuel are available to you, including diesel, 92nd, 95th and 98th gasoline.';

  @override
  String get faq3Question => 'How do I get a rental car?';

  @override
  String get faq3Answer =>
      'After successful booking, you can pick up the car at the specified location. Our representative will provide you with a car, check the necessary documents and tell you about the features of use.';

  @override
  String get faq4Question =>
      'Have plans changed: the cancellation process and related payments?';

  @override
  String get faq4Answer =>
      'If your plans have changed, you can cancel your reservation by contacting our support service. Depending on the date and reason for cancellation, certain payments may apply.';

  @override
  String get faq5Question =>
      'The impact of flight cancellation or postponement on car booking?';

  @override
  String get faq5Answer =>
      'If your flight is cancelled or rescheduled, please contact us as soon as possible. We will try to adapt your order according to the new schedule.';

  @override
  String get faq6Question => 'What expenses can I incur when renting a car?';

  @override
  String get faq6Answer =>
      'Expenses may include fuel, payment of fines for traffic violations and additional services if they are not included in the main package.';

  @override
  String get faq7Question => 'What happens if you break the lease?';

  @override
  String get faq7Answer =>
      'Violation of the lease agreement may result in unilateral termination of the agreement, fines under the agreement and legal consequences in accordance with the legislation of Georgia.';

  @override
  String get faq8Question =>
      'The procedure for paying for a car rental: when and how is it performed?';

  @override
  String get faq8Answer =>
      'The rent is paid at the time of signing the contract. We accept payments by cards, online transfers, and cryptocurrency — in any currency.';

  @override
  String get faq9Question => 'How should cars be returned after the rental?';

  @override
  String get faq9Answer =>
      'It is necessary to return the car in the same condition in which it was received, with the same fuel level. Our cars are available for rent in a clean condition.';

  @override
  String get faq10Question => 'What is the amount of the prepayment?';

  @override
  String get faq10Answer =>
      'The amount of the prepayment depends on the date of booking, the rental period and the selected car model. Details are discussed personally at the time of booking.';

  @override
  String get aboutText =>
      'Our company has been serving customers for years, offering high-quality, impeccably maintained, and clean vehicles. Our team of professionals is always ready to assist you 24/7. We provide not only high-quality cars but also excellent service and a friendly atmosphere. Our managers are always available to help you.';

  @override
  String get aboutContactsTitle => 'Contacts';

  @override
  String get aboutPhoneLabel => 'Phone';

  @override
  String get aboutEmailLabel => 'E-mail';

  @override
  String get aboutAddressLabel => 'Address';

  @override
  String get aboutWorkingHoursLabel => 'Working hours';

  @override
  String get aboutShowOnMap => 'Show on the map';

  @override
  String get aboutCopy => 'Copy';

  @override
  String get aboutCopied => 'Copied';

  @override
  String get aboutOpenFailed => 'Could not open the link. The text was copied.';

  @override
  String get aboutContactsError =>
      'Could not load the contact details. Please try again later.';

  @override
  String get aboutFacebook => 'Facebook';

  @override
  String get aboutInstagram => 'Instagram';

  @override
  String get aboutWhatsapp => 'WhatsApp';

  @override
  String get aboutTelegram => 'Telegram';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundText =>
      'This page does not exist. The address may be mistyped or out of date.';

  @override
  String get notFoundGoHome => 'Go to Home';
}
