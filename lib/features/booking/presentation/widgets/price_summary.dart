import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The rental days and the total, updated while the form is filled in.
/// For a rental longer than 7 days the total is an estimate and a note says
/// that the price is individual.
class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.price});

  /// Null while there are no two valid dates to calculate from.
  final RentalPrice? price;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = this.price;

    if (price == null) return Text(l10n.bookingChooseDates);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          label: l10n.bookingRentalDays,
          value: '${price.days}',
          valueStyle: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          label: price.isIndividualPrice
              ? l10n.bookingEstimatedTotal
              : l10n.bookingTotal,
          value: l10n.priceAmount(formatPrice(price.total)),
          valueStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (price.isIndividualPrice) ...[
          const SizedBox(height: 12),
          Text(individualPriceNote(l10n)),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: valueStyle),
      ],
    );
  }
}
