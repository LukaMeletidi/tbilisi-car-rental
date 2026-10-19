/// The texts of the admin area. The admin area is English only, so they are
/// plain constants here and not in the translation files.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

const adminSignInTitle = 'Admin sign-in';
const adminEmailLabel = 'E-mail';
const adminPasswordLabel = 'Password';
const adminShowPassword = 'Show the password';
const adminHidePassword = 'Hide the password';
const adminSignInButton = 'Sign in';
const adminSigningIn = 'Signing in…';
const adminSignOutButton = 'Sign out';

const adminNoAccessText = 'This account has no admin access.';

const adminBookingsTitle = 'Bookings';
const adminTbilisiTimeNote = 'Tbilisi time (GMT+4)';
const adminNoBookings = 'No bookings yet.';
const adminBookingsNoAccess = 'You do not have access to the bookings.';
const adminBookingsLoadError = 'Could not load the bookings.';
const adminBookingsNoConnection =
    'No connection. The bookings could not be loaded.';
const adminTryAgain = 'Try again';
const adminOfflineNote = 'Offline: showing saved data';

/// The entries of the admin navigation.
const adminNavBookings = 'Bookings';
const adminNavCalendar = 'Calendar';
const adminNavCars = 'Cars';
const adminNavSettings = 'Settings';

/// The Settings page and its two pages (steps 6.5 to 6.7).
const adminSettingsTitle = 'Settings';
const adminSettingsExtrasTitle = 'Extras & Prices';
const adminSettingsExtrasDescription =
    'The price per day of each extra, in USD.';
const adminSettingsCompanyTitle = 'Company Info';
const adminSettingsCompanyDescription =
    'Name, contacts, address, working hours and links for the About Us '
    'page.';
const adminBackToSettings = 'Back to Settings';

/// The Extras & Prices form (step 6.6).
const adminExtrasNote =
    'Prices in USD per day. 0 is shown as Free. New prices apply to new '
    'totals; stored bookings keep their totals.';
const adminExtrasPriceSuffix = 'USD per day';
const adminExtrasSave = 'Save prices';
const adminLoadCurrentPrices = 'Load the current prices';
const adminExtrasSaved = 'Saved';
const adminExtrasChangedElsewhereBanner =
    'The prices were changed elsewhere. Saving will be refused.';
const adminExtrasUnreadable =
    'The stored prices cannot be read. They must be corrected in the '
    'Firebase console.';

/// The age range an extra is meant for, as in the public app (app_en.arb);
/// null for an extra without one. A test compares them.
String? adminExtraAgeRange(Extra extra) {
  switch (extra) {
    case Extra.snowChains:
      return null;
    case Extra.childSeat:
      return '1–4 years';
    case Extra.infantSeat:
      return '0–12 months';
    case Extra.boosterSeat:
      return '3–16 years';
  }
}

/// The label of the price field of an extra: "Child seat (1–4 years)".
String adminExtraPriceLabel(Extra extra) {
  final ages = adminExtraAgeRange(extra);
  return ages == null
      ? adminExtraName(extra)
      : '${adminExtraName(extra)} ($ages)';
}

/// The error under a price field.
String adminExtraPriceProblemText(ExtraPriceProblem problem) {
  switch (problem) {
    case ExtraPriceProblem.required:
      return 'Enter a price (0 for free).';
    case ExtraPriceProblem.invalid:
      return 'Use a number with at most two decimals, for example 5 or 4.50.';
    case ExtraPriceProblem.tooHigh:
      return 'At most $extraMaxPricePerDay USD per day.';
  }
}

/// The text shown when the prices could not be loaded.
String adminExtrasFailureText(ExtrasLoadFailure failure) {
  switch (failure) {
    case ExtrasLoadFailure.noConnection:
      return 'No connection. The prices could not be loaded.';
    case ExtrasLoadFailure.other:
      return 'The prices could not be loaded.';
  }
}

/// What the form says after an attempt to save the prices.
String adminExtrasSaveNoticeText(ExtrasSaveNotice notice) {
  switch (notice) {
    case ExtrasSaveNotice.saved:
      return adminExtrasSaved;
    case ExtrasSaveNotice.noAnswer:
      return 'No answer from the server. The prices may or may not be saved. '
          'Press "$adminSaveAgain" to check: if they were saved, nothing is '
          'written twice. Or load the prices as they are stored now.';
    case ExtrasSaveNotice.noConnection:
      return 'Not saved. No connection. Check your internet and try again.';
    case ExtrasSaveNotice.refused:
      return 'Not saved. The server refused the change. Check that you are '
          'still signed in as the admin.';
    case ExtrasSaveNotice.changedElsewhere:
      return 'Not saved. The prices were changed elsewhere. Load the current '
          'prices to see what is stored.';
    case ExtrasSaveNotice.unknown:
      return 'Not saved. Something went wrong. Try again.';
  }
}

/// The Company Info form (step 6.7).
const adminCompanyNote =
    'Everything here is public: it is shown on the About Us page. Leave a '
    'field empty to hide it.';
const adminCompanyCardCompany = 'Company';
const adminCompanyCardContacts = 'Contacts';
const adminCompanyCardAddress = 'Address';
const adminCompanyCardHours = 'Working hours';
const adminCompanyCardMap = 'Map';
const adminCompanyCardSocial = 'Social links';
const adminCompanyLabelName = 'Name';
const adminCompanyLabelPhone = 'Phone';
const adminCompanyLabelEmail = 'E-mail';
const adminCompanyLabelKa = 'Georgian (ka)';
const adminCompanyLabelRu = 'Russian (ru)';
const adminCompanyLabelEn = 'English (en)';
const adminCompanyLabelMap = 'Google Maps link';
const adminCompanyLabelFacebook = 'Facebook';
const adminCompanyLabelInstagram = 'Instagram';
const adminCompanyLabelWhatsapp = 'WhatsApp';
const adminCompanyLabelTelegram = 'Telegram';
const adminCompanySave = 'Save company info';
const adminLoadCurrentInfo = 'Load the current info';
const adminCompanySaved = 'Saved';
const adminCompanyChangedElsewhereBanner =
    'The company information was changed elsewhere. Saving will be refused.';
