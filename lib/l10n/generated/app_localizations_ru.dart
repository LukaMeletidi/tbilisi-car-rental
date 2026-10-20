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

  @override
  String get tabHome => 'Главная';

  @override
  String get tabCars => 'Авто';

  @override
  String get tabContact => 'Контакты';

  @override
  String get tabFaq => 'Вопросы';

  @override
  String get aboutTitle => 'О нас';

  @override
  String get homeHeroTitle => 'Автопарк';

  @override
  String get homeHeroSubtitle => 'Каталог автомобилей';

  @override
  String get homeTopCarsTitle => 'Самые популярные автомобили';

  @override
  String get homeProcessTitle => 'Процесс аренды и доставки автомобиля';

  @override
  String get homeProcess1Title => 'Выбор автомобиля';

  @override
  String get homeProcess1Text =>
      'Ознакомьтесь с нашим каталогом и выберите подходящую модель.';

  @override
  String get homeProcess2Title => 'Бронирование';

  @override
  String get homeProcess2Text =>
      'Заполните форму на сайте или свяжитесь с нами по телефону.';

  @override
  String get homeProcess3Title => 'Подтверждение';

  @override
  String get homeProcess3Text =>
      'Наш менеджер свяжется с вами для уточнения деталей.';

  @override
  String get homeProcess4Title => 'Получение автомобиля';

  @override
  String get homeProcess4Text =>
      'Встреча в удобном для вас месте, подписание договора и передача ключей.';

  @override
  String get homeBenefitsTitle =>
      'Мы заинтересованы в том, чтобы в следующий раз вы выбрали нас снова';

  @override
  String get homeBenefit1Title => 'Обслуживание 24/7';

  @override
  String get homeBenefit1Text =>
      'Наши клиенты получают не только аренду авто, но и индивидуальное внимание 24/7. Всегда доступен личный менеджер для решения вопросов в течение всего срока аренды.';

  @override
  String get homeBenefit2Title => 'Полная безопасность';

  @override
  String get homeBenefit2Text =>
      'Все автомобили в нашем парке застрахованы, обеспечивая вам спокойствие и уверенность в любой поездке.';

  @override
  String get homeBenefit3Title => 'Высокое качество автомобилей';

  @override
  String get homeBenefit3Text =>
      'Наши машины всегда в отличном техническом состоянии, оснащены зимней резиной в зимний период для вашей безопасности.';

  @override
  String get homeTermsTitle => 'Лучшие условия для комфортной поездки';

  @override
  String get homeTerms1Title => 'Минимальный залог';

  @override
  String get homeTerms1Text =>
      'При аренде машины необходимо внести депозит, размер которого зависит от типа трансмиссии автомобиля.';

  @override
  String get homeTerms2Title => 'Возраст от 21 года';

  @override
  String get homeTerms2Text =>
      'Опыт вождения не менее 2 лет: страховые требования стандартные, без дополнительных условий.';

  @override
  String get homeTerms3Title => 'Честное разделение рисков';

  @override
  String get homeTerms3Text =>
      'Для максимального спокойствия арендаторов, на все транспортные средства оформлен полис обязательного страхования гражданской ответственности, а многие из них также имеют полное страховое покрытие.';

  @override
  String get homeTrafficTitle => 'Особенности дорожного движения в Грузии';

  @override
  String get homeTraffic1Title => 'до 60 км/ч';

  @override
  String get homeTraffic1Text => 'в населенных пунктах';

  @override
  String get homeTraffic2Title => 'до 90 км/ч';

  @override
  String get homeTraffic2Text => 'вне населенных пунктов';

  @override
  String get homeTraffic3Title => 'до 110 км/ч';

  @override
  String get homeTraffic3Text => 'на автомагистралях';

  @override
  String get faqPageHeading => 'Ответы на популярные вопросы клиентов';

  @override
  String get faq1Question => 'Какие документы требуются для аренды машины?';

  @override
  String get faq1Answer =>
      'Для аренды автомобиля в Грузии потребуется действующее водительское удостоверение, паспорт и международные права (если ваша страна не входит в список согласованных).';

  @override
  String get faq2Question => 'Где лучше осуществлять заправку в Грузии?';

  @override
  String get faq2Answer =>
      'На каждом пройденном пятикилометровом участке дороги вы обнаружите небольшие заправочные станции, а более крупные находятся на расстоянии 10-15 км. Подавляющее большинство станций работают в режиме круглосуточного обслуживания. Вам доступны различные виды топлива, включая дизель, 92-й, 95-й и 98-й бензин.';

  @override
  String get faq3Question => 'Как получить машину, взятую в аренду?';

  @override
  String get faq3Answer =>
      'После успешного бронирования вы можете забрать автомобиль в указанном месте. Наш представитель предоставит вам авто, проверит необходимые документы и расскажет об особенностях использования.';

  @override
  String get faq4Question =>
      'Изменились планы: процесс отмены брони и связанные платежи?';

  @override
  String get faq4Answer =>
      'Если ваши планы изменились, вы можете отменить бронь связавшись с нашей службой поддержки. В зависимости от срока и причины отмены, могут применяться определенные платежи.';

  @override
  String get faq5Question =>
      'Влияние отмены или переноса рейса на бронирование автомобиля?';

  @override
  String get faq5Answer =>
      'Если ваш рейс отменится или перенесется, пожалуйста, свяжитесь с нами как можно скорее. Мы постараемся адаптировать ваш заказ в соответствии с новым графиком.';

  @override
  String get faq6Question =>
      'Какие расходы я могу понести при аренде автомобиля?';

  @override
  String get faq6Answer =>
      'Расходы могут включать топливо, оплата штрафов за нарушение ПДД и дополнительные услуги, если они не включены в основной пакет.';

  @override
  String get faq7Question => 'Что будет, если нарушить договор аренды?';

  @override
  String get faq7Answer =>
      'Нарушение договора аренды может повлечь за собой одностороннее прекращение договора, штрафы по договору и правовые последствия в соответствии с законодательством Грузии.';

  @override
  String get faq8Question =>
      'Процедура оплаты аренды автомобиля: когда и как это выполняется?';

  @override
  String get faq8Answer =>
      'Оплата аренды осуществляется на момент подписания договора. Принимаем оплату картами, переводами онлайн, криптовалютой — в любой валюте.';

  @override
  String get faq9Question => 'Как следует возвращать машины после аренды?';

  @override
  String get faq9Answer =>
      'Необходимо возвращать автомобиль в том же состоянии, в котором он был получен, с таким же уровнем топлива. Наши автомобили предоставляются в аренду в чистом состоянии.';

  @override
  String get faq10Question => 'Каков размер предоплаты?';

  @override
  String get faq10Answer =>
      'Размер предоплаты зависит от даты брони, срока аренды и выбранной модели автомобиля. Подробности обсуждаются персонально при бронировании.';

  @override
  String get aboutText =>
      'Наша компания работает с клиентами уже много лет, предлагая качественные, безупречно обслуживаемые и чистые автомобили. Наша команда профессионалов готова помочь вам в любое время — 24 часа в сутки, 7 дней в неделю. Мы предоставляем не только первоклассные автомобили, но и отличный сервис в доброжелательной атмосфере. Наши менеджеры всегда на связи и готовы вам помочь.';

  @override
  String get aboutContactsTitle => 'Контакты';

  @override
  String get aboutPhoneLabel => 'Телефон';

  @override
  String get aboutEmailLabel => 'Эл. почта';

  @override
  String get aboutAddressLabel => 'Адрес';

  @override
  String get aboutWorkingHoursLabel => 'Часы работы';

  @override
  String get aboutShowOnMap => 'Показать на карте';

  @override
  String get aboutCopy => 'Копировать';

  @override
  String get aboutCopied => 'Скопировано';

  @override
  String get aboutOpenFailed => 'Не удалось открыть ссылку. Текст скопирован.';

  @override
  String get aboutContactsError =>
      'Не удалось загрузить контактные данные. Попробуйте позже.';

  @override
  String get aboutFacebook => 'Facebook';

  @override
  String get aboutInstagram => 'Instagram';

  @override
  String get aboutWhatsapp => 'WhatsApp';

  @override
  String get aboutTelegram => 'Telegram';
}
