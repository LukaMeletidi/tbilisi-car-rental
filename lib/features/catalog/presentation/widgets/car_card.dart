import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_spec_chips.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// One car as a large white card.
class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car, this.onTap});

  final Car car;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: _CarCardBody(car: car),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _CarCardBody extends ConsumerWidget {
  const _CarCardBody({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final description = car.description.forLanguage(
      ref.watch(appLanguageProvider),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CarPhoto(photos: car.photos),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(carTitle(car), style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              CarSpecChips(car: car),
              const SizedBox(height: 12),
              Text(
                l10n.pricePerDay(formatPrice(car.pricePerDay)),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
