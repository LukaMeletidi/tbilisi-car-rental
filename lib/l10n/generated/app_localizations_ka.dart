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
  String priceAmount(String amount) {
    return '\$$amount';
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
  String get makeBooking => 'დაჯავშნის მოთხოვნა';

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

  @override
  String get bookingTitle => 'ჯავშნის მოთხოვნა';

  @override
  String get bookingSectionContact => 'თქვენი მონაცემები';

  @override
  String get bookingFullName => 'სახელი და გვარი';

  @override
  String get bookingFullNameHelper => 'როგორც პასპორტშია';

  @override
  String get bookingPhone => 'ტელეფონის ნომერი';

  @override
  String get bookingWhatsapp => 'ამ ნომერზე ვიყენებ WhatsApp-ს';

  @override
  String get bookingTelegram => 'ამ ნომერზე ვიყენებ Telegram-ს';

  @override
  String get bookingEmail => 'ელფოსტა';

  @override
  String get bookingSectionDates => 'თარიღები';

  @override
  String get bookingPickupDateTime => 'მიღების თარიღი და დრო';

  @override
  String get bookingDropoffDateTime => 'დაბრუნების თარიღი და დრო';

  @override
  String get tbilisiTimeLabel => 'თბილისის დრო (GMT+4)';

  @override
  String get bookingSectionLocations => 'ადგილები';

  @override
  String get bookingPickupLocation => 'მიღების ადგილი';

  @override
  String get bookingDropoffLocation => 'დაბრუნების ადგილი';

  @override
  String get bookingLocationOther => 'სხვა ადგილი';

  @override
  String get bookingLocationOtherText => 'მისამართი ან ადგილი საქართველოში';

  @override
  String get bookingSectionExtras => 'დამატებითი მომსახურება';

  @override
  String get extraSnowChains => 'თოვლის ჯაჭვები';

  @override
  String get extraChildSeat => 'საბავშვო სავარძელი';

  @override
  String get extraChildSeatAge => '1–4 წელი';

  @override
  String get extraInfantSeat => 'ჩვილის სავარძელი';

  @override
  String get extraInfantSeatAge => '0–12 თვე';

  @override
  String get extraBoosterSeat => 'ბუსტერი';

  @override
  String get extraBoosterSeatAge => '3–16 წელი';

  @override
  String get extraFree => 'უფასო';

  @override
  String get bookingSectionNotes => 'განსაკუთრებული სურვილები';

  @override
  String get bookingNotesHint =>
      'არასავალდებულო. მაგალითად: ორი საბავშვო სავარძელი';

  @override
  String get bookingSectionPrice => 'ფასი';

  @override
  String get bookingChooseDates => 'ფასის სანახავად აირჩიეთ თარიღები';

  @override
  String get bookingRentalDays => 'ქირაობის დღეები';

  @override
  String get bookingTotal => 'სულ';

  @override
  String get bookingEstimatedTotal => 'სავარაუდო ფასი';

  @override
  String bookingIndividualPriceNote(int days) {
    return '$days დღეზე მეტი ხნით ქირაობისას ფასი ინდივიდუალურია — ჩვენი გუნდი დაგიკავშირდებათ საბოლოო ფასის დასადასტურებლად.';
  }

  @override
  String get bookingSubmit => 'მოთხოვნის გაგზავნა';

  @override
  String get bookingSending => 'იგზავნება…';

  @override
  String get bookingCheckFields => 'გთხოვთ, შეამოწმოთ მონიშნული ველები';

  @override
  String get bookingFormLoadError =>
      'ჯავშნის ფორმის ჩატვირთვა ვერ მოხერხდა. სცადეთ მოგვიანებით.';

  @override
  String get bookingErrorNameRequired => 'შეიყვანეთ სახელი და გვარი';

  @override
  String get bookingErrorNameTooShort => 'სახელი ძალიან მოკლეა';

  @override
  String bookingErrorTooLong(int max) {
    return 'არაუმეტეს $max სიმბოლო';
  }

  @override
  String get bookingErrorPhoneRequired => 'შეიყვანეთ ტელეფონის ნომერი';

  @override
  String bookingErrorPhoneInvalid(String example) {
    return 'მიუთითეთ ნომერი საერთაშორისო ფორმატში, მაგალითად $example';
  }

  @override
  String get bookingErrorEmailRequired => 'შეიყვანეთ ელფოსტა';

  @override
  String get bookingErrorEmailInvalid => 'შეიყვანეთ სწორი ელფოსტის მისამართი';

  @override
  String get bookingErrorPickupRequired => 'აირჩიეთ მიღების თარიღი და დრო';

  @override
  String get bookingErrorPickupNotInFuture => 'მიღების დრო მომავალში უნდა იყოს';

  @override
  String get bookingErrorDropoffRequired => 'აირჩიეთ დაბრუნების თარიღი და დრო';

  @override
  String get bookingErrorDropoffNotAfterPickup =>
      'დაბრუნება მიღებაზე გვიან უნდა იყოს';

  @override
  String bookingErrorRentalTooLong(int days) {
    return 'ქირაობა შესაძლებელია არაუმეტეს $days დღით';
  }

  @override
  String get bookingErrorLocationRequired => 'აირჩიეთ ადგილი';

  @override
  String get bookingErrorLocationUnknown =>
      'ეს ადგილი აღარ არის ხელმისაწვდომი. აირჩიეთ სხვა.';

  @override
  String get bookingErrorLocationTextRequired => 'მიუთითეთ მისამართი ან ადგილი';

  @override
  String get bookingFailedRejected =>
      'მოთხოვნა არ იქნა მიღებული. შეამოწმეთ თქვენი მონაცემები და თარიღები, ან აირჩიეთ სხვა ავტომობილი.';

  @override
  String get bookingFailedNoConnection =>
      'მოთხოვნის გაგზავნა ვერ მოხერხდა. შეამოწმეთ ინტერნეტკავშირი და სცადეთ ხელახლა.';

  @override
  String get bookingFailedUnknown => 'დაფიქსირდა შეცდომა. სცადეთ ხელახლა.';

  @override
  String get bookingSentThanks =>
      'გმადლობთ ნდობისთვის — ჩვენი წარმომადგენელი მალე დაგიკავშირდებათ დეტალების დასაზუსტებლად.';

  @override
  String get bookingSentSummaryTitle => 'თქვენი მოთხოვნა';

  @override
  String get bookingSentCar => 'ავტომობილი';

  @override
  String get bookingSentPickup => 'მიღება';

  @override
  String get bookingSentDropoff => 'დაბრუნება';

  @override
  String get bookingSentNoExtras => 'არ არის';

  @override
  String get bookingSentUnknownPlace => 'ადგილი ჩვენი სიიდან';

  @override
  String get bookingSentWhatsapp => 'WhatsApp';

  @override
  String get bookingSentTelegram => 'Telegram';

  @override
  String get tabHome => 'მთავარი';

  @override
  String get tabCars => 'მანქანები';

  @override
  String get tabContact => 'კონტაქტი';

  @override
  String get tabFaq => 'კითხვები';

  @override
  String get aboutTitle => 'ჩვენ შესახებ';

  @override
  String get homeHeroTitle => 'ავტოპარკი';

  @override
  String get homeHeroSubtitle => 'ავტომობილების კატალოგი';

  @override
  String get homeTopCarsTitle => 'ყველაზე პოპულარული ავტომობილები';

  @override
  String get homeProcessTitle => 'მანქანის გაქირავებისა და მიწოდების პროცესი';

  @override
  String get homeProcess1Title => 'ავტომობილის შერჩევა';

  @override
  String get homeProcess1Text =>
      'გადახედეთ ჩვენს კატალოგს და შეარჩიეთ სასურველი მოდელი.';

  @override
  String get homeProcess2Title => 'დაჯავშნა';

  @override
  String get homeProcess2Text =>
      'შეავსეთ ფორმა ვებგვერდზე ან დაგვიკავშირდით ტელეფონით.';

  @override
  String get homeProcess3Title => 'დადასტურება';

  @override
  String get homeProcess3Text =>
      'ჩვენი მენეჯერი დაგიკავშირდებათ დეტალების დასაზუსტებლად.';

  @override
  String get homeProcess4Title => 'ავტომობილის მიღება';

  @override
  String get homeProcess4Text =>
      'თქვენთვის მოსახერხებელ ადგილას შეხვედრა, ხელშეკრულების გაფორმება და გასაღებების გადაცემა.';

  @override
  String get homeBenefitsTitle => 'გვსურს, რომ მომავალშიც ჩვენ აგვირჩიოთ';

  @override
  String get homeBenefit1Title => '24/7 მომსახურება';

  @override
  String get homeBenefit1Text =>
      'ჩვენი კლიენტები არა მხოლოდ ავტომობილის დაქირავებას, არამედ ინდივიდუალურ ყურადღებასაც იღებენ 24/7 რეჟიმში. პირადი მენეჯერი ყოველთვის ხელმისაწვდომია მთელი გაქირავების პერიოდის განმავლობაში არსებული პრობლემების გადასაჭრელად.';

  @override
  String get homeBenefit2Title => 'სრული უსაფრთხოება';

  @override
  String get homeBenefit2Text =>
      'ჩვენს ავტოპარკში არსებული ყველა ავტომობილი დაზღვეულია, რაც ნებისმიერი მგზავრობისას თქვენს სიმშვიდესა და თავდაჯერებულობას უზრუნველყოფს.';

  @override
  String get homeBenefit3Title => 'უმაღლესი ხარისხის ავტომობილები';

  @override
  String get homeBenefit3Text =>
      'ჩვენი ავტომობილები ყოველთვის შესანიშნავ ტექნიკურ მდგომარეობაშია; თქვენი უსაფრთხოებისთვის, ზამთრის პერიოდში ისინი აღჭურვილია ზამთრის საბურავებით.';

  @override
  String get homeTermsTitle => 'საუკეთესო პირობები კომფორტული მგზავრობისთვის';

  @override
  String get homeTerms1Title => 'მინიმალური დეპოზიტი';

  @override
  String get homeTerms1Text =>
      'ავტომობილის დაქირავებისას საჭიროა დეპოზიტის შეტანა, რომლის ოდენობაც ავტომობილის გადაცემათა კოლოფის ტიპზეა დამოკიდებული.';

  @override
  String get homeTerms2Title => 'ასაკი — 21 წლიდან';

  @override
  String get homeTerms2Text =>
      'მართვის გამოცდილება მინიმუმ 2 წელი: დაზღვევის მოთხოვნები სტანდარტულია, დამატებითი პირობების გარეშე.';

  @override
  String get homeTerms3Title => 'რისკების სამართლიანი გაზიარება';

  @override
  String get homeTerms3Text =>
      'მქირავებლების მაქსიმალური სიმშვიდის უზრუნველსაყოფად, ყველა ავტომობილი დაზღვეულია მესამე პირის სამოქალაქო პასუხისმგებლობის სავალდებულო დაზღვევით, ბევრი მათგანი კი სრული დაზღვევითაც.';

  @override
  String get homeTrafficTitle => 'საგზაო მოძრაობის თავისებურებები საქართველოში';

  @override
  String get homeTraffic1Title => '60 კმ/სთ-მდე';

  @override
  String get homeTraffic1Text => 'დასახლებულ პუნქტებში';

  @override
  String get homeTraffic2Title => '90 კმ/სთ-მდე';

  @override
  String get homeTraffic2Text => 'დასახლებული პუნქტების გარეთ';

  @override
  String get homeTraffic3Title => '110 კმ/სთ-მდე';

  @override
  String get homeTraffic3Text => 'ავტომაგისტრალებზე';

  @override
  String get faqPageHeading => 'პასუხები მომხმარებელთა ხშირ კითხვებზე';

  @override
  String get faq1Question =>
      'რა დოკუმენტებია საჭირო ავტომობილის დასაქირავებლად?';

  @override
  String get faq1Answer =>
      'ავტომობილის დასაქირავებლად, დაგჭირდებათ მოქმედი მართვის მოწმობა, პასპორტი და მართვის საერთაშორისო ნებართვა (გარდა იმ შემთხვევისა, თუ თქვენი ქვეყანა შედის დაშვებულ ქვეყანათა სიაში).';

  @override
  String get faq2Question =>
      'სად არის საუკეთესო ადგილი საქართველოში საწვავის ჩასასხმელად?';

  @override
  String get faq2Answer =>
      'გზის გასწვრივ, ყოველ ხუთ კილომეტრში პატარა ბენზინგასამართი სადგურებია, ხოლო უფრო დიდი სადგურები — 10–15 კილომეტრის ინტერვალით. მათი უმეტესობა 24 საათის განმავლობაში მუშაობს. ხელმისაწვდომია საწვავის სხვადასხვა სახეობა, მათ შორის დიზელი, ასევე 92, 95 და 98-ოქტანიანი ბენზინი.';

  @override
  String get faq3Question => 'როგორ მივიღო გაქირავებული ავტომობილი?';

  @override
  String get faq3Answer =>
      'ჯავშნის წარმატებით დადასტურების შემდეგ, ავტომობილის მიღება შეგეძლებათ განსაზღვრულ ადგილას. ჩვენი წარმომადგენელი გადაგცემთ ავტომობილს, შეამოწმებს საჭირო დოკუმენტებს და აგიხსნით მისი გამოყენების თავისებურებებს.';

  @override
  String get faq4Question =>
      'გეგმები შეიცვალა: რა ხდება ჯავშნის გაუქმების პროცესსა და მასთან დაკავშირებულ გადახდებთან დაკავშირებით?';

  @override
  String get faq4Answer =>
      'თუ თქვენი გეგმები შეიცვალა, ჯავშნის გაუქმება შეგიძლიათ ჩვენს მხარდაჭერის გუნდთან დაკავშირებით. გაუქმების დროისა და მიზეზის მიხედვით, შესაძლოა, გარკვეული გადასახადი დაგეკისროთ.';

  @override
  String get faq5Question =>
      'როგორ მოქმედებს ფრენის გაუქმება ან გადადება ავტომობილის დაქირავების ჯავშანზე?';

  @override
  String get faq5Answer =>
      'თუ თქვენი რეისი გაუქმდა ან გადაიდო, გთხოვთ, რაც შეიძლება მალე დაგვიკავშირდეთ. ჩვენ ყველაფერს გავაკეთებთ იმისათვის, რომ თქვენი ჯავშანი ახალ განრიგს მოვარგოთ.';

  @override
  String get faq6Question =>
      'ავტომობილის დაქირავებისას რა ხარჯები შეიძლება დამეკისროს?';

  @override
  String get faq6Answer =>
      'ხარჯები შესაძლოა მოიცავდეს საწვავს, საგზაო ჯარიმების გადახდასა და დამატებით მომსახურებებს, თუ ისინი უკვე არ შედის ძირითად პაკეტში.';

  @override
  String get faq7Question => 'რა მოხდება, თუ იჯარის ხელშეკრულებას დაარღვევთ?';

  @override
  String get faq7Answer =>
      'იჯარის ხელშეკრულების დარღვევამ შესაძლოა გამოიწვიოს ხელშეკრულების ცალმხრივად შეწყვეტა, ხელშეკრულებით გათვალისწინებული ჯარიმები და საქართველოს კანონმდებლობის შესაბამისი სამართლებრივი შედეგები.';

  @override
  String get faq8Question =>
      'ავტომობილის გაქირავების საფასურის გადახდის პროცედურა: როდის და როგორ ხორციელდება იგი?';

  @override
  String get faq8Answer =>
      'ქირის გადახდა ხდება ხელშეკრულების გაფორმებისას. ვიღებთ გადახდებს ბარათით, ონლაინ გადარიცხვითა და კრიპტოვალუტით — ნებისმიერ ვალუტაში.';

  @override
  String get faq9Question =>
      'როგორ უნდა დაბრუნდეს ავტომობილები გაქირავების შემდეგ?';

  @override
  String get faq9Answer =>
      'სატრანსპორტო საშუალება უნდა დაბრუნდეს იმავე მდგომარეობაში, როგორშიც ის მიიღეთ, საწვავის იმავე დონით. ჩვენი სატრანსპორტო საშუალებები გაიცემა სუფთა მდგომარეობაში.';

  @override
  String get faq10Question => 'რა არის წინასწარი გადახდის ოდენობა?';

  @override
  String get faq10Answer =>
      'წინასწარი გადახდის ოდენობა დამოკიდებულია დაჯავშნის თარიღზე, გაქირავების პერიოდსა და ავტომობილის შერჩეულ მოდელზე. დეტალები განიხილება ინდივიდუალურად, დაჯავშნის პროცესში.';

  @override
  String get aboutText =>
      'ჩვენი კომპანია წლებია ემსახურება მომხმარებლებს და თავაზობს მაღალი ხარისხის, იდეალურად გამართულ და სუფთა ავტომობილებს. ჩვენი პროფესიონალებისგან შემდგარი გუნდი ყოველთვის მზადაა მოგემსახუროთ 24/7 რეჟიმში. ჩვენ გთავაზობთ არა მხოლოდ მაღალი ხარისხის ავტომობილებს, არამედ კარგ მომსახურებასა და მეგობრულ გარემოს. ჩვენი მენეჯერები მუდამ მზად არიან დახმარება გაგიწიონ.';

  @override
  String get aboutContactsTitle => 'კონტაქტები';

  @override
  String get aboutPhoneLabel => 'ტელეფონი';

  @override
  String get aboutEmailLabel => 'ელფოსტა';

  @override
  String get aboutAddressLabel => 'მისამართი';

  @override
  String get aboutWorkingHoursLabel => 'სამუშაო საათები';

  @override
  String get aboutShowOnMap => 'რუკაზე ნახვა';

  @override
  String get aboutCopy => 'კოპირება';

  @override
  String get aboutCopied => 'დაკოპირდა';

  @override
  String get aboutOpenFailed => 'ბმულის გახსნა ვერ მოხერხდა. ტექსტი დაკოპირდა.';

  @override
  String get aboutContactsError =>
      'საკონტაქტო მონაცემების ჩატვირთვა ვერ მოხერხდა. სცადეთ მოგვიანებით.';

  @override
  String get aboutFacebook => 'Facebook';

  @override
  String get aboutInstagram => 'Instagram';

  @override
  String get aboutWhatsapp => 'WhatsApp';

  @override
  String get aboutTelegram => 'Telegram';

  @override
  String get notFoundTitle => 'გვერდი ვერ მოიძებნა';

  @override
  String get notFoundText =>
      'ეს გვერდი არ არსებობს. შესაძლოა მისამართი არასწორად არის აკრეფილი ან მოძველებულია.';

  @override
  String get notFoundGoHome => 'მთავარ გვერდზე';
}
