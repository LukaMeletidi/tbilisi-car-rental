import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_form.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The booking request for one car. The form appears when the car, the
/// extras prices and the places are loaded; nobody can book without them.
///
/// While a request is being sent, going back is blocked (the back arrow is
/// disabled and the system back button does nothing).
class BookingFormScreen extends ConsumerWidget {
  const BookingFormScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final car = ref.watch(carProvider(carId));
    final prices = ref.watch(extrasPricesProvider);
    final locations = ref.watch(pickupLocationsProvider);
    final sending = ref.watch(
      bookingFormProvider(carId).select((state) => state.isSending),
    );

    final all = <AsyncValue<Object>>[car, prices, locations];
    // Asked for again after "Try again", or not answered yet.
    final waiting = all.any(
      (value) => value.isLoading && (value.hasError || !value.hasValue),
    );
    final failed = [
      for (final value in all)
        if (value.hasError) value,
    ];

    final Widget body;
    if (!car.isLoading && car.error is CarNotAvailableException) {
      body = CatalogMessage(
        icon: Icons.directions_car,
        text: l10n.carNotAvailable,
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text(l10n.backToCars),
        ),
      );
    } else if (waiting) {
      body = const Center(child: CircularProgressIndicator());
    } else if (failed.isNotEmpty) {
      body = CatalogMessage(
        icon: Icons.cloud_off,
        text: l10n.bookingFormLoadError,
        // The technical reason, for the developer only.
        detail: kDebugMode ? '${failed.first.error}' : null,
        action: FilledButton(
          onPressed: () {
            if (car.hasError) ref.invalidate(carProvider(carId));
            if (prices.hasError) ref.invalidate(extrasPricesProvider);
            if (locations.hasError) ref.invalidate(pickupLocationsProvider);
          },
          child: Text(l10n.tryAgain),
        ),
      );
    } else {
      body = BookingForm(
        car: car.requireValue,
        extrasPrices: prices.requireValue,
        locations: locations.requireValue,
      );
    }

    return PopScope(
      canPop: !sending,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          leading: IconButton(
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: sending
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.car(carId)),
          ),
          title: const AppBarLogo(),
          actions: const [LanguageMenuButton()],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}
