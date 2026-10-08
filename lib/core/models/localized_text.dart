import 'package:tbilisi_car_rental/core/localization/app_language.dart';

/// A text stored once per language, such as a car description { ka, ru, en }.
class LocalizedText {
  const LocalizedText({this.ka = '', this.ru = '', this.en = ''});

  /// Reads { ka, ru, en }. A missing language is an empty text.
  factory LocalizedText.fromMap(Map<String, dynamic> map) {
    return LocalizedText(
      ka: _optionalString(map, 'ka'),
      ru: _optionalString(map, 'ru'),
      en: _optionalString(map, 'en'),
    );
  }

  final String ka;
  final String ru;
  final String en;

  /// The text in [language]; if that is missing, the English text;
  /// if that is missing too, an empty string.
  String forLanguage(AppLanguage language) {
    final text = switch (language) {
      AppLanguage.ka => ka,
      AppLanguage.ru => ru,
      AppLanguage.en => en,
    };
    if (text.trim().isNotEmpty) return text;
    if (en.trim().isNotEmpty) return en;
    return '';
  }

  Map<String, dynamic> toMap() => {'ka': ka, 'ru': ru, 'en': en};

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other.ka == ka &&
      other.ru == ru &&
      other.en == en;

  @override
  int get hashCode => Object.hash(ka, ru, en);
}

String _optionalString(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value == null) return '';
  if (value is String) return value;
  throw FormatException(
    'Text field "$field" must be a string, got ${value.runtimeType}.',
  );
}
