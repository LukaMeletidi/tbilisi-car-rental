import 'package:tbilisi_car_rental/core/models/car.dart';
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
