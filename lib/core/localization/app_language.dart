/// The three languages of the public UI.
enum AppLanguage {
  en('en', 'English'),
  ka('ka', 'ქართული'),
  ru('ru', 'Русский');

  const AppLanguage(this.code, this.nativeName);

  /// Two-letter language code, also stored on each booking later.
  final String code;

  /// The language's own name, shown in the language switcher.
  final String nativeName;
}

/// Starting language rule: the first device language that we support,
/// otherwise English. [deviceLanguageCodes] is in the user's preference order.
AppLanguage resolveStartingLanguage(List<String> deviceLanguageCodes) {
  for (final deviceCode in deviceLanguageCodes) {
    final code = deviceCode.toLowerCase();
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
  }
  return AppLanguage.en;
}
