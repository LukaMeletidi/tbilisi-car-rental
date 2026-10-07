/// Tbilisi is always 4 hours ahead of UTC. Georgia has no daylight saving
/// time, so the offset is the same all year.
const tbilisiUtcOffset = Duration(hours: 4);

/// A date and time as a clock in Tbilisi shows it, in whole minutes.
///
/// This is what the screens show and what the date and time pickers return.
/// It is deliberately not a [DateTime], so it cannot be mistaken for a real
/// moment in time. Stored values are always UTC: use [TbilisiDateTime.fromUtc]
/// to show a stored moment and [toUtc] to store what the user picked.
///
/// Nothing here depends on the time zone of the device.
class TbilisiDateTime implements Comparable<TbilisiDateTime> {
  const TbilisiDateTime._(
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
  );

  /// A Tbilisi date and time as picked by the user. Throws an
  /// [ArgumentError] when it is not a real date or time, such as 30 February
  /// or 24:00.
  factory TbilisiDateTime(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
  ]) {
    // DateTime.utc silently turns 30 February into 2 March. If the fields
    // come back changed, the input was not a real date and time.
    final check = DateTime.utc(year, month, day, hour, minute);
    if (check.year != year ||
        check.month != month ||
        check.day != day ||
        check.hour != hour ||
        check.minute != minute) {
      throw ArgumentError(
        'Not a valid date and time: $year-$month-$day $hour:$minute',
      );
    }
    return TbilisiDateTime._(year, month, day, hour, minute);
  }

  /// What a clock in Tbilisi shows at the UTC moment [utc]. Seconds are
  /// dropped. Throws an [ArgumentError] when [utc] is not a UTC date.
  factory TbilisiDateTime.fromUtc(DateTime utc) {
    if (!utc.isUtc) {
      throw ArgumentError.value(utc, 'utc', 'must be a UTC date');
    }
    final shifted = utc.add(tbilisiUtcOffset);
    return TbilisiDateTime._(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
    );
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// The UTC moment at which a clock in Tbilisi shows this date and time.
  /// This is the value to store.
  DateTime toUtc() =>
      DateTime.utc(year, month, day, hour, minute).subtract(tbilisiUtcOffset);

  @override
  int compareTo(TbilisiDateTime other) => toUtc().compareTo(other.toUtc());

  @override
  bool operator ==(Object other) =>
      other is TbilisiDateTime &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute);

  /// For logs and test messages only, for example "2026-01-11 01:30 (Tbilisi)".
  /// Screens format dates in the user's language instead.
  @override
  String toString() {
    String two(int value) => value.toString().padLeft(2, '0');
    return '$year-${two(month)}-${two(day)} ${two(hour)}:${two(minute)} '
        '(Tbilisi)';
  }
}
