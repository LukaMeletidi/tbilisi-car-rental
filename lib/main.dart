import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/firestore_start_up.dart';
import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/firebase_options.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

Future<void> main() async {
  // Needed because we call Firebase before runApp().
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Android and iOS only: Firestore keeps no copy of the data on disk, and
  // an old copy is removed. Must run before anything uses Firestore. Never
  // stops the start of the app.
  await setUpFirestore();
  await _activateAppCheck();
  // Web only: the admin sign-in ends when the browser is closed. Does
  // nothing on Android. Never stops the start of the app.
  await limitWebSignInToBrowserSession();
  runApp(const ProviderScope(child: TbilisiCarRentalApp()));
}

/// Turns on Firebase App Check, for now ONLY in debug builds on Android,
/// with the debug provider (step 2.9a).
///
/// Release builds and the web build do not activate anything yet; step 2.9b
/// (Phase 7) decides their setup. App Check is not enforced in the Firebase
/// console, so requests without a token are still accepted and only counted.
///
/// The debug provider prints a debug token in the Android log on the first
/// start. The owner registers it by hand in the Firebase console. The token
/// is a secret: it is never written into a file of this project.
///
/// A failure here never stops the app: the error is logged and the app
/// starts as usual.
Future<void> _activateAppCheck() async {
  final isAndroidApp =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (!kDebugMode || !isAndroidApp) return;

  try {
    await FirebaseAppCheck.instance
        .activate(providerAndroid: const AndroidDebugProvider())
        .timeout(const Duration(seconds: 5));
  } catch (error, stackTrace) {
    developer.log(
      'App Check could not be activated: $error',
      name: 'main',
      level: 900, // warning
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class TbilisiCarRentalApp extends ConsumerWidget {
  const TbilisiCarRentalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
