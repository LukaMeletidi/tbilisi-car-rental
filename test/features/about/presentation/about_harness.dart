import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/links/url_opener.dart';
import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// Stands in for url_launcher: records every link and answers [opens].
class FakeUrlOpener {
  final opened = <Uri>[];
  var opens = true;

  Future<bool> call(Uri uri) async {
    opened.add(uri);
    return opens;
  }
}

/// What the page reads as the company data.
sealed class CompanyAnswer {
  const CompanyAnswer();
}

class CompanyData extends CompanyAnswer {
  const CompanyData(this.company);
  final CompanyInfo? company;
}

class CompanyError extends CompanyAnswer {
  const CompanyError();
}

class CompanyPending extends CompanyAnswer {
  const CompanyPending();
}

late FakeUrlOpener opener;

/// The texts copied to the clipboard, in order.
final copied = <String>[];

/// How many times the page started a read of the company data.
var companyReads = 0;

/// The Contact page alone, at [size] and [textScale], in [language]. The
/// company data is [answer]; a later read (after "Try again") gets [then].
Future<void> pumpAbout(
  WidgetTester tester, {
  CompanyAnswer answer = const CompanyData(null),
  CompanyAnswer? then,
  Size size = const Size(400, 1200),
  double textScale = 1,
  String language = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  opener = FakeUrlOpener();
  copied.clear();
  companyReads = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  Stream<CompanyInfo?> read() {
    companyReads++;
    final current = companyReads == 1 ? answer : (then ?? answer);
    return switch (current) {
      CompanyData(:final company) => Stream.value(company),
      CompanyError() => Stream.error(const FormatException('made up')),
      CompanyPending() => const Stream.empty(),
    };
  }

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        companyInfoProvider.overrideWith((ref) => read()),
        urlOpenerProvider.overrideWithValue(opener.call),
      ],
      child: _App(
        language: AppLanguage.values.byName(language),
        textScale: textScale,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _App extends ConsumerStatefulWidget {
  const _App({required this.language, required this.textScale});

  final AppLanguage language;
  final double textScale;

  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  @override
  void initState() {
    super.initState();
    // As the language menu would: the page reads appLanguageProvider.
    scheduleMicrotask(
      () => ref.read(appLanguageProvider.notifier).setLanguage(widget.language),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    return MaterialApp(
      theme: buildAppTheme(),
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(widget.textScale)),
        child: child!,
      ),
      home: const AboutScreen(),
    );
  }
}

/// The texts of [language].
AppLocalizations aboutTexts(String language) =>
    lookupAppLocalizations(Locale(language));
