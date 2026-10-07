import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/filter_sheet.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The button above the list. Shows how many filters are set and opens the
/// filter sheet.
class FiltersButton extends ConsumerWidget {
  const FiltersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activeCount = ref.watch(
      carFilterProvider.select((filter) => filter.activeCount),
    );

    return OutlinedButton.icon(
      onPressed: () => showFilterSheet(context),
      icon: const Icon(Icons.tune),
      label: Text(
        activeCount == 0 ? l10n.filters : l10n.filtersWithCount(activeCount),
      ),
    );
  }
}
