import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';

class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final deviceLanguageCodes = [
      for (final locale in PlatformDispatcher.instance.locales)
        locale.languageCode,
    ];
    return resolveStartingLanguage(deviceLanguageCodes);
  }

  void setLanguage(AppLanguage language) => state = language;
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);