const adminCompanyUnreadable =
    'The stored company information cannot be read. It must be corrected in '
    'the Firebase console.';

/// The error under a field of the Company Info form.
String adminCompanyProblemText(CompanyField field, CompanyProblem problem) {
  switch (problem) {
    case CompanyProblem.tooLong:
      switch (field) {
        case CompanyField.name:
          return 'At most $companyNameMaxLength characters.';
        case CompanyField.address:
        case CompanyField.workingHours:
          return 'At most $companyTextMaxLength characters per language.';
        case CompanyField.phone:
        case CompanyField.email:
        case CompanyField.mapUrl:
        case CompanyField.facebook:
        case CompanyField.instagram:
        case CompanyField.whatsapp:
        case CompanyField.telegram:
          return 'At most $companyLinkMaxLength characters.';
      }
    case CompanyProblem.incomplete:
      return 'Fill in all three languages, or leave all three empty.';
    case CompanyProblem.notHttps:
      return 'Use an address that starts with https://.';
    case CompanyProblem.invalid:
      switch (field) {
        case CompanyField.phone:
          return 'Use the international format, for example '
              '+995 555 00 00 00.';
        case CompanyField.email:
          return 'Use an address like name@example.com.';
        case CompanyField.name:
        case CompanyField.address:
        case CompanyField.workingHours:
        case CompanyField.mapUrl:
        case CompanyField.facebook:
        case CompanyField.instagram:
        case CompanyField.whatsapp:
        case CompanyField.telegram:
          return 'Use a full web address without spaces, for example '
              'https://www.example.com/page.';
      }
  }
}

/// The text shown when the company information could not be loaded.
String adminCompanyFailureText(CompanyLoadFailure failure) {
  switch (failure) {
    case CompanyLoadFailure.noConnection:
      return 'No connection. The company information could not be loaded.';
    case CompanyLoadFailure.other:
      return 'The company information could not be loaded.';
  }
}

/// What the form says after an attempt to save the company information.
String adminCompanySaveNoticeText(CompanySaveNotice notice) {
  switch (notice) {
    case CompanySaveNotice.saved:
      return adminCompanySaved;
    case CompanySaveNotice.noAnswer:
      return 'No answer from the server. The company information may or may '
          'not be saved. Press "$adminSaveAgain" to check: if it was saved, '
          'nothing is written twice. Or load the information as it is '
          'stored now.';
    case CompanySaveNotice.noConnection:
      return 'Not saved. No connection. Check your internet and try again.';
    case CompanySaveNotice.refused:
      return 'Not saved. The server refused the change. Check that you are '
          'still signed in as the admin.';
    case CompanySaveNotice.changedElsewhere:
      return 'Not saved. The company information was changed elsewhere. '
          'Load the current info to see what is stored.';
    case CompanySaveNotice.unknown:
      return 'Not saved. Something went wrong. Try again.';
  }
}

/// The Calendar page (steps 5.5a and 5.5b).
const adminCalendarTitle = 'Calendar';
const adminCalendarLoading = 'Loading the calendar…';
const adminCalendarNoConnection =
    'No connection. The calendar could not be loaded.';
const adminCalendarNoAccess = 'You do not have access to the calendar.';
const adminCalendarLoadError = 'The calendar could not be loaded.';
const adminCalendarNoBookings = 'No confirmed bookings in these 14 days.';
const adminCalendarNoCars = 'There are no cars yet.';
const adminCalendarHiddenCar = 'Hidden';
const adminCalendarUnknownCar = 'Unknown car';
const adminCalendarPrevious = 'Previous 7 days';
const adminCalendarNext = 'Next 7 days';
const adminCalendarToday = 'Today';
const adminCalendarCarColumn = 'Car';

/// The line about confirmed booking documents the calendar could not read.
String adminCalendarUnreadable(int count) => count == 1
    ? '1 confirmed booking could not be read and is not shown.'
    : '$count confirmed bookings could not be read and are not shown.';

/// The label of a header cell for a screen reader: "Friday 16 Oct 2026",
/// and ", today" for today.
String adminCalendarDayLabel(String fullDate, {required bool today}) =>
    today ? '$fullDate, today' : fullDate;

/// The tooltip and screen-reader label of a booking on the calendar: the
/// times only, never a name or another detail of the customer.
String adminCalendarBarLabel(
  DateTime pickupUtc,
  DateTime dropoffUtc, {
  required bool tooClose,
}) {
  final times =
      'Confirmed booking, ${formatAdminUtc(pickupUtc)} to '
      '${formatAdminUtc(dropoffUtc)} (Tbilisi time).';
  return tooClose
      ? '$times Too close to another booking of this car. Opens the booking.'
      : '$times Opens the booking.';
}

/// The fleet list (step 4.4b).
const adminCarsTitle = 'Cars';
const adminNoCars = 'No cars yet.';
const adminCarsNoConnection = 'No connection. The cars could not be loaded.';
const adminCarsNoAccess = 'You do not have access to the cars.';
const adminCarsLoadError = 'Could not load the cars.';
const adminCarBadgeVisible = 'Visible';
const adminCarBadgeHidden = 'Hidden';
const adminCarNeedsRepair = 'Needs repair';
const adminCarUnreadable = 'Unreadable car';

/// Hide and show on the fleet list (step 4.5).
const adminCarHide = 'Hide';
const adminCarShow = 'Show';
const adminCancel = 'Cancel';
const adminHideCarTitle = 'Hide this car?';
const adminHiddenCarNote =
    'A hidden car disappears from the public catalog. '
    'Existing bookings are not changed.';

/// The edit form of a car (step 4.5).
const adminCarEditTitle = 'Edit the car';
const adminBackToCars = 'Back to the cars';
const adminCarMissing = 'This car does not exist.';
const adminCarUnreadableText =
    'This car cannot be read by the app. Repair it in the Firebase console.';
const adminCarRepairNote =
    'This car needs repair: it does not meet the current rules. Fill in the '
    'marked fields. A save writes the whole car again and removes anything '
    'the app does not know.';
const adminCarChangedElsewhereBanner =
    'This car was changed elsewhere. Saving will be refused.';
