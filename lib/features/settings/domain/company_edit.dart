/// The edit of the company information (step 6.7): whether the typed form
/// would change what is stored, and what the screen says after a save. The
/// field checks and the company to save are in company_input.dart. Pure
/// Dart; nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// Whether [draft] would change the stored [base] (null: settings/company
/// does not exist yet). When the form has no problem, the company it would
/// save is compared, so spaces around a text, or a phone typed with spaces,
/// is no change. Otherwise the trimmed texts are compared with the form as
/// it opened.
bool companyDraftChanged(CompanyInfo? base, CompanyInput draft) {
  if (validateCompanyInput(draft).isEmpty) {
    return companyFromInput(draft) != (base ?? CompanyInfo.empty);
  }
  return !sameCompanyInput(CompanyInput.fromCompany(base), draft);
}

/// Whether two forms hold the same texts, ignoring spaces at either end.
bool sameCompanyInput(CompanyInput a, CompanyInput b) {
  String t(String text) => text.trim();
  bool sameText(LocalizedText x, LocalizedText y) =>
      t(x.ka) == t(y.ka) && t(x.ru) == t(y.ru) && t(x.en) == t(y.en);
  return t(a.name) == t(b.name) &&
      t(a.phone) == t(b.phone) &&
      t(a.email) == t(b.email) &&
      sameText(a.address, b.address) &&
      sameText(a.workingHours, b.workingHours) &&
      t(a.mapUrl) == t(b.mapUrl) &&
      CompanySocialLink.values.every(
        (link) => t(a.social[link] ?? '') == t(b.social[link] ?? ''),
      );
}

/// Why loading the company information for the form failed.
enum CompanyLoadFailure {
  /// No answer of the server in time; the read stays open.
  noConnection,

  /// Anything else.
  other,
}

/// What the screen says after an attempt to save.
enum CompanySaveNotice {
  /// The server confirmed it (or it was already stored exactly so).
  saved,

  /// No answer in time: the information may or may not be saved.
  noAnswer,

  noConnection,
  refused,
  changedElsewhere,
  unknown,
}

/// The notice for a save that certainly did not happen.
CompanySaveNotice noticeForCompanyWriteFailure(SettingsWriteFailure failure) {
  switch (failure) {
    case SettingsWriteFailure.noConnection:
      return CompanySaveNotice.noConnection;
    case SettingsWriteFailure.refused:
      return CompanySaveNotice.refused;
    case SettingsWriteFailure.changedElsewhere:
      return CompanySaveNotice.changedElsewhere;
    case SettingsWriteFailure.unknown:
      return CompanySaveNotice.unknown;
  }
}
