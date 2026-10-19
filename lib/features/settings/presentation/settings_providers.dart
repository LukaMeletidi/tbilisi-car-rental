import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

/// Live prices of the extras. In the error state there are no prices at all;
/// a screen must not calculate a total then.
///
/// Auto-dispose and no automatic retry, as for the cars.
final extrasPricesProvider = StreamProvider.autoDispose<ExtrasPrices>(
  (ref) => ref.watch(settingsRepositoryProvider).watchExtrasPrices(),
  retry: (retryCount, error) => null,
);

/// Live list of the fixed pickup and drop-off places.
final pickupLocationsProvider =
    StreamProvider.autoDispose<List<PickupLocation>>(
      (ref) => ref.watch(settingsRepositoryProvider).watchPickupLocations(),
      retry: (retryCount, error) => null,
    );

/// The company information, live; null when it is not filled in yet.
/// Auto-dispose and no automatic retry, as the other settings.
final companyInfoProvider = StreamProvider.autoDispose<CompanyInfo?>(
  (ref) => ref.watch(settingsRepositoryProvider).watchCompany(),
  retry: (retryCount, error) => null,
);
