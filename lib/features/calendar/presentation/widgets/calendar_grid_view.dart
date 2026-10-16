import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// The narrowest a day column gets; below that the days scroll sideways.
const calendarMinDayWidth = 44.0;

/// The width of the car column from 600 px of grid width, and below.
const calendarCarColumnWide = 160.0;
const calendarCarColumnNarrow = 120.0;

/// The height of the day header.
const calendarHeaderHeight = 48.0;

/// The height of one lane of bars, and the space above and below them.
const calendarLaneHeight = 32.0;
const calendarRowPadding = 4.0;

/// The narrowest a bar is drawn, so that it can be tapped.
const calendarMinBarWidth = 16.0;

/// The height of a row with [lanes] lanes: 40 px for one lane. The car
/// column and the days use this one function, so the rows line up.
double calendarRowHeight(int lanes) =>
    2 * calendarRowPadding + math.max(1, lanes) * calendarLaneHeight;

/// The key of the bar of the booking [bookingId], for tests.
Key calendarBarKey(String bookingId) => ValueKey('calendar-bar-$bookingId');

/// The key of the name cell of the car [carId], for tests.
Key calendarCarKey(String carId) => ValueKey('calendar-car-$carId');

/// The key of the header cell [index] (0 … 13), for tests.
Key calendarDayKey(int index) => ValueKey('calendar-day-$index');

/// The key of the sideways scroll view of the days, for tests.
const calendarDaysScrollKey = ValueKey('calendar-days-scroll');

/// The grid of the calendar on a white card: a fixed column of car names on
/// the left and the 14 days on the right, which scroll sideways when they
/// do not fit. Shows only times; never a name or another detail of the
/// customer.
class CalendarGridView extends StatefulWidget {
  const CalendarGridView({
    super.key,
    required this.window,
    required this.rows,
    required this.today,
    required this.onOpenBooking,
  });

  final CalendarWindow window;
  final List<CalendarRow> rows;

  /// Today in Tbilisi; highlighted when it is shown.
  final CalendarDay today;

  /// Called with the ID of a booking that was tapped.
  final void Function(String bookingId) onOpenBooking;

  @override
  State<CalendarGridView> createState() => _CalendarGridViewState();
}

