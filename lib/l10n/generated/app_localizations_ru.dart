// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Tbilisi Car Rental';

  @override
  String get languageLabel => 'Язык';

  @override
  String get catalogEmpty => 'Пока нет доступных автомобилей';

  @override
  String get catalogError =>
      'Не удалось загрузить автомобили. Повторите попытку позже.';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get noPhoto => 'Нет фото';

  @override
  String pricePerDay(String price) {
    return '\$$price / день';
  }

  @override
  String seatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count места',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0';
  }

  @override
  String get transmissionAutomatic => 'Автомат';

  @override
  String get transmissionManual => 'Механика';

  @override
  String get fuelPetrol => 'Бензин';

  @override
  String get fuelDiesel => 'Дизель';

  @override
  String get fuelHybrid => 'Гибрид';

  @override
  String get fuelElectric => 'Электро';

  @override
  String get filters => 'Фильтры';

  @override
  String filtersWithCount(int count) {
    return 'Фильтры ($count)';
  }

  @override
  String get filterSeats => 'Места';

  @override
  String get filterFuelType => 'Тип топлива';

  @override
  String get filterTransmission => 'Коробка передач';

  @override
  String get filterAny => 'Любой';

  @override
  String get filterReset => 'Сбросить';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String get catalogNoMatch => 'Нет автомобилей, подходящих под фильтры';

  @override
  String showCars(int count) {
    return 'Показать ($count)';
  }
}
