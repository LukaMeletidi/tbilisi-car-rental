/// The company information in settings/company (PLAN Section 4): what
/// About Us shows and the Company Info screen edits. Every field is
/// optional; a field that is not set is null here and ABSENT in the stored
/// document. Pure Dart; nothing here talks to Firestore and nothing is
/// logged.
library;

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

/// The social pages the company may link to; the names are the stored keys
/// (companySocialFields).
enum CompanySocialLink { facebook, instagram, whatsapp, telegram }

/// The company information. A value is built only by [CompanyInfo.fromMap]
/// or by companyFromInput, which both check every field as the rules do,
/// so [toMap] always gives a document the rules accept.
class CompanyInfo {
  CompanyInfo({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.workingHours,
    this.mapUrl,
    Map<CompanySocialLink, String> social = const {},
  }) : social = Map.unmodifiable(social);

  /// Reads a stored settings/company. Throws a [FormatException] when a
  /// field is unknown, or present but not valid by the rules of
  /// firestore.rules. An empty document {} is valid: nothing is filled in.
  /// The message names the field, never its value.
  factory CompanyInfo.fromMap(Map<String, dynamic> data) {
    for (final key in data.keys) {
      if (!companyFields.contains(key)) {
        throw FormatException('settings/company: unknown field "$key".');
      }
    }
    Never invalid(String field) =>
        throw FormatException('settings/company: "$field" is not valid.');

    String? text(String field, bool Function(String value) isValid) {
      if (!data.containsKey(field)) return null;
      final value = data[field];
      if (value is! String || !isValid(value)) invalid(field);
      return value;
    }

    LocalizedText? translated(String field) {
      if (!data.containsKey(field)) return null;
      final value = data[field];
      if (value is! Map || !_isCompanyTextMap(value)) invalid(field);
      return LocalizedText(
        ka: value['ka'] as String,
        ru: value['ru'] as String,
        en: value['en'] as String,
      );
    }

    final social = <CompanySocialLink, String>{};
    if (data.containsKey('social')) {
      final value = data['social'];
      if (value is! Map || value.isEmpty) invalid('social');
      for (final MapEntry(:key, value: address) in value.entries) {
        final link = CompanySocialLink.values
            .where((link) => link.name == key)
            .firstOrNull;
        if (link == null || address is! String || !isCompanyLink(address)) {
          invalid('social');
        }
        social[link] = address;
      }
    }

    return CompanyInfo(
      name: text('name', isCompanyName),
      phone: text('phone', isStoredCompanyPhone),
      email: text('email', isStoredCompanyEmail),
      address: translated('address'),
      workingHours: translated('workingHours'),
      mapUrl: text('mapUrl', isCompanyLink),
      social: social,
    );
  }

  /// Nothing filled in.
  static final empty = CompanyInfo();

  final String? name;

  /// In its stored form: "+" and digits only.
  final String? phone;
  final String? email;
  final LocalizedText? address;
  final LocalizedText? workingHours;
  final String? mapUrl;

  /// The links that are set; empty when none is. Cannot be changed.
  final Map<CompanySocialLink, String> social;

  /// Whether no field is set: About Us then shows its empty state.
  bool get isEmpty =>
      name == null &&
      phone == null &&
      email == null &&
      address == null &&
      workingHours == null &&
      mapUrl == null &&
      social.isEmpty;

  /// The document to store: only the fields that are set. Never an empty
  /// text, never null, never an empty social map.
  Map<String, dynamic> toMap() => {
    if (name != null) 'name': name,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (address != null) 'address': address!.toMap(),
    if (workingHours != null) 'workingHours': workingHours!.toMap(),
    if (mapUrl != null) 'mapUrl': mapUrl,
    if (social.isNotEmpty)
      'social': {
        for (final link in CompanySocialLink.values)
          if (social[link] != null) link.name: social[link],
      },
  };

  @override
  bool operator ==(Object other) =>
      other is CompanyInfo &&
      other.name == name &&
      other.phone == phone &&
      other.email == email &&
      other.address == address &&
      other.workingHours == workingHours &&
      other.mapUrl == mapUrl &&
      other.social.length == social.length &&
      social.entries.every((entry) => other.social[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    name,
    phone,
    email,
    address,
    workingHours,
    mapUrl,
    Object.hashAll([for (final link in CompanySocialLink.values) social[link]]),
  );
}

// The same pattern as isTrimmedText in firestore.rules.
final _trimmedText = RegExp(r'^\S([\s\S]*\S)?$');

// The same pattern as isCompanyLink in firestore.rules.
final _companyLink = RegExp(
  '^${RegExp.escape(companyLinkScheme)}[^\\s]+\\.[^\\s]+\$',
);

/// A text of 1 to [max] characters (runes, as the rules count) with no
/// space at either end.
bool _isTrimmedText(String value, int max) =>
    _trimmedText.hasMatch(value) && value.runes.length <= max;

/// A stored company name.
bool isCompanyName(String value) => _isTrimmedText(value, companyNameMaxLength);

/// One stored language of a translated company text.
bool isCompanyTextPart(String value) =>
    _isTrimmedText(value, companyTextMaxLength);

/// A stored phone: already in the booking's stored form.
bool isStoredCompanyPhone(String value) => normalizePhone(value) == value;

/// A stored e-mail: the booking's check, with no space at either end.
bool isStoredCompanyEmail(String value) =>
    value.trim() == value && isValidEmail(value);

/// A stored link: https, no space, a dot after the scheme, at most
/// [companyLinkMaxLength] characters.
bool isCompanyLink(String value) =>
    value.runes.length <= companyLinkMaxLength && _companyLink.hasMatch(value);

bool _isCompanyTextMap(Map<dynamic, dynamic> value) =>
    value.length == companyTextLanguages.length &&
    companyTextLanguages.every((language) {
      final part = value[language];
      return part is String && isCompanyTextPart(part);
    });
