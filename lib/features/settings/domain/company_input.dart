/// The Company Info form (step 6.7): the typed text, its problems, and the
/// company to save. Pure Dart. Text is trimmed; an empty text means "not
/// set". The phone and the e-mail use the booking validators.
library;

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

/// What the admin typed, as text. A translated text may be partly empty.
class CompanyInput {
  const CompanyInput({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = const LocalizedText(),
    this.workingHours = const LocalizedText(),
    this.mapUrl = '',
    this.social = const {},
  });

  /// The form filled from what is stored; empty for no document.
  factory CompanyInput.fromCompany(CompanyInfo? company) => CompanyInput(
    name: company?.name ?? '',
    phone: company?.phone ?? '',
    email: company?.email ?? '',
    address: company?.address ?? const LocalizedText(),
    workingHours: company?.workingHours ?? const LocalizedText(),
    mapUrl: company?.mapUrl ?? '',
    social: company?.social ?? const {},
  );

  final String name;
  final String phone;
  final String email;
  final LocalizedText address;
  final LocalizedText workingHours;
  final String mapUrl;
  final Map<CompanySocialLink, String> social;
}

/// The fields of the form that can have a problem.
enum CompanyField {
  name,
  phone,
  email,
  address,
  workingHours,
  mapUrl,
  facebook,
  instagram,
  whatsapp,
  telegram,
}

/// What is wrong with a field.
enum CompanyProblem {
  /// Not a valid phone, e-mail or link.
  invalid,

  /// Longer than the limit.
  tooLong,

  /// A translated text with one or two of the three languages.
  incomplete,

  /// A link that does not start with https://.
  notHttps,
}

final _anySpace = RegExp(r'\s');

/// Every problem of [input], at most one per field. Empty when it can be
/// saved.
Map<CompanyField, CompanyProblem> validateCompanyInput(CompanyInput input) {
  final problems = <CompanyField, CompanyProblem>{};
  if (input.name.trim().runes.length > companyNameMaxLength) {
    problems[CompanyField.name] = CompanyProblem.tooLong;
  }
  final phone = input.phone.trim();
  if (phone.isNotEmpty && normalizePhone(phone) == null) {
    problems[CompanyField.phone] = CompanyProblem.invalid;
  }
  final email = input.email.trim();
  if (email.isNotEmpty && !isValidEmail(email)) {
    problems[CompanyField.email] = CompanyProblem.invalid;
  }
  final address = _translatedProblem(input.address);
  if (address != null) problems[CompanyField.address] = address;
  final hours = _translatedProblem(input.workingHours);
  if (hours != null) problems[CompanyField.workingHours] = hours;
  final map = _linkProblem(input.mapUrl);
  if (map != null) problems[CompanyField.mapUrl] = map;
  for (final link in CompanySocialLink.values) {
    final problem = _linkProblem(input.social[link] ?? '');
    if (problem != null) {
      problems[CompanyField.values.byName(link.name)] = problem;
    }
  }
  return problems;
}

CompanyProblem? _translatedProblem(LocalizedText text) {
  final parts = [text.ka.trim(), text.ru.trim(), text.en.trim()];
  if (parts.every((part) => part.isEmpty)) return null;
  if (parts.any((part) => part.isEmpty)) return CompanyProblem.incomplete;
  if (parts.any((part) => part.runes.length > companyTextMaxLength)) {
    return CompanyProblem.tooLong;
  }
  return null;
}

CompanyProblem? _linkProblem(String raw) {
  final link = raw.trim();
  if (link.isEmpty) return null;
  if (_anySpace.hasMatch(link)) return CompanyProblem.invalid;
  if (!link.startsWith(companyLinkScheme)) return CompanyProblem.notHttps;
  if (link.runes.length > companyLinkMaxLength) return CompanyProblem.tooLong;
  if (!isCompanyLink(link)) return CompanyProblem.invalid;
  return null;
}

/// The company to save from [input]: trimmed, empty texts left out, the
/// phone in its stored form. Throws an [ArgumentError] when
/// validateCompanyInput finds a problem.
CompanyInfo companyFromInput(CompanyInput input) {
  if (validateCompanyInput(input).isNotEmpty) {
    throw ArgumentError('The company input has problems.');
  }
  String? text(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  LocalizedText? translated(LocalizedText typed) => text(typed.en) == null
      ? null
      : LocalizedText(
          ka: typed.ka.trim(),
          ru: typed.ru.trim(),
          en: typed.en.trim(),
        );

  final phone = text(input.phone);
  return CompanyInfo(
    name: text(input.name),
    phone: phone == null ? null : normalizePhone(phone),
    email: text(input.email),
    address: translated(input.address),
    workingHours: translated(input.workingHours),
    mapUrl: text(input.mapUrl),
    social: {
      for (final link in CompanySocialLink.values)
        if (text(input.social[link] ?? '') != null)
          link: text(input.social[link]!)!,
    },
  );
}
