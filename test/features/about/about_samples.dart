import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

/// Made-up company data for the tests of the Contact tab.
const sampleAddress = LocalizedText(
  ka: 'თბილისი, სანიმუშო ქუჩა 1',
  ru: 'Тбилиси, Примерная улица 1',
  en: 'Tbilisi, 1 Example Street',
);

const sampleHours = LocalizedText(
  ka: 'ყოველდღე 09:00–21:00',
  ru: 'Ежедневно 09:00–21:00',
  en: 'Every day 09:00–21:00',
);

const samplePhone = '+995555000001';
const sampleEmail = 'info@example.com';
const sampleName = 'Example Car Rental';
const sampleMap = 'https://www.example.com/map';

/// A made-up company with every field filled in.
CompanyInfo fullCompany({String? mapUrl = sampleMap}) => CompanyInfo(
  name: sampleName,
  phone: samplePhone,
  email: sampleEmail,
  address: sampleAddress,
  workingHours: sampleHours,
  mapUrl: mapUrl,
  social: const {
    CompanySocialLink.facebook: 'https://www.example.com/facebook',
    CompanySocialLink.instagram: 'https://www.example.com/instagram',
    CompanySocialLink.whatsapp: 'https://www.example.com/whatsapp',
    CompanySocialLink.telegram: 'https://www.example.com/telegram',
  },
);
