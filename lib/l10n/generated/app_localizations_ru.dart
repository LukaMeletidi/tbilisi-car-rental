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
  String priceAmount(String amount) {
    return '\$$amount';
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

  @override
  String get searchHint => 'Марка или модель';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get catalogNoSearchMatch => 'По вашему запросу ничего не найдено';

  @override
  String get makeBooking => 'Забронировать';

  @override
  String get carNotAvailable => 'Этот автомобиль недоступен';

  @override
  String get backToCars => 'К списку автомобилей';

  @override
  String get carError =>
      'Не удалось загрузить автомобиль. Повторите попытку позже.';

  @override
  String get descriptionTitle => 'Описание';

  @override
  String photoPosition(int current, int total) {
    return 'Фото $current из $total';
  }

  @override
  String get bookingTitle => 'Заявка на бронирование';

  @override
  String get bookingSectionContact => 'Ваши данные';

  @override
  String get bookingFullName => 'Имя и фамилия';

  @override
  String get bookingFullNameHelper => 'Как в паспорте';

  @override
  String get bookingPhone => 'Номер телефона';

  @override
  String get bookingWhatsapp => 'Я пользуюсь WhatsApp на этом номере';

  @override
  String get bookingTelegram => 'Я пользуюсь Telegram на этом номере';

  @override
  String get bookingEmail => 'Эл. почта';

  @override
  String get bookingSectionDates => 'Даты';

  @override
  String get bookingPickupDateTime => 'Дата и время получения';

  @override
  String get bookingDropoffDateTime => 'Дата и время возврата';

  @override
  String get tbilisiTimeLabel => 'Время Тбилиси (GMT+4)';

  @override
  String get bookingSectionLocations => 'Места';

  @override
  String get bookingPickupLocation => 'Место получения';

  @override
  String get bookingDropoffLocation => 'Место возврата';

  @override
  String get bookingLocationOther => 'Другое место';

  @override
  String get bookingLocationOtherText => 'Адрес или место в Грузии';

  @override
  String get bookingSectionExtras => 'Дополнительно';

  @override
  String get extraSnowChains => 'Цепи противоскольжения';

  @override
  String get extraChildSeat => 'Детское кресло';

  @override
  String get extraChildSeatAge => '1–4 года';

  @override
  String get extraInfantSeat => 'Автолюлька';

  @override
  String get extraInfantSeatAge => '0–12 месяцев';

  @override
  String get extraBoosterSeat => 'Бустер';

  @override
  String get extraBoosterSeatAge => '3–16 лет';

  @override
  String get extraFree => 'Бесплатно';

  @override
  String get bookingSectionNotes => 'Особые пожелания';

  @override
  String get bookingNotesHint => 'Необязательно. Например: два детских кресла';

  @override
  String get bookingSectionPrice => 'Стоимость';

  @override
  String get bookingChooseDates => 'Выберите даты, чтобы увидеть стоимость';

  @override
  String get bookingRentalDays => 'Дней аренды';

  @override
  String get bookingTotal => 'Итого';

  @override
  String get bookingEstimatedTotal => 'Примерная стоимость';

  @override
  String bookingIndividualPriceNote(int days) {
    return 'Для аренды дольше $days дней цена индивидуальная — наша команда свяжется с вами, чтобы подтвердить окончательную цену.';
  }

  @override
  String get bookingSubmit => 'Отправить заявку';

  @override
  String get bookingSending => 'Отправка…';

  @override
  String get bookingCheckFields => 'Проверьте отмеченные поля';

  @override
  String get bookingFormLoadError =>
      'Не удалось загрузить форму бронирования. Попробуйте позже.';

  @override
  String get bookingErrorNameRequired => 'Введите имя и фамилию';

  @override
  String get bookingErrorNameTooShort => 'Имя слишком короткое';

  @override
  String bookingErrorTooLong(int max) {
    return 'Не более $max символов';
  }

  @override
  String get bookingErrorPhoneRequired => 'Введите номер телефона';

  @override
  String bookingErrorPhoneInvalid(String example) {
    return 'Укажите номер в международном формате, например $example';
  }

  @override
  String get bookingErrorEmailRequired => 'Введите эл. почту';

  @override
  String get bookingErrorEmailInvalid => 'Введите правильный адрес эл. почты';

  @override
  String get bookingErrorPickupRequired => 'Выберите дату и время получения';

  @override
  String get bookingErrorPickupNotInFuture =>
      'Время получения должно быть в будущем';

  @override
  String get bookingErrorDropoffRequired => 'Выберите дату и время возврата';

  @override
  String get bookingErrorDropoffNotAfterPickup =>
      'Возврат должен быть позже получения';

  @override
  String bookingErrorRentalTooLong(int days) {
    return 'Аренда может длиться не более $days дней';
  }

  @override
  String get bookingErrorLocationRequired => 'Выберите место';

  @override
  String get bookingErrorLocationUnknown =>
      'Это место больше недоступно. Выберите другое.';

  @override
  String get bookingErrorLocationTextRequired => 'Укажите адрес или место';

  @override
  String get bookingFailedRejected =>
      'Заявка не принята. Проверьте свои данные и даты или выберите другой автомобиль.';

  @override
  String get bookingFailedNoConnection =>
      'Не удалось отправить заявку. Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get bookingFailedUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get bookingSentThanks =>
      'Спасибо за доверие — наш представитель скоро свяжется с вами, чтобы уточнить детали.';

  @override
  String get bookingSentSummaryTitle => 'Ваша заявка';

  @override
  String get bookingSentCar => 'Автомобиль';

  @override
  String get bookingSentPickup => 'Получение';

  @override
  String get bookingSentDropoff => 'Возврат';

  @override
  String get bookingSentNoExtras => 'Нет';

  @override
  String get bookingSentUnknownPlace => 'Место из нашего списка';

  @override
  String get bookingSentWhatsapp => 'WhatsApp';

  @override
  String get bookingSentTelegram => 'Telegram';
}