const adminLoadCurrentCar = 'Load the current car';
const adminSaveAgain = 'Save again';
const adminCarSaved = 'Saved';
const adminCarSectionCar = 'The car';
const adminCarSectionPrice = 'Price';
const adminCarSectionDescriptions = 'Descriptions';
const adminCarSectionPhotos = 'Photos';
const adminCarSectionVisibility = 'Visibility';
const adminCarLabelBrand = 'Brand';
const adminCarLabelModel = 'Model';
const adminCarLabelYear = 'Year';
const adminCarLabelDrivetrain = 'Drivetrain';
const adminCarLabelTransmission = 'Transmission';
const adminCarLabelFuelType = 'Fuel type';
const adminCarLabelSeats = 'Seats';
const adminCarLabelEngineSize = 'Engine size (litres, optional)';
const adminCarLabelPrice = 'Price per day (USD)';
const adminCarPriceNote =
    'Changing the price does not change the totals of existing bookings.';
const adminCarLabelDescriptionKa = 'Description (Georgian)';
const adminCarLabelDescriptionRu = 'Description (Russian)';
const adminCarLabelDescriptionEn = 'Description (English)';
const adminCarPhotosNote =
    'At most $carMaxPhotos addresses, each starting with $carPhotoScheme. '
    'The first photo is shown in the catalog.';
const adminCarNoPhotos = 'No photos. The catalog shows a placeholder.';
const adminCarAddPhoto = 'Add photo address';
const adminCarMovePhotoUp = 'Move up';
const adminCarMovePhotoDown = 'Move down';
const adminCarRemovePhoto = 'Remove';
const adminCarLabelVisible = 'Visible in the catalog';

/// The "new car" form (step 4.6).
const adminAddCar = 'Add a car';
const adminNewCarTitle = 'New car';
const adminNewCarVisibilityNote =
    'A new car is saved hidden. Turn this on to show it in the public '
    'catalog at once.';
const adminNewCarSavedHidden =
    'Saved. The new car is hidden; use Show on its card to put it in the '
    'catalog.';
const adminNewCarSavedVisible = 'Saved.';
const adminCarMayExistText = 'The car may already exist. Check the cars list.';
const adminLoadMore = 'Load more';
const adminEstimate = 'estimate';

const adminFilterAll = 'All';
const adminSearchHint = 'Name or phone';
const adminClearSearch = 'Clear search';
const adminNoMatch = 'No bookings match.';
const adminClearFilters = 'Clear filters';

/// The text of a status chip of the filter: "New 2", "All 7".
String adminChipLabel(String label, int count) => '$label $count';

/// The name of an order of the list.
String adminSortLabel(AdminBookingsSort sort) {
  switch (sort) {
    case AdminBookingsSort.newestFirst:
      return 'Newest first';
    case AdminBookingsSort.oldestFirst:
      return 'Oldest first';
    case AdminBookingsSort.pickupDate:
      return 'Pickup date';
  }
}

/// The tooltip of the sort button: "Sort: Newest first".
String adminSortTooltip(AdminBookingsSort sort) =>
    'Sort: ${adminSortLabel(sort)}';

/// Shown while older bookings can still be loaded: the filter, the counts
/// and the order only know the loaded ones.
String adminLoadedOnlyNote(int loaded) =>
    'Filters and counts cover the $loaded loaded bookings. '
    'Load more to include older ones.';

const adminNotFoundText = 'This admin page does not exist.';
const adminBackToBookings = 'Back to the bookings';

const adminBookingTitle = 'Booking';
const adminBookingMissing =
    'This booking does not exist. It may have been deleted.';
const adminBookingUnreadable = 'This booking cannot be read.';
const adminBookingLoadError = 'Could not load the booking.';
const adminBookingNoAccess = 'You do not have access to this booking.';

const adminSectionStatus = 'Status';
const adminSectionCustomer = 'Customer';
const adminSectionRental = 'Rental';
const adminSaving = 'Saving…';
const adminDismissNotice = 'Hide this message';

const adminLabelName = 'Name';
const adminLabelPhone = 'Phone';
const adminLabelEmail = 'E-mail';
const adminLabelLanguage = 'Language of the customer';
const adminLabelCar = 'Car';
const adminLabelPickup = 'Pickup';
const adminLabelDropoff = 'Drop-off';
const adminLabelExtras = 'Extras';
const adminLabelNotes = 'Notes';
const adminLabelTotal = 'Days and total';
const adminOnWhatsapp = 'WhatsApp';
const adminOnTelegram = 'Telegram';
const adminNoExtras = 'None';

/// Shown for a fixed place whose name cannot be looked up.
const adminUnknownPlace = 'A place from our list';

const adminConfirmTitle = 'Change the status?';
const adminConfirmYes = 'Change';
const adminConfirmNo = 'Keep';

/// The button that changes the status: "Set to Confirmed".
String adminChangeTo(BookingStatus status) =>
    'Set to ${adminStatusLabel(status)}';

/// The question before a change that is hard on the customer.
String adminConfirmText(BookingStatus from, BookingStatus to) =>
    'The status changes from "${adminStatusLabel(from)}" to '
    '"${adminStatusLabel(to)}".';

/// What is said after an attempt to change the status. Only "Saved" means
/// the server confirmed it. "No answer" does not say "not saved": the change
/// may still have arrived, and the status on screen is the stored one.
///
/// [fields] are the names of the unknown fields, for
/// [AdminStatusChangeNotice.unknownFields].
String adminStatusNoticeText(
  AdminStatusChangeNotice notice, {
  List<String> fields = const [],
}) {
  switch (notice) {
    case AdminStatusChangeNotice.saved:
      return 'Saved';
    case AdminStatusChangeNotice.noAnswer:
      return 'No answer from the server. '
          'The status shown is the current one.';
    case AdminStatusChangeNotice.noConnection:
      return 'Not saved. No connection.';
    case AdminStatusChangeNotice.refused:
      return 'Not saved. The change was refused.';
    case AdminStatusChangeNotice.bookingMissing:
      return 'Not saved. This booking no longer exists.';
    case AdminStatusChangeNotice.unknownFields:
      return 'Not saved. ${adminUnknownFieldsText(fields)}';
    case AdminStatusChangeNotice.noCreatedAt:
      return 'Not saved. $adminNoCreatedAtText';
    case AdminStatusChangeNotice.storedFormat:
      return 'Not saved. ${adminStoredFormatNoticeText(fields)}';
    case AdminStatusChangeNotice.unknown:
      return 'Not saved. Please try again.';
  }
}

