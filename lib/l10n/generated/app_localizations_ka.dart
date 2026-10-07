// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class AppLocalizationsKa extends AppLocalizations {
  AppLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get appTitle => 'Tbilisi Car Rental';

  @override
  String get languageLabel => 'ენა';

  @override
  String get catalogEmpty => 'ავტომობილები ჯერ არ არის';

  @override
  String get catalogError =>
      'ავტომობილების ჩატვირთვა ვერ მოხერხდა. სცადეთ მოგვიანებით.';

  @override
  String get tryAgain => 'სცადეთ ხელახლა';

  @override
  String get noPhoto => 'ფოტო არ არის';

  @override
  String pricePerDay(String price) {
    return '\$$price / დღე';
  }

  @override
  String seatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ადგილი',
    );
    return '$_temp0';
  }

  @override
  String get transmissionAutomatic => 'ავტომატიკა';

  @override
  String get transmissionManual => 'მექანიკა';

  @override
  String get fuelPetrol => 'ბენზინი';

  @override
  String get fuelDiesel => 'დიზელი';

  @override
  String get fuelHybrid => 'ჰიბრიდი';

  @override
  String get fuelElectric => 'ელექტრო';
}
