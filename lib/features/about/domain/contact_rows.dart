/// The rows of the contacts card on the Contact tab, built from
/// settings/company. Pure Dart; nothing here opens a link and nothing is
/// logged.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

/// What a row shows, in the order of the card.
enum ContactKind {
  phone,
  email,
  address,
  workingHours,
  map,
  facebook,
  instagram,
  whatsapp,
  telegram,
}

/// One row of the contacts card.
class ContactRow {
  const ContactRow({required this.kind, this.text = '', this.uri});

  final ContactKind kind;

  /// The value shown (a phone, an e-mail, an address, the working hours).
  /// Empty for the map and the social links: the screen shows their label.
  final String text;

  /// What a tap opens; null for a row that is plain text.
  final Uri? uri;

  /// Whether the row has a copy button: the phone, the e-mail and the
  /// address.
  bool get copyable =>
      kind == ContactKind.phone ||
      kind == ContactKind.email ||
      kind == ContactKind.address;

  /// What is copied when a link cannot be opened: the value, or the link.
  String get copyText => text.isNotEmpty ? text : uri.toString();

  @override
  bool operator ==(Object other) =>
      other is ContactRow &&
      other.kind == kind &&
      other.text == text &&
      other.uri == uri;

  @override
  int get hashCode => Object.hash(kind, text, uri);

  @override
  String toString() => 'ContactRow(${kind.name})';
}

final _spaces = RegExp(r'\s+');

/// The text without spaces at either end; null when nothing is left.
String? _filled(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// An https link, or null when it is not one.
Uri? _https(String? value) {
  final link = _filled(value);
  if (link == null) return null;
  final uri = Uri.tryParse(link);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri
      : null;
}

/// "tel:" with the phone, without any space.
Uri phoneUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(_spaces, ''));

/// "mailto:" with the e-mail, without any space.
Uri emailUri(String email) =>
    Uri(scheme: 'mailto', path: email.replaceAll(_spaces, ''));

/// The company name for the title of the card; null when it is not set.
String? contactsTitle(CompanyInfo? company) => _filled(company?.name);

/// The rows of the filled fields, in [ContactKind] order, in [language].
/// Empty when nothing is filled in (or the document does not exist).
///
/// The address opens the map link when one is set; otherwise it is plain
/// text, and a map link without an address gets a row of its own.
List<ContactRow> contactRows(CompanyInfo? company, AppLanguage language) {
  if (company == null) return const [];
  final phone = _filled(company.phone);
  final email = _filled(company.email);
  final address = _filled(company.address?.forLanguage(language));
  final hours = _filled(company.workingHours?.forLanguage(language));
  final map = _https(company.mapUrl);

  const social = {
    CompanySocialLink.facebook: ContactKind.facebook,
    CompanySocialLink.instagram: ContactKind.instagram,
    CompanySocialLink.whatsapp: ContactKind.whatsapp,
    CompanySocialLink.telegram: ContactKind.telegram,
  };

  return List.unmodifiable([
    if (phone != null)
      ContactRow(kind: ContactKind.phone, text: phone, uri: phoneUri(phone)),
    if (email != null)
      ContactRow(kind: ContactKind.email, text: email, uri: emailUri(email)),
    if (address != null)
      ContactRow(kind: ContactKind.address, text: address, uri: map),
    if (hours != null) ContactRow(kind: ContactKind.workingHours, text: hours),
    if (address == null && map != null)
      ContactRow(kind: ContactKind.map, uri: map),
    for (final MapEntry(key: link, value: kind) in social.entries)
      if (_https(company.social[link]) case final uri?)
        ContactRow(kind: kind, uri: uri),
  ]);
}