/// Said when the stored document has fields the Firestore rules do not
/// know: they refuse every change of such a document. The names are
/// shown, never the values.
String adminUnknownFieldsText(List<String> fields) {
  final names = fields.join(', ');
  if (fields.isEmpty) {
    return 'This booking has a field the app does not know. '
        'Remove it in the Firebase console.';
  }
  return fields.length == 1
      ? 'This booking has a field the app does not know: $names. '
            'Remove it in the Firebase console.'
      : 'This booking has fields the app does not know: $names. '
            'Remove them in the Firebase console.';
}

/// Said when the stored document has no createdAt: the rules refuse every
/// change of such a document.
const adminNoCreatedAtText =
    'This booking has no creation date and cannot be changed from the app.';

/// The name of an edited part of a booking, by its stored field name, for
/// the conflict message. An unknown name is shown as it is.
String adminFieldName(String storedKey) {
  for (final field in AdminBookingField.values) {
    if (field.storedKey != storedKey) continue;
    switch (field) {
      case AdminBookingField.customer:
        return 'customer';
      case AdminBookingField.car:
        return 'car';
      case AdminBookingField.pickup:
        return 'pickup time';
      case AdminBookingField.dropoff:
        return 'drop-off time';
      case AdminBookingField.pickupLocation:
        return 'pickup place';
      case AdminBookingField.dropoffLocation:
        return 'drop-off place';
      case AdminBookingField.extras:
        return 'extras';
      case AdminBookingField.notes:
        return 'notes';
      case AdminBookingField.total:
        return 'total';
      case AdminBookingField.language:
        return 'language';
    }
  }
  return storedKey;
}

/// What is said after an attempt to save an edit. Only "Saved" means the
/// server confirmed it. "No answer" does not say "not saved".
///
/// [fields] are the unknown field names for
/// [AdminBookingSaveNotice.unknownFields], and the stored names of the
/// parts that were changed elsewhere for [AdminBookingSaveNotice.conflict].
String adminSaveNoticeText(
  AdminBookingSaveNotice notice, {
  List<String> fields = const [],
}) {
  switch (notice) {
    case AdminBookingSaveNotice.saved:
      return 'Saved';
    case AdminBookingSaveNotice.noAnswer:
      return 'No answer from the server. '
          'Open the booking to see what is stored.';
    case AdminBookingSaveNotice.noConnection:
      return 'Not saved. No connection.';
    case AdminBookingSaveNotice.refused:
      return 'Not saved. The change was refused.';
    case AdminBookingSaveNotice.bookingMissing:
      return 'Not saved. This booking no longer exists.';
    case AdminBookingSaveNotice.carMissing:
      return 'Not saved. This car no longer exists. Choose another car.';
    case AdminBookingSaveNotice.unknownFields:
      return 'Not saved. ${adminUnknownFieldsText(fields)}';
    case AdminBookingSaveNotice.noCreatedAt:
      return 'Not saved. $adminNoCreatedAtText';
    case AdminBookingSaveNotice.storedFormat:
      return 'Not saved. ${adminStoredFormatNoticeText(fields)}';
    case AdminBookingSaveNotice.conflict:
      final names = fields.map(adminFieldName).join(', ');
      return names.isEmpty
          ? 'This booking was changed elsewhere. '
                'Your changes were not saved.'
          : 'This booking was changed elsewhere ($names). '
                'Your changes were not saved.';
    case AdminBookingSaveNotice.unknown:
      return 'Not saved. Please try again.';
  }
}

/// Said for a part the admin did not touch whose stored value the
/// Firestore rules refuse (for example a phone written by hand with
/// spaces). [part] starts the sentence: "The phone number".
String adminStoredFormatText(String part) =>
    '$part is stored in a format the app does not accept. '
    'Edit it to correct it.';

/// Said after a write that was not made because a part that is not
/// written is stored in a form the rules refuse. [errorNames] are the
/// names of the AdminBookingError values; each gives its sentence, for
/// example "The phone number is stored in a format the app does not
/// accept. Edit it to correct it."
String adminStoredFormatNoticeText(List<String> errorNames) {
  final sentences = [
    for (final error in AdminBookingError.values)
      if (errorNames.contains(error.name)) adminBookingErrorText(error),
  ];
  return sentences.isEmpty
      ? adminStoredFormatText('A value of this booking')
      : sentences.join(' ');
}

const adminEditTooltip = 'Edit';
const adminEditTitle = 'Edit the booking';
const adminSave = 'Save';
const adminCorrectFields = 'Correct the marked fields.';

const adminSectionCar = 'Car';
const adminSectionDates = 'Dates and places';
const adminSectionExtras = 'Extras';
const adminSectionNotes = 'Notes';
const adminSectionTotal = 'Total';

const adminLabelPickupTime = 'Pickup time';
const adminLabelDropoffTime = 'Drop-off time';
const adminLabelPickupPlace = 'Pickup place';
const adminLabelDropoffPlace = 'Drop-off place';
const adminLabelAddress = 'Address';
const adminOtherPlace = 'Other place';

const adminPickupInPastNote = 'The pickup is in the past.';
const adminCarsNotLoaded =
    'The cars could not be loaded. The car cannot be changed.';
const adminPlacesNotLoaded =
    'The places could not be loaded. Only the stored place or another '
    'address can be chosen.';

/// A car that is hidden from the public: "Toyota Prius, 2019 (hidden)".
String adminCarHidden(String title) => '$title (hidden)';

/// A car ID that no car has any more: "abc123 (not found)".
String adminCarNotFound(String carId) => '$carId (not found)';

/// A stored place that settings no longer has.
String adminPlaceNotInList(String id) => '$id (not in the list any more)';

