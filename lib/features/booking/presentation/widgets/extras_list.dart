import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The extras as checkboxes: the name, the age a seat is meant for, and the
/// price per day from settings.
class ExtrasList extends StatelessWidget {
  const ExtrasList({
    super.key,
    required this.prices,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ExtrasPrices prices;
  final Set<Extra> selected;

  /// False while the request is being sent.
  final bool enabled;

  final void Function(Extra extra, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final extra in Extra.values)
          CheckboxListTile(
            value: selected.contains(extra),
            onChanged: enabled ? (value) => onChanged(extra, value!) : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(extraName(l10n, extra)),
            subtitle: switch (extraAgeText(l10n, extra)) {
              final age? => Text(age),
              null => null,
            },
            secondary: Text(
              extraPriceText(l10n, prices.priceOf(extra)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
