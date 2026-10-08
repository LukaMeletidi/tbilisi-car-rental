import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_labels.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The specs of a car as small labels: seats, transmission, fuel type,
/// drivetrain and, unless hidden, engine size.
class CarSpecChips extends StatelessWidget {
  const CarSpecChips({super.key, required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engineSize = car.visibleEngineSize;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SpecChip(l10n.seatsCount(car.seats)),
        _SpecChip(transmissionLabel(l10n, car.transmission)),
        _SpecChip(fuelTypeLabel(l10n, car.fuelType)),
        _SpecChip(drivetrainLabel(car.drivetrain)),
        if (engineSize != null) _SpecChip(formatEngineSize(engineSize)),
      ],
    );
  }
}

/// A small non-clickable label for one spec, such as "5 seats" or "FWD".
class _SpecChip extends StatelessWidget {
  const _SpecChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