/// An extra with its current price: "Child seat · $5 per day".
String adminExtraWithPrice(Extra extra, double? pricePerDay) =>
    pricePerDay == null
    ? adminExtraName(extra)
    : '${adminExtraName(extra)} · ${adminAmount(pricePerDay)} per day';

/// "Stored total: 5 days · $225".
String adminStoredTotal(int days, double total) =>
    'Stored total: ${adminDays(days)} · ${adminAmount(total)}';

/// "New total: 7 days × ($45 car + $6.50 extras) = $360.50", with
/// " · estimate" for more than 7 days.
String adminNewTotal({
  required int days,
  required double carPerDay,
  required double extrasPerDay,
  required double total,
  required bool estimate,
}) =>
    'New total: ${adminDays(days)} × (${adminAmount(carPerDay)} car + '
    '${adminAmount(extrasPerDay)} extras) = ${adminAmount(total)}'
    '${estimate ? ' · $adminEstimate' : ''}';

const adminNewTotalUsesTodaysPrices = "The new total uses today's prices.";
const adminTotalStays = 'The total stays as it is.';
const adminNewTotalNoPrices =
    'The new total cannot be calculated: the prices could not be loaded.';
const adminNewTotalNoDates =
    'The new total cannot be calculated from these dates.';

/// "Keep the stored total ($225)".
String adminKeepStoredTotal(double total) =>
    'Keep the stored total (${adminAmount(total)})';

/// "Use the new total ($360.50)".
String adminUseNewTotal(double total) =>
    'Use the new total (${adminAmount(total)})';

const adminDiscardTitle = 'Discard your changes?';
const adminKeepEditing = 'Keep editing';
const adminDiscard = 'Discard';
const adminLoadCurrent = 'Load the current booking';

/// The banner shown while the form has changes in parts that were changed
/// elsewhere: "This booking was changed elsewhere (car). Saving will be
/// refused." [fields] are stored field names.
String adminChangedElsewhereBanner(List<String> fields) {
  final names = fields.map(adminFieldName).join(', ');
  return 'This booking was changed elsewhere ($names). '
      'Saving will be refused.';
}

/// Shown instead of the address for a customer who has no e-mail (the
/// stored value is then a placeholder; see noEmailPlaceholder).
const adminNoEmail = 'No e-mail';

const adminTotalUsesTodaysPrices = "The total uses today's prices.";
const adminNewTotalIncomplete = 'Choose a car and the dates to see the total.';
const adminNewTotalNoPricesLoaded =
    'The total cannot be calculated: the prices could not be loaded.';
const adminCheckAgain = 'Check again';
const adminChecking = 'Checking…';

const adminNewBookingTitle = 'New booking';
const adminNoEmailSwitch = 'The customer has no e-mail';
const adminCarsLoading = 'Loading the cars…';
const adminCarsLoadFailed = 'The cars could not be loaded.';

/// Asked before the "new booking" form is left while the booking may
/// already exist (the server did not answer the save).
const adminLeaveTitle = 'Leave this form?';
const adminMayExistText =
    'The booking may already exist. Check the bookings list.';
const adminStay = 'Stay';
const adminLeave = 'Leave';

/// The total line of the "new booking" form. For a total it is
/// "Total: 5 days × ($45 car + $5 extras) = $250", with " · estimate" for
/// more than 7 days; otherwise the reason why there is none yet.
String adminNewBookingTotalText(AdminNewTotal total) {
  final price = total.price;
  switch (total.state) {
    case AdminNewTotalState.incomplete:
      return adminNewTotalIncomplete;
    case AdminNewTotalState.pricesNotLoaded:
      return adminNewTotalNoPricesLoaded;
    case AdminNewTotalState.ready:
    case AdminNewTotalState.tooHigh:
      return 'Total: ${adminDays(price!.days)} × '
          '(${adminAmount(total.carPricePerDay!)} car + '
          '${adminAmount(total.extrasPerDay!)} extras) = '
          '${adminAmount(price.total)}'
          '${price.isIndividualPrice ? ' · $adminEstimate' : ''}';
  }
}

/// What is said after an attempt to create a booking. Only "Saved" means
/// the server confirmed it. "No answer" does not say "not saved": the
/// booking may exist, and "Check again" finds out without creating a
/// second one.
String adminCreateNoticeText(AdminBookingCreateNotice notice) {
  switch (notice) {
    case AdminBookingCreateNotice.saved:
      return 'Saved';
    case AdminBookingCreateNotice.noAnswer:
      return 'No answer from the server. Press "$adminCheckAgain": '
          'the booking will not be created twice.';
    case AdminBookingCreateNotice.stillUnknown:
      return 'Still no answer from the server. Check the connection and '
          'press "$adminCheckAgain": the booking will not be created twice.';
    case AdminBookingCreateNotice.noConnection:
      return 'Not saved. No connection.';
    case AdminBookingCreateNotice.refused:
      return 'Not saved. The booking was refused.';
    case AdminBookingCreateNotice.carMissing:
      return 'Not saved. This car no longer exists. Choose another car.';
    case AdminBookingCreateNotice.unknown:
      return 'Not saved. Please try again.';
  }
}

const adminDeleteButton = 'Delete this booking';
const adminDeleteTitle = 'Delete this booking?';
const adminDeleteYes = 'Delete';
const adminDeleting = 'Deleting…';
const adminDeleteCannotBeUndone =
    'This cannot be undone. To keep the booking but mark it as not taking '
    'place, set its status to Cancelled instead.';
const adminDeleteConfirmedWarning =
    'This booking is confirmed. The customer expects the car.';

/// The lines of the question "Delete this booking?" that say WHICH booking
/// it is: the customer's name, the car, the pickup in Tbilisi time and
/// the status.
List<String> adminDeleteDialogLines(Booking booking, AdminCarLabel car) => [
  booking.customer.fullName,
  adminCarText(car),
  'Pickup: ${formatAdminUtc(booking.pickup)}',
  'Status: ${adminStatusLabel(booking.status)}',
];

