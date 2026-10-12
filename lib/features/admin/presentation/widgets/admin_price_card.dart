import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The total of the edit form: the stored total, the new total at today's
/// prices, and the choice between them. It is the content of a white card.
///
/// The choice is shown only when it is needed (the car, a date or the
/// extras changed and the new total is not the stored one). Nothing is
/// ever selected for the admin: [choice] is null until they tap one.
class AdminPriceCard extends StatelessWidget {
  const AdminPriceCard({
    super.key,
    required this.totals,
    required this.choice,
    required this.enabled,
    required this.onChoose,
  });

  final AdminTotalComparison totals;

  /// Null while the admin has not chosen.
  final AdminTotalChoice? choice;

  /// False while a save is running.
  final bool enabled;

  final ValueChanged<AdminTotalChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final newPrice = totals.newPrice;
    final carPerDay = totals.carPricePerDay;
    final extrasPerDay = totals.extrasPerDay;
    final storedTotal = totals.storedCents / 100;
    // Whether the prices of the car and the extras are known at all.
    final pricesLoaded = carPerDay != null && extrasPerDay != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          adminStoredTotal(totals.storedDays, storedTotal),
          style: textTheme.bodyLarge,
        ),
        if (!totals.priceFieldsChanged) ...[
          const SizedBox(height: 4),
          Text(adminTotalStays, style: textTheme.bodySmall),
        ] else ...[
          const SizedBox(height: 8),
          if (newPrice != null && pricesLoaded) ...[
            Text(
              adminNewTotal(
                days: newPrice.days,
                carPerDay: carPerDay,
                extrasPerDay: extrasPerDay,
                total: newPrice.total,
                estimate: newPrice.isIndividualPrice,
              ),
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 2),
            Text(adminNewTotalUsesTodaysPrices, style: textTheme.bodySmall),
          ] else
            Text(
              pricesLoaded ? adminNewTotalNoDates : adminNewTotalNoPrices,
              style: textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          if (!totals.choiceNeeded)
            // The new total is the stored one.
            Text(adminTotalStays, style: textTheme.bodySmall)
          else ...[
            _Choice(
              label: adminKeepStoredTotal(storedTotal),
              selected: choice == AdminTotalChoice.keepStored,
              onTap: enabled
                  ? () => onChoose(AdminTotalChoice.keepStored)
                  : null,
            ),
            // Without a new total only "keep" is offered.
            if (newPrice != null)
              _Choice(
                label: adminUseNewTotal(newPrice.total),
                selected: choice == AdminTotalChoice.useNew,
                // Above the highest total the rules accept: not possible.
                onTap: enabled && totals.canUseNew
                    ? () => onChoose(AdminTotalChoice.useNew)
                    : null,
              ),
            if (newPrice != null && !totals.canUseNew)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 4),
                child: Text(
                  adminBookingErrorText(AdminBookingError.totalTooHigh),
                  style: textTheme.bodySmall,
                ),
              ),
            if (choice == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  adminBookingErrorText(AdminBookingError.totalChoiceRequired),
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

/// One of the two choices: a radio mark and its text. Disabled when
/// [onTap] is null.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? theme.disabledColor
        : selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: color,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: onTap == null ? theme.disabledColor : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