class _CalendarGridViewState extends State<CalendarGridView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.window.days;
    final todayIndex = days.indexOf(widget.today);
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final carColumn = constraints.maxWidth >= 600
              ? calendarCarColumnWide
              : calendarCarColumnNarrow;
          final dayWidth = math.max(
            calendarMinDayWidth,
            (constraints.maxWidth - carColumn) / calendarDayCount,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: carColumn,
                child: Column(
                  children: [
                    _CarHeaderCell(),
                    for (final row in widget.rows) _CarNameCell(row: row),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    key: calendarDaysScrollKey,
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: dayWidth * calendarDayCount,
                      child: Column(
                        children: [
                          _DayHeader(
                            window: widget.window,
                            dayWidth: dayWidth,
                            todayIndex: todayIndex,
                          ),
                          for (final row in widget.rows)
                            _DaysRow(
                              row: row,
                              dayWidth: dayWidth,
                              todayIndex: todayIndex,
                              onOpenBooking: widget.onOpenBooking,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _lineColor = Colors.black12;
final _todayTint = appBackgroundColor.withValues(alpha: 0.10);

class _CarHeaderCell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: calendarHeaderHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black26),
          right: BorderSide(color: Colors.black26),
        ),
      ),
      child: Text(
        adminCalendarCarColumn,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _CarNameCell extends StatelessWidget {
  const _CarNameCell({required this.row});

  final CalendarRow row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final car = row.car;
    final title = car == null ? adminCalendarUnknownCar : carTitle(car);
    final String? second;
    if (car == null) {
      second = shortCarId(row.carId);
    } else if (row.hidden) {
      second = adminCalendarHiddenCar;
    } else {
      second = null;
    }
    return Container(
      key: calendarCarKey(row.carId),
      height: calendarRowHeight(row.lanes.length),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _lineColor),
          right: BorderSide(color: Colors.black26),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (second != null)
            Text(
              second,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.window,
    required this.dayWidth,
    required this.todayIndex,
  });

  final CalendarWindow window;
  final double dayWidth;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = window.days;
    return SizedBox(
      height: calendarHeaderHeight,
      child: Row(
        children: [
          for (var i = 0; i < calendarDayCount; i++)
            Semantics(
              key: calendarDayKey(i),
              label: adminCalendarDayLabel(
                calendarFullDateText(days[i]),
                today: i == todayIndex,
              ),
              selected: i == todayIndex,
              excludeSemantics: true,
              child: Container(
                width: dayWidth,
                height: calendarHeaderHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == todayIndex ? appBackgroundColor : null,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black26),
                    right: BorderSide(color: _lineColor),
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: i == todayIndex ? Colors.white : null,
                    fontWeight: i == todayIndex ? FontWeight.w700 : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        calendarWeekdayText(days[i]),
                        style: textTheme.labelSmall?.copyWith(
                          color: i == todayIndex ? Colors.white : null,
                        ),
                      ),
                      Text(
                        calendarDateText(window, i),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: textTheme.bodySmall?.copyWith(
                          color: i == todayIndex ? Colors.white : null,
                          fontWeight: i == todayIndex ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaysRow extends StatelessWidget {
  const _DaysRow({
    required this.row,
    required this.dayWidth,
    required this.todayIndex,
    required this.onOpenBooking,
  });

  final CalendarRow row;
  final double dayWidth;
  final int todayIndex;
  final void Function(String bookingId) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final total = dayWidth * calendarDayCount;
    return SizedBox(
      height: calendarRowHeight(row.lanes.length),
      child: Stack(
        children: [
          // The day cells: a line between the days, today tinted.
          Row(
            children: [
              for (var i = 0; i < calendarDayCount; i++)
                Container(
                  width: dayWidth,
                  decoration: BoxDecoration(
                    color: i == todayIndex ? _todayTint : null,
                    border: const Border(
                      right: BorderSide(color: _lineColor),
                      bottom: BorderSide(color: _lineColor),
                    ),
                  ),
                ),
            ],
          ),
          for (var lane = 0; lane < row.lanes.length; lane++)
            for (final bar in row.lanes[lane])
              _placed(bar, lane: lane, total: total),
        ],
      ),
    );
  }

  Widget _placed(CalendarBar bar, {required int lane, required double total}) {
    final width = math.max(
      calendarMinBarWidth,
      (bar.end - bar.start) * dayWidth,
    );
    final left = math.min(bar.start * dayWidth, total - width);
    return Positioned(
      left: left,
      width: width,
      top: calendarRowPadding + lane * calendarLaneHeight + 2,
      height: calendarLaneHeight - 4,
      child: _Bar(bar: bar, onOpenBooking: onOpenBooking),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.onOpenBooking});

  final CalendarBar bar;
  final void Function(String bookingId) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final booking = bar.booking;
    final label = adminCalendarBarLabel(
      booking.pickup,
      booking.dropoff,
      tooClose: bar.tooClose,
    );
    final pickup = TbilisiDateTime.fromUtc(booking.pickup);
    String two(int value) => value.toString().padLeft(2, '0');
    const white = Colors.white;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          key: calendarBarKey(booking.id ?? ''),
          color: appBackgroundColor,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(bar.startsBefore ? 0 : 6),
            right: Radius.circular(bar.endsAfter ? 0 : 6),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: booking.id == null ? null : () => onOpenBooking(booking.id!),
            child: Stack(
              children: [
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (bar.startsBefore)
                            const Icon(
                              Icons.chevron_left,
                              size: 16,
                              color: white,
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                '${two(pickup.hour)}:${two(pickup.minute)}',
                                style: const TextStyle(
                                  color: white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (bar.tooClose)
                            const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(
                                Icons.warning_amber,
                                size: 16,
                                color: white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (bar.endsAfter)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right, size: 16, color: white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