/// What the detail says after an attempt to delete that left the booking
/// on screen. "No answer" does not say "not deleted": the booking may be
/// gone, and then the page says so by itself.
String adminDeleteNoticeText(AdminBookingDeleteNotice notice) {
  switch (notice) {
    case AdminBookingDeleteNotice.noAnswer:
      return 'No answer from the server. If the booking is still shown '
          'here, it was not deleted.';
    case AdminBookingDeleteNotice.noConnection:
      return 'Not deleted. No connection.';
    case AdminBookingDeleteNotice.refused:
      return 'Not deleted. The change was refused.';
    case AdminBookingDeleteNotice.statusChanged:
      return 'Not deleted. The status of this booking was changed '
          'elsewhere. Look at it again.';
    case AdminBookingDeleteNotice.unknown:
      return 'Not deleted. Please try again.';
  }
}

/// What the bookings list says once after a booking is gone.
String adminDeletedNoticeText(AdminDeletedNotice notice) {
  switch (notice) {
    case AdminDeletedNotice.deleted:
      return 'Booking deleted.';
    case AdminDeletedNotice.alreadyDeleted:
      return 'This booking was already deleted.';
  }
}

/// The text for a problem of the edit form.
String adminBookingErrorText(AdminBookingError error) {
  switch (error) {
    case AdminBookingError.nameRequired:
      return 'Enter the name.';
    case AdminBookingError.nameTooShort:
      return 'The name is too short.';
    case AdminBookingError.nameTooLong:
      return 'The name is too long (100 characters at most).';
    case AdminBookingError.phoneRequired:
      return 'Enter the phone number.';
    case AdminBookingError.phoneInvalid:
      return 'Enter the phone number in international format, '
          'for example +995 555 12 34 56.';
    case AdminBookingError.emailRequired:
      return 'Enter the e-mail address.';
    case AdminBookingError.emailInvalid:
      return 'This e-mail address is not valid.';
    case AdminBookingError.emailTooLong:
      return 'The e-mail address is too long.';
    case AdminBookingError.carRequired:
      return 'Choose a car.';
    case AdminBookingError.carMissing:
      return 'This car no longer exists. Choose another car.';
    case AdminBookingError.pickupRequired:
      return 'Choose the pickup date and time.';
    case AdminBookingError.dropoffRequired:
      return 'Choose the drop-off date and time.';
    case AdminBookingError.dropoffNotAfterPickup:
      return 'The drop-off must be after the pickup.';
    case AdminBookingError.rentalTooLong:
      return 'A rental can be 365 days at most.';
    case AdminBookingError.pickupLocationRequired:
      return 'Choose the pickup place.';
    case AdminBookingError.dropoffLocationRequired:
      return 'Choose the drop-off place.';
    case AdminBookingError.pickupLocationUnknown:
    case AdminBookingError.dropoffLocationUnknown:
      return 'This place is not in the list. Choose another place.';
    case AdminBookingError.pickupLocationTextRequired:
    case AdminBookingError.dropoffLocationTextRequired:
      return 'Enter the address.';
    case AdminBookingError.pickupLocationTextTooLong:
    case AdminBookingError.dropoffLocationTextTooLong:
      return 'The address is too long (200 characters at most).';
    case AdminBookingError.notesTooLong:
      return 'The notes are too long (500 characters at most).';
    case AdminBookingError.nameStoredFormat:
      return adminStoredFormatText('The name');
    case AdminBookingError.phoneStoredFormat:
      return adminStoredFormatText('The phone number');
    case AdminBookingError.emailStoredFormat:
      return adminStoredFormatText('The e-mail address');
    case AdminBookingError.pickupLocationStoredFormat:
      return adminStoredFormatText('The pickup place');
    case AdminBookingError.dropoffLocationStoredFormat:
      return adminStoredFormatText('The drop-off place');
    case AdminBookingError.totalChoiceRequired:
      return 'Choose which total to save.';
    case AdminBookingError.newTotalUnavailable:
      return 'The new total cannot be calculated. Keep the stored total.';
    case AdminBookingError.totalTooHigh:
      return 'The new total is too high to be saved.';
  }
}

/// The English name of an extra.
String adminExtraName(Extra extra) {
  switch (extra) {
    case Extra.snowChains:
      return 'Snow chains';
    case Extra.childSeat:
      return 'Child seat';
    case Extra.infantSeat:
      return 'Infant seat';
    case Extra.boosterSeat:
      return 'Booster seat';
  }
}

/// The language the customer used: "Georgian (ka)".
String adminLanguageLabel(AppLanguage language) {
  switch (language) {
    case AppLanguage.en:
      return 'English (en)';
    case AppLanguage.ka:
      return 'Georgian (ka)';
    case AppLanguage.ru:
      return 'Russian (ru)';
  }
}

/// "Created by Nino"; only for a booking made by an admin.
String adminCreatedBy(String name) => 'Created by $name';

/// "Booking ID: abc123".
String adminBookingIdText(String id) => 'Booking ID: $id';

/// The text shown when one booking could not be loaded.
String adminBookingFailureText(AdminBookingsFailure failure) {
  switch (failure) {
    case AdminBookingsFailure.permissionDenied:
      return adminBookingNoAccess;
    case AdminBookingsFailure.noConnection:
    case AdminBookingsFailure.other:
      return adminBookingLoadError;
  }
}

/// "1 booking could not be read." / "3 bookings could not be read."
String adminUnreadableBookings(int count) => count == 1
    ? '1 booking could not be read.'
    : '$count bookings could not be read.';

/// "1 day" / "5 days".
String adminDays(int days) => days == 1 ? '1 day' : '$days days';

/// An amount in US dollars: "$225", "$272.50".
String adminAmount(double amount) => '\$${formatPrice(amount)}';

/// "Received 9 Oct 2026 17:34"; [dateTime] is already formatted.
String adminReceived(String dateTime) => 'Received $dateTime';

/// The word on the status chip. The chip always shows this text; the
/// colour alone never carries the meaning.
String adminStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.newBooking:
      return 'New';
    case BookingStatus.pending:
      return 'Pending';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.cancelled:
      return 'Cancelled';
  }
}

/// The car line of a row.
String adminCarText(AdminCarLabel car) {
  switch (car.state) {
    case AdminCarState.active:
      return car.title!;
    case AdminCarState.hidden:
      return '${car.title} (hidden)';
    case AdminCarState.notFound:
      return 'Car not found';
    case AdminCarState.notLoaded:
      return 'Car: not loaded';
  }
}

