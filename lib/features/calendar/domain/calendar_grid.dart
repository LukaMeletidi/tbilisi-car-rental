/// The calendar of the admin area (Section 3.4): which 14 days it shows,
/// which confirmed bookings it draws, where each one sits, and the rows.
/// Pure Dart; only UTC moments and Tbilisi dates, never the device time
/// zone. Nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';

/// How many days the calendar shows at once.
const calendarDayCount = 14;

/// How many days "Previous" and "Next" move the calendar.
const calendarStepDays = 7;

/// A date as a clock in Tbilisi shows it. The day starts at 00:00 Tbilisi
/// time and lasts exactly 24 hours: Tbilisi is always UTC+4, with no
/// daylight saving time.
class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay._(this.year, this.month, this.day);

  /// Throws an ArgumentError when it is not a real date.
  factory CalendarDay(int year, int month, int day) {
    final checked = TbilisiDateTime(year, month, day);
    return CalendarDay._(checked.year, checked.month, checked.day);
  }

  /// The Tbilisi date at the UTC moment [utc]: 19:59 UTC is still the same
  /// date, 20:00 UTC is 00:00 of the next one. Throws an ArgumentError when
  /// [utc] is not UTC.
  factory CalendarDay.ofUtc(DateTime utc) {
    final local = TbilisiDateTime.fromUtc(utc);
    return CalendarDay._(local.year, local.month, local.day);
  }

  final int year;
  final int month;
  final int day;

  /// The UTC moment at which this day starts: 00:00 Tbilisi time, which is
  /// 20:00 UTC of the day before.
  DateTime get startUtc => TbilisiDateTime(year, month, day).toUtc();

  /// 1 is Monday, 7 is Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// The day [days] later (earlier when negative), across months and years.
  CalendarDay plusDays(int days) {
    final moved = DateTime.utc(year, month, day + days);
    return CalendarDay._(moved.year, moved.month, moved.day);
  }

  @override
  int compareTo(CalendarDay other) => startUtc.compareTo(other.startUtc);

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// For test messages only, for example "2026-10-16".
  @override
  String toString() {
    String two(int value) => value.toString().padLeft(2, '0');
    return '$year-${two(month)}-${two(day)}';
  }
}

/// The [calendarDayCount] days the calendar shows, from [first].
class CalendarWindow {
  const CalendarWindow(this.first);

  /// The window that starts with today: the Tbilisi date at [nowUtc].
  factory CalendarWindow.startingToday(DateTime nowUtc) =>
      CalendarWindow(CalendarDay.ofUtc(nowUtc));

  final CalendarDay first;

  CalendarDay get last => first.plusDays(calendarDayCount - 1);

  List<CalendarDay> get days => [
    for (var i = 0; i < calendarDayCount; i++) first.plusDays(i),
  ];

  /// 00:00 Tbilisi time of [first].
  DateTime get startUtc => first.startUtc;

  /// 00:00 Tbilisi time of the day after [last]; not part of the window.
  DateTime get endUtc => first.plusDays(calendarDayCount).startUtc;

  CalendarWindow previous() =>
      CalendarWindow(first.plusDays(-calendarStepDays));

  CalendarWindow next() => CalendarWindow(first.plusDays(calendarStepDays));

  @override
  bool operator ==(Object other) =>
      other is CalendarWindow && other.first == first;

  @override
  int get hashCode => first.hashCode;
}

void _requireUtc(Booking booking) {
  if (!booking.pickup.isUtc || !booking.dropoff.isUtc) {
    throw ArgumentError('A booking time must be UTC.');
  }
}

/// Whether [booking] is in [window] for at least a minute: picked up before
/// the window ends and returned after it starts. A car returned at exactly
/// 00:00 of the first day, or picked up at exactly 00:00 after the last
/// day, is not in it. Throws an ArgumentError for a time that is not UTC.
bool bookingTouchesWindow(Booking booking, CalendarWindow window) {
  _requireUtc(booking);
  return booking.pickup.isBefore(window.endUtc) &&
      booking.dropoff.isAfter(window.startUtc);
}

