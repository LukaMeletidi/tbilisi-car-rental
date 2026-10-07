import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

String transmissionLabel(AppLocalizations l10n, Transmission transmission) =>
    switch (transmission) {
      Transmission.automatic => l10n.transmissionAutomatic,
      Transmission.manual => l10n.transmissionManual,
    };

String fuelTypeLabel(AppLocalizations l10n, FuelType fuelType) =>
    switch (fuelType) {
      FuelType.petrol => l10n.fuelPetrol,
      FuelType.diesel => l10n.fuelDiesel,
      FuelType.hybrid => l10n.fuelHybrid,
      FuelType.electric => l10n.fuelElectric,
    };

/// The numbers are the same in every language; only "Any" is translated.
String seatsFilterLabel(AppLocalizations l10n, SeatsFilter seats) =>
    switch (seats) {
      SeatsFilter.any => l10n.filterAny,
      SeatsFilter.two => '2',
      SeatsFilter.four => '4',
      SeatsFilter.five => '5',
      SeatsFilter.sevenPlus => '7+',
    };