/// The text shown when the bookings could not be loaded.
String adminBookingsFailureText(AdminBookingsFailure failure) {
  switch (failure) {
    case AdminBookingsFailure.permissionDenied:
      return adminBookingsNoAccess;
    case AdminBookingsFailure.noConnection:
      return adminBookingsNoConnection;
    case AdminBookingsFailure.other:
      return adminBookingsLoadError;
  }
}

/// The text shown for a failed sign-in. The raw code of Firebase is never
/// shown, and a wrong e-mail is not told apart from a wrong password.
String adminSignInFailureText(AdminSignInFailure failure) {
  switch (failure) {
    case AdminSignInFailure.missingInput:
      return 'Enter your e-mail and password.';
    case AdminSignInFailure.invalidEmail:
      return 'This e-mail address is not valid.';
    case AdminSignInFailure.wrongCredentials:
      return 'The e-mail or the password is wrong.';
    case AdminSignInFailure.tooManyAttempts:
      return 'Too many attempts. Wait a few minutes and try again.';
    case AdminSignInFailure.noConnection:
      return 'No connection. Check your internet and try again.';
    case AdminSignInFailure.accountDisabled:
      return 'This account is disabled.';
    case AdminSignInFailure.unknown:
      return 'Sign-in did not work. Please try again.';
  }
}

/// The text of a problem of a field of the car form. The numbers come from
/// car_limits.dart, so the texts follow the limits. The "for example"
/// values are only examples.
String adminCarErrorText(CarError error) {
  switch (error) {
    case CarError.brandRequired:
      return 'Enter the brand, for example Toyota.';
    case CarError.brandTooLong:
      return 'The brand can have at most $carNameMaxLength characters.';
    case CarError.modelRequired:
      return 'Enter the model, for example Prius.';
    case CarError.modelTooLong:
      return 'The model can have at most $carNameMaxLength characters.';
    case CarError.yearRequired:
      return 'Enter the year the car was made, for example 2019.';
    case CarError.yearNotWhole:
      return 'Enter the year as a whole number, for example 2019.';
    case CarError.yearTooOld:
      return 'The year cannot be before $carMinYear.';
    case CarError.yearTooNew:
      return 'The year cannot be later than next year.';
    case CarError.drivetrainRequired:
      return 'Choose the drivetrain.';
    case CarError.transmissionRequired:
      return 'Choose the transmission.';
    case CarError.fuelTypeRequired:
      return 'Choose the fuel type.';
    case CarError.seatsRequired:
      return 'Enter the number of seats, for example 5.';
    case CarError.seatsNotWhole:
      return 'Enter the seats as a whole number, for example 5.';
    case CarError.seatsOutOfRange:
      return 'A car has $carMinSeats to $carMaxSeats seats.';
    case CarError.engineSizeInvalid:
      return 'Enter the engine size in litres, for example 1.6, or leave it '
          'empty.';
    case CarError.engineSizeOutOfRange:
      return 'The engine size must be more than 0 and at most '
          '$carMaxEngineSize litres.';
    case CarError.priceRequired:
      return 'Enter the price per day in USD, for example 45.';
    case CarError.priceInvalid:
      return 'Enter the price as a number with at most two decimals, for '
          'example 45.50.';
    case CarError.priceOutOfRange:
      return 'The price per day must be more than 0 and at most '
          '$carMaxPricePerDay USD.';
    case CarError.descriptionKaRequired:
      return 'Enter the description in Georgian.';
    case CarError.descriptionKaTooLong:
      return 'The Georgian description can have at most '
          '$carDescriptionMaxLength characters.';
    case CarError.descriptionRuRequired:
      return 'Enter the description in Russian.';
    case CarError.descriptionRuTooLong:
      return 'The Russian description can have at most '
          '$carDescriptionMaxLength characters.';
    case CarError.descriptionEnRequired:
      return 'Enter the description in English.';
    case CarError.descriptionEnTooLong:
      return 'The English description can have at most '
          '$carDescriptionMaxLength characters.';
    case CarError.tooManyPhotos:
      return 'A car can have at most $carMaxPhotos photos.';
  }
}

/// The text of a problem of one photo address.
String adminCarPhotoErrorText(CarPhotoError error) {
  switch (error) {
    case CarPhotoError.notHttps:
      return 'The address must start with $carPhotoScheme.';
    case CarPhotoError.hasSpace:
      return 'The address cannot contain spaces.';
    case CarPhotoError.notWebAddress:
      return 'This is not a web address.';
    case CarPhotoError.tooLong:
      return 'The address can have at most $carPhotoMaxLength characters.';
    case CarPhotoError.duplicate:
      return 'This photo is already in the list.';
  }
}

/// The text shown when the cars could not be loaded.
String adminCarsFailureText(FleetLoadFailure failure) {
  switch (failure) {
    case FleetLoadFailure.permissionDenied:
      return adminCarsNoAccess;
    case FleetLoadFailure.noConnection:
      return adminCarsNoConnection;
    case FleetLoadFailure.other:
      return adminCarsLoadError;
  }
}

/// The text shown when the calendar could not be loaded.
String adminCalendarFailureText(AdminBookingsFailure failure) {
  switch (failure) {
    case AdminBookingsFailure.permissionDenied:
      return adminCalendarNoAccess;
    case AdminBookingsFailure.noConnection:
      return adminCalendarNoConnection;
    case AdminBookingsFailure.other:
      return adminCalendarLoadError;
  }
}

/// The text shown when the car of the edit form could not be loaded.
String adminCarFailureText(FleetLoadFailure failure) {
  switch (failure) {
    case FleetLoadFailure.permissionDenied:
      return 'You do not have access to this car.';
    case FleetLoadFailure.noConnection:
      return 'No connection. The car could not be loaded.';
    case FleetLoadFailure.other:
      return 'Could not load the car.';
  }
}

/// "Photo address 1".
String adminCarPhotoLabel(int index) => 'Photo address ${index + 1}';

String adminTransmissionLabel(Transmission transmission) {
  switch (transmission) {
    case Transmission.automatic:
      return 'Automatic';
    case Transmission.manual:
      return 'Manual';
  }
}

