import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_date_format.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// A date and time of the booking form, in Tbilisi time. It cannot be typed
/// in: a tap opens the pickers (see [pickTbilisiDateTime]).
///
/// The line "Tbilisi time (GMT+4)" under the field is always visible, also
/// when the field shows an error.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.errorText,
    required this.enabled,
    required this.onTap,
  });

  final String label;

  /// Null while nothing is chosen.
  final TbilisiDateTime? value;

  final String? errorText;

  /// False while the request is being sent.
  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = this.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: value == null,
              decoration: InputDecoration(
                labelText: label,
                errorText: errorText,
                errorMaxLines: 6,
                enabled: enabled,
                suffixIcon: const Icon(Icons.event),
              ),
              child: Text(
                value == null ? '' : formatTbilisiDateTime(value),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(l10n.tbilisiTimeLabel, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// Opens the date picker and then the time picker, and returns what the user
/// chose as a Tbilisi date and time. Returns null when either picker is
/// closed without a choice.
///
/// Everything is Tbilisi time. The pickers only get and give plain numbers
/// (year, month, day, hour, minute); the time zone of the device is never
/// used. [today] is the current day in Tbilisi, [firstDay] and [lastDay] are
/// the days the date picker offers, and [start] is where both pickers open.
/// The time picker uses the 24-hour clock in every language.
Future<TbilisiDateTime?> pickTbilisiDateTime(
  BuildContext context, {
  required TbilisiDateTime today,
  required TbilisiDateTime firstDay,
  required TbilisiDateTime lastDay,
  required TbilisiDateTime start,
}) async {
  // The date picker works with calendar days. Only the year, month and day
  // of these values are used, never a moment in time.
  DateTime day(TbilisiDateTime value) =>
      DateTime(value.year, value.month, value.day);

  final first = day(firstDay);
  final last = day(lastDay);
  var initial = day(start);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    currentDate: day(today),
    builder: (context, child) => OnWhite(child: child!),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
    builder: (context, child) => OnWhite(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    ),
  );
  if (time == null) return null;

  return TbilisiDateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
}
