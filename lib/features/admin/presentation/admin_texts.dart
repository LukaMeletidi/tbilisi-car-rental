/// The texts of the admin area. The admin area is English only, so they are
/// plain constants here and not in the translation files.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
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
String adminStatusNoticeText(AdminStatusChangeNotice notice) {
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
    case AdminStatusChangeNotice.unknown:
      return 'Not saved. Please try again.';
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