String adminFuelTypeLabel(FuelType fuelType) {
  switch (fuelType) {
    case FuelType.petrol:
      return 'Petrol';
    case FuelType.diesel:
      return 'Diesel';
    case FuelType.hybrid:
      return 'Hybrid';
    case FuelType.electric:
      return 'Electric';
  }
}

/// What the edit form says after an attempt to save the car.
String adminCarSaveNoticeText(CarSaveNotice notice) {
  switch (notice) {
    case CarSaveNotice.saved:
      return adminCarSaved;
    case CarSaveNotice.noAnswer:
      return 'No answer from the server. The car may or may not be saved. '
          'Press "$adminSaveAgain" to check: if it was saved, nothing is '
          'written twice. Or load the car as it is stored now.';
    case CarSaveNotice.noConnection:
      return 'Not saved. No connection. Check your internet and try again.';
    case CarSaveNotice.refused:
      return 'Not saved. The server refused the change. Check that you are '
          'still signed in as the admin.';
    case CarSaveNotice.carMissing:
      return 'Not saved. This car no longer exists.';
    case CarSaveNotice.changedElsewhere:
      return 'Not saved. This car was changed elsewhere. Load the current '
          'car to see what is stored.';
    case CarSaveNotice.unknown:
      return 'Not saved. Something went wrong. Try again.';
  }
}

/// What the "new car" form says after an attempt to save.
String adminCarCreateNoticeText(CarCreateNotice notice) {
  switch (notice) {
    case CarCreateNotice.saved:
      return adminNewCarSavedVisible;
    case CarCreateNotice.noAnswer:
      return 'No answer from the server. The car may or may not be saved. '
          'Press "$adminCheckAgain": if it was saved, it is not created '
          'twice.';
    case CarCreateNotice.noConnection:
      return 'Not saved. No connection. Check your internet and try again.';
    case CarCreateNotice.refused:
      return 'Not saved. The server refused the car. Check that you are '
          'still signed in as the admin.';
    case CarCreateNotice.unknown:
      return 'Something went wrong. The car may or may not be saved. Press '
          '"$adminCheckAgain": if it was saved, it is not created twice.';
  }
}

/// What the list says after hiding or showing a car.
String adminCarActiveNoticeText(CarActiveNotice notice) {
  switch (notice) {
    case CarActiveNotice.hidden:
      return 'The car is hidden.';
    case CarActiveNotice.shown:
      return 'The car is visible.';
    case CarActiveNotice.noAnswer:
      return 'No answer from the server. The list shows the real state as '
          'soon as the server answers.';
    case CarActiveNotice.noConnection:
      return 'Not changed. No connection. Check your internet and try again.';
    case CarActiveNotice.refused:
      return 'Not changed. The server refused it.';
    case CarActiveNotice.carMissing:
      return 'Not changed. This car no longer exists.';
    case CarActiveNotice.unknown:
      return 'Not changed. Something went wrong. Try again.';
  }
}

/// "Year 2019".
String adminCarYear(int year) => 'Year $year';

/// "\$45 per day", "\$45.50 per day": the price as the catalog shows it.
String adminCarPrice(double pricePerDay) =>
    '\$${formatPrice(pricePerDay)} per day';

/// "ID: abcd1234…"; [shortId] is already shortened.
String adminCarIdText(String shortId) => 'ID: $shortId';

/// "7 cars: 6 visible, 1 hidden. 6 need repair." The part about repair is
/// left out when no car needs it; one car "needs repair". Unreadable
/// documents are counted as cars and named when there are any.
String adminFleetCounts(FleetCounts counts) {
  final total = counts.total;
  final parts = StringBuffer(
    '$total ${total == 1 ? 'car' : 'cars'}: '
    '${counts.visible} visible, ${counts.hidden} hidden',
  );
  if (counts.unreadable > 0) parts.write(', ${counts.unreadable} unreadable');
  parts.write('.');
  if (counts.needRepair == 1) {
    parts.write(' 1 needs repair.');
  } else if (counts.needRepair > 1) {
    parts.write(' ${counts.needRepair} need repair.');
  }
  return parts.toString();
}

/// The conflict warning before a write (step 5.3). Times only, never a
/// customer name.
const adminConflictTitle = 'Rentals of this car are too close';
const adminConflictPartlyTitle = 'Not every booking could be compared';
const adminConflictUncheckedTitle = 'Conflicts could not be checked';
const adminContinueAnyway = 'Continue anyway';
const adminConflictQuestion = 'Continue anyway?';
const adminConflictUncheckedText =
    'The other confirmed bookings of this car could not be read, so a '
    'conflict cannot be ruled out. Continue anyway?';

/// "These confirmed bookings of this car overlap this one or are less than
/// 5 hours apart:"
String adminConflictIntro() =>
    'These confirmed bookings of this car overlap this one or are less than '
    '${conflictBuffer.inHours} hours apart:';

/// "10 Dec 2026 10:00 – 12 Dec 2026 10:00" (Tbilisi time).
String adminConflictPeriod(ConflictPeriod period) =>
    '${formatAdminUtc(period.pickup)} – ${formatAdminUtc(period.dropoff)}';

/// "and 2 more".
String adminConflictMore(int more) => 'and $more more';

/// "1 booking of this car could not be read and was not compared." /
/// "3 bookings of this car could not be read and were not compared."
String adminConflictUnreadable(int count) => count == 1
    ? '1 booking of this car could not be read and was not compared.'
    : '$count bookings of this car could not be read and were not '
          'compared.';

/// The bookings ahead in the "Hide this car?" dialog (step 5.4). Times
/// only, never a customer name.
const adminHideAheadIntro =
    'This car has confirmed bookings that are not over yet:';
const adminHideUnchecked =
    'The confirmed bookings of this car could not be read, so bookings '
    'that are not over yet cannot be ruled out.';

/// "1 booking of this car could not be read and is not listed." /
/// "3 bookings of this car could not be read and are not listed."
String adminHideUnreadable(int count) => count == 1
    ? '1 booking of this car could not be read and is not listed.'
    : '$count bookings of this car could not be read and are not listed.';
