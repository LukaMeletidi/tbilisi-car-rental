/// The values the date and time pickers of the booking form start with, and
/// the first and last day they offer. Everything is Tbilisi time and is
/// worked out from a UTC moment, never from the time zone of the device.
///
/// A "day" is a [TbilisiDateTime] at 00:00.
library;

import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

/// How far ahead the pickup date picker goes. A limit of the picker only;
/// it is not a rule of the form and not in the Firestore rules.
const bookingPickupPickerYearsAhead = 2;

/// What a clock in Tbilisi shows at the UTC moment [utcNow].
TbilisiDateTime tbilisiNow(DateTime utcNow) => TbilisiDateTime.fromUtc(utcNow);

/// The current day in Tbilisi.
TbilisiDateTime tbilisiToday(DateTime utcNow) => _dayOf(tbilisiNow(utcNow));

/// The first day the pickup picker offers: today in Tbilisi.
TbilisiDateTime earliestPickupDay(DateTime utcNow) => tbilisiToday(utcNow);

/// The last day the pickup picker offers: the same date
/// [bookingPickupPickerYearsAhead] years later.
TbilisiDateTime latestPickupDay(DateTime utcNow) {
  final today = tbilisiToday(utcNow);
  // DateTime.utc turns 29 February of a later, shorter year into 1 March.
  final later = DateTime.utc(
    today.year + bookingPickupPickerYearsAhead,
    today.month,
    today.day,
  );
  return TbilisiDateTime(later.year, later.month, later.day);
}

/// The first day the dropoff picker offers: the day of [pickup], or today
/// when no pickup is chosen yet.
TbilisiDateTime earliestDropoffDay(DateTime utcNow, {TbilisiDateTime? pickup}) {
  return pickup == null ? tbilisiToday(utcNow) : _dayOf(pickup);
}

/// The last day the dropoff picker offers: [bookingMaxRentalDays] days after
/// the day of [pickup]. Without a pickup it is counted from the last
/// possible pickup day.
TbilisiDateTime latestDropoffDay(DateTime utcNow, {TbilisiDateTime? pickup}) {
  final from = pickup == null ? latestPickupDay(utcNow) : _dayOf(pickup);
  return _shift(from, const Duration(days: bookingMaxRentalDays));
}

/// Where the pickup pickers open when nothing is chosen yet: the next full
/// hour in Tbilisi. At 14:20 that is 15:00; at exactly 14:00 also 15:00;
/// at 23:30 it is 00:00 of the next day.
TbilisiDateTime defaultPickup(DateTime utcNow) {
  final now = tbilisiNow(utcNow);
  final thisHour = TbilisiDateTime(now.year, now.month, now.day, now.hour);
  return _shift(thisHour, const Duration(hours: 1));
}

/// Where the dropoff pickers open when nothing is chosen yet: one day after
/// [pickup] at the same time, or one day after [defaultPickup].
TbilisiDateTime defaultDropoff(DateTime utcNow, {TbilisiDateTime? pickup}) {
  return _shift(pickup ?? defaultPickup(utcNow), const Duration(days: 1));
}

TbilisiDateTime _dayOf(TbilisiDateTime value) =>
    TbilisiDateTime(value.year, value.month, value.day);

// The offset is fixed, so adding to the UTC moment moves the Tbilisi clock
// by exactly the same amount.
TbilisiDateTime _shift(TbilisiDateTime value, Duration amount) =>
    TbilisiDateTime.fromUtc(value.toUtc().add(amount));
