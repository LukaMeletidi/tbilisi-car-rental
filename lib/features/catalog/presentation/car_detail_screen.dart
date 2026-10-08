import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo_gallery.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_spec_chips.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// One car: all photos, the specs, the full description, and the booking
/// button.
class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final car = ref.watch(carProvider(carId));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        title: const AppBarLogo(),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: car.when(
          // Show the spinner again after "Try again" is pressed.
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => error is CarNotAvailableException
              ? CatalogMessage(
                  icon: Icons.directions_car,
                  text: l10n.carNotAvailable,
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.backToCars),
                  ),
                )
              : CatalogMessage(
                  icon: Icons.cloud_off,
                  text: l10n.carError,
                  // The technical reason, for the developer only.
                  detail: kDebugMode ? '$error' : null,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(carProvider(carId)),
                    child: Text(l10n.tryAgain),
                  ),
                ),
          data: (car) => _CarDetail(car: car),
        ),
      ),
      // Only when the car is shown; not while loading or in an error state.
      bottomNavigationBar: car is AsyncData<Car>
          ? _BookingBar(carId: carId)
          : null,
    );
  }
}

class _CarDetail extends StatelessWidget {
  const _CarDetail({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: _CarDetailBody(car: car),
          ),
        ),
      ),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _CarDetailBody extends ConsumerWidget {
  const _CarDetailBody({required this.car});

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
        CarPhotoGallery(photos: car.photos),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(carTitle(car), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.pricePerDay(formatPrice(car.pricePerDay)),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              CarSpecChips(car: car),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(l10n.descriptionTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(description),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The booking button, fixed at the bottom of the screen on the purple page.
/// It opens the booking form of the car.
class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.booking(carId)),
                child: Text(l10n.makeBooking),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
