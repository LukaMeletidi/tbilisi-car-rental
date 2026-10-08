import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';

/// A Tbilisi date and time as the booking form shows it: "10.01.2026 18:00"
/// (day.month.year hours:minutes, 24-hour clock). The same in every
/// language.
///
/// The text is built from the five numbers of [value]. Nothing is converted,
/// so the time zone of the device plays no part.
String formatTbilisiDateTime(TbilisiDateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final year = value.year.toString().padLeft(4, '0');
  return '${two(value.day)}.${two(value.month)}.$year '
      '${two(value.hour)}:${two(value.minute)}';
}
