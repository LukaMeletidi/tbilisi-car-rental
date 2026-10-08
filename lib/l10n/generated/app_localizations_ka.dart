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

  @override
  String get filters => 'ფილტრები';

  @override
  String filtersWithCount(int count) {
    return 'ფილტრები ($count)';
  }

  @override
  String get filterSeats => 'ადგილები';

  @override
  String get filterFuelType => 'საწვავის ტიპი';

  @override
  String get filterTransmission => 'გადაცემათა კოლოფი';

  @override
  String get filterAny => 'ნებისმიერი';

  @override
  String get filterReset => 'გასუფთავება';

  @override
  String get resetFilters => 'ფილტრების გასუფთავება';

  @override
  String get catalogNoMatch => 'ფილტრებს არცერთი ავტომობილი არ შეესაბამება';

  @override
  String showCars(int count) {
    return 'ჩვენება ($count)';
  }

  @override
  String get searchHint => 'მარკა ან მოდელი';

  @override
  String get clearSearch => 'ძიების გასუფთავება';

  @override
  String get catalogNoSearchMatch => 'თქვენი ძიებით არაფერი მოიძებნა';

  @override
  String get makeBooking => 'დაჯავშნა';

  @override
  String get bookingComingSoon => 'ონლაინ ჯავშანი მალე იქნება ხელმისაწვდომი';

  @override
  String get carNotAvailable => 'ეს ავტომობილი მიუწვდომელია';

  @override
  String get backToCars => 'ავტომობილების სიაში დაბრუნება';

  @override
  String get carError =>
      'ავტომობილის ჩატვირთვა ვერ მოხერხდა. სცადეთ მოგვიანებით.';

  @override
  String get descriptionTitle => 'აღწერა';

  @override
  String photoPosition(int current, int total) {
    return 'ფოტო $current / $total';
  }
}
