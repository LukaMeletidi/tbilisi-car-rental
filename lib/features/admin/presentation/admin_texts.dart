/// The texts of the admin area. The admin area is English only, so they are
/// plain constants here and not in the translation files.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';

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
const adminTryAgain = 'Try again';
const adminOfflineNote = 'Offline: showing saved data';
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
