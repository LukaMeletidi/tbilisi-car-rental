import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A Tbilisi date and time for the admin area, in English and with the
/// month as a word so that day and month cannot be mixed up:
/// "10 Jan 2026 18:00", "9 Oct 2026 07:05" (24-hour clock).
///
/// The text is built from the five numbers of [value]; nothing is
/// converted here.
String formatAdminDateTime(TbilisiDateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.day} ${_months[value.month - 1]} ${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

/// The stored UTC moment [utc] as a Tbilisi date and time for the admin
/// area. The conversion is the project's one helper,
/// [TbilisiDateTime.fromUtc]; the time zone of the device is never used.
String formatAdminUtc(DateTime utc) =>
    formatAdminDateTime(TbilisiDateTime.fromUtc(utc));
