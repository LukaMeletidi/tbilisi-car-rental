// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tbilisi Car Rental';

  @override
  String get languageLabel => 'Language';

  @override
  String get catalogEmpty => 'No cars available yet';

  @override
  String get catalogError => 'Could not load the cars. Please try again later.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noPhoto => 'No photo';

  @override
  String pricePerDay(String price) {
    return '\$$price / day';
  }

  @override
  String seatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get transmissionAutomatic => 'Automatic';

  @override
  String get transmissionManual => 'Manual';

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelElectric => 'Electric';

  @override
  String get filters => 'Filters';

  @override
  String filtersWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get filterSeats => 'Seats';

  @override
  String get filterFuelType => 'Fuel type';

  @override
  String get filterTransmission => 'Transmission';

  @override
  String get filterAny => 'Any';

  @override
  String get filterReset => 'Reset';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get catalogNoMatch => 'No cars match your filters';

  @override
  String showCars(int count) {
    return 'Show cars ($count)';
  }
}