/// One booking as the calendar draws it.
class CalendarBar {
  const CalendarBar({
    required this.booking,
    required this.start,
    required this.end,
    required this.firstDay,
    required this.lastDay,
    required this.startsBefore,
    required this.endsAfter,
    required this.tooClose,
  });

  final Booking booking;

  /// Where the bar begins and ends, in days after 00:00 of the first day of
  /// the window: 0.0 is that moment, 1.5 is 12:00 of the second day, 14.0
  /// is the end of the last day. Cut to 0.0 … 14.0.
  final double start;
  final double end;

  /// The first and the last day cell (0 … 13) the bar lies in. A return at
  /// exactly 00:00 does not reach into that day.
  final int firstDay;
  final int lastDay;

  /// Picked up before the window starts: the bar is cut on the left.
  final bool startsBefore;

  /// Returned after the window ends: the bar is cut on the right.
  final bool endsAfter;

  /// Another confirmed booking of the same car is less than conflictBuffer
  /// away: a conflict someone chose to allow. Checked against every
  /// confirmed booking of the car, also those outside the window.
  final bool tooClose;
}

double _daysAfter(DateTime start, DateTime moment) =>
    moment.difference(start).inMinutes / Duration.minutesPerDay;

/// The bar of [booking] in [window]. Throws an ArgumentError for a booking
/// that is not in the window (see [bookingTouchesWindow]).
CalendarBar placeBooking(
  Booking booking,
  CalendarWindow window, {
  required bool tooClose,
}) {
  if (!bookingTouchesWindow(booking, window)) {
    throw ArgumentError('The booking is not in the window.');
  }
  const last = calendarDayCount - 1;
  const width = calendarDayCount * 1.0;
  final double start = _daysAfter(
    window.startUtc,
    booking.pickup,
  ).clamp(0.0, width);
  final double end = _daysAfter(
    window.startUtc,
    booking.dropoff,
  ).clamp(0.0, width);
  return CalendarBar(
    booking: booking,
    start: start,
    end: end,
    firstDay: start.floor().clamp(0, last),
    lastDay: (end.ceil() - 1).clamp(0, last),
    startsBefore: booking.pickup.isBefore(window.startUtc),
    endsAfter: booking.dropoff.isAfter(window.endUtc),
    tooClose: tooClose,
  );
}

int _compareBars(CalendarBar a, CalendarBar b) {
  final byPickup = a.booking.pickup.compareTo(b.booking.pickup);
  if (byPickup != 0) return byPickup;
  return (a.booking.id ?? '').compareTo(b.booking.id ?? '');
}

/// Puts the bars of one car into lanes, top to bottom, so that no two bars
/// of one lane share a day cell. Sorted by pickup (then booking ID), each
/// bar goes into the first lane whose last bar ends on an earlier day;
/// otherwise a new lane is added. A return at 10:00 and the next pickup at
/// 18:00 of the same day therefore lie in two lanes: neither hides the
/// other, also when they are too close or overlap.
List<List<CalendarBar>> calendarLanes(List<CalendarBar> bars) {
  final sorted = [...bars]..sort(_compareBars);
  final lanes = <List<CalendarBar>>[];
  for (final bar in sorted) {
    final lane = lanes
        .where((lane) => lane.last.lastDay < bar.firstDay)
        .firstOrNull;
    if (lane == null) {
      lanes.add([bar]);
    } else {
      lane.add(bar);
    }
  }
  return List.unmodifiable([
    for (final lane in lanes) List<CalendarBar>.unmodifiable(lane),
  ]);
}

/// One row of the calendar: a car and its bars.
class CalendarRow {
  const CalendarRow({
    required this.carId,
    required this.car,
    required this.lanes,
  });

  final String carId;

  /// Null when no readable car has [carId] (removed in the console, or a
  /// document the app cannot read). The row then says "Unknown car".
  final Car? car;

  /// At least one lane; a single empty lane for a car without bookings.
  final List<List<CalendarBar>> lanes;

  bool get hidden => car != null && !car!.active;

  /// Whether the row has at least one bar.
  bool get hasBars => lanes.first.isNotEmpty;
}

