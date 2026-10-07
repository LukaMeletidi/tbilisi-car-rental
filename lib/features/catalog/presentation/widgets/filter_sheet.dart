import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_labels.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const FilterSheet(),
  );
}

/// The three filters. Every tap changes the list behind the sheet at once.
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(carFilterProvider);
    final notifier = ref.read(carFilterProvider.notifier);
    final matchCount = ref.watch(catalogCarsProvider).value?.cars.length ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.filters, style: textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: filter.activeCount == 0 ? null : notifier.reset,
                  child: Text(l10n.filterReset),
                ),
              ],
            ),
            _Section(
              title: l10n.filterSeats,
              chips: [
                for (final option in SeatsFilter.values)
                  ChoiceChip(
                    label: Text(seatsFilterLabel(l10n, option)),
                    selected: filter.seats == option,
                    onSelected: (_) => notifier.setSeats(option),
                  ),
              ],
            ),
            _Section(
              title: l10n.filterFuelType,
              chips: [
                ChoiceChip(
                  label: Text(l10n.filterAny),
                  selected: filter.fuelType == null,
                  onSelected: (_) => notifier.setFuelType(null),
                ),
                for (final option in FuelType.values)
                  ChoiceChip(
                    label: Text(fuelTypeLabel(l10n, option)),
                    selected: filter.fuelType == option,
                    onSelected: (_) => notifier.setFuelType(option),
                  ),
              ],
            ),
            _Section(
              title: l10n.filterTransmission,
              chips: [
                ChoiceChip(
                  label: Text(l10n.filterAny),
                  selected: filter.transmission == null,
                  onSelected: (_) => notifier.setTransmission(null),
                ),
                for (final option in Transmission.values)
                  ChoiceChip(
                    label: Text(transmissionLabel(l10n, option)),
                    selected: filter.transmission == option,
                    onSelected: (_) => notifier.setTransmission(option),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.showCars(matchCount)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}