/// The order of the Cars list: brand, then model (both ignoring case), then
/// year, then ID.
int _compareCars(Car a, Car b) {
  for (final result in [
    a.brand.toLowerCase().compareTo(b.brand.toLowerCase()),
    a.model.toLowerCase().compareTo(b.model.toLowerCase()),
    a.year.compareTo(b.year),
  ]) {
    if (result != 0) return result;
  }
  return a.id.compareTo(b.id);
}

/// The rows of [window], in this order:
/// 1. every visible car, also one without a booking;
/// 2. every hidden car with at least one booking in the window (marked);
/// 3. every car ID of a booking in the window that has no readable car,
///    by ID.
/// Groups 1 and 2 are each in the order of the Cars list. Only bookings with
/// status confirmed count; any other is ignored. Throws an ArgumentError for
/// a booking time that is not UTC.
List<CalendarRow> calendarRows({
  required List<Car> cars,
  required List<Booking> bookings,
  required CalendarWindow window,
}) {
  final byCar = <String, List<Booking>>{};
  for (final booking in bookings) {
    if (booking.status != BookingStatus.confirmed) continue;
    byCar.putIfAbsent(booking.carId, () => []).add(booking);
  }

  List<List<CalendarBar>> lanesOf(String carId) {
    final all = byCar[carId] ?? const <Booking>[];
    final bars = [
      for (final booking in all)
        if (bookingTouchesWindow(booking, window))
          placeBooking(
            booking,
            window,
            tooClose: all.any(
              (other) =>
                  other.id != booking.id && bookingsConflict(booking, other),
            ),
          ),
    ];
    final lanes = calendarLanes(bars);
    return lanes.isEmpty ? const [<CalendarBar>[]] : lanes;
  }

  final sorted = [...cars]..sort(_compareCars);
  final rows = <CalendarRow>[
    for (final car in sorted)
      if (car.active)
        CalendarRow(carId: car.id, car: car, lanes: lanesOf(car.id)),
  ];
  for (final car in sorted.where((car) => !car.active)) {
    final row = CalendarRow(carId: car.id, car: car, lanes: lanesOf(car.id));
    if (row.hasBars) rows.add(row);
  }
  final known = {for (final car in cars) car.id};
  final unknown = byCar.keys.where((id) => !known.contains(id)).toList()
    ..sort();
  for (final carId in unknown) {
    final row = CalendarRow(carId: carId, car: null, lanes: lanesOf(carId));
    if (row.hasBars) rows.add(row);
  }
  return List.unmodifiable(rows);
}

/// Whether any row has a bar: false means "no confirmed bookings in these
/// days".
bool calendarHasBars(List<CalendarRow> rows) => rows.any((row) => row.hasBars);

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The short weekday of [day], for example "Fri".
String calendarWeekdayText(CalendarDay day) => _weekdayShort[day.weekday - 1];

/// Whether the header cell [index] (0 … 13) of [window] also names the
/// month: the first cell, and every cell that is the 1st of a month.
bool calendarCellShowsMonth(CalendarWindow window, int index) =>
    index == 0 || window.first.plusDays(index).day == 1;

/// The date line of a header cell: "16", or "1 Nov" when the cell names
/// the month (see [calendarCellShowsMonth]).
String calendarDateText(CalendarWindow window, int index) {
  final day = window.first.plusDays(index);
  return calendarCellShowsMonth(window, index)
      ? '${day.day} ${adminMonthNames[day.month - 1]}'
      : '${day.day}';
}

/// The full date with the weekday, for a screen reader: "Friday 16 Oct
/// 2026".
String calendarFullDateText(CalendarDay day) =>
    '${_weekdayLong[day.weekday - 1]} ${day.day} '
    '${adminMonthNames[day.month - 1]} ${day.year}';

/// The days of [window] as one line: "16 Oct – 29 Oct 2026", or
/// "28 Dec 2026 – 10 Jan 2027" across a year end.
String calendarRangeText(CalendarWindow window) {
  final first = window.first;
  final last = window.last;
  String dayMonth(CalendarDay day) =>
      '${day.day} ${adminMonthNames[day.month - 1]}';
  return first.year == last.year
      ? '${dayMonth(first)} – ${dayMonth(last)} ${last.year}'
      : '${dayMonth(first)} ${first.year} – ${dayMonth(last)} ${last.year}';
}
