import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/config/app_check_config.dart';

void main() {
  group('appCheckWebProvider', () {
    test('debug: the web debug provider, without a token from the code', () {
      final provider = appCheckWebProvider(debug: true, siteKey: 'x');
      expect(provider, isA<WebDebugProvider>());
      expect((provider! as WebDebugProvider).debugToken, isNull);
    });

    test('debug without a key: still the debug provider', () {
      expect(
        appCheckWebProvider(debug: true, siteKey: ''),
        isA<WebDebugProvider>(),
      );
    });

    test('release with a key: reCAPTCHA Enterprise with that key', () {
      final provider = appCheckWebProvider(
        debug: false,
        siteKey: ' made-up-site-key ',
      );
      expect(provider, isA<ReCaptchaEnterpriseProvider>());
      expect(provider!.siteKey, 'made-up-site-key');
    });

    test(
      'release with an empty key: no provider (no App Check on the web)',
      () {
        expect(appCheckWebProvider(debug: false, siteKey: ''), isNull);
        expect(appCheckWebProvider(debug: false, siteKey: '   '), isNull);
      },
    );
  });

  group('the committed site key', () {
    test('is a reCAPTCHA site key: not empty, no spaces, starts with "6L"', () {
      expect(appCheckWebSiteKey, isNotEmpty);
      expect(appCheckWebSiteKey, isNot(contains(RegExp(r'\s'))));
      expect(appCheckWebSiteKey, startsWith('6L'));
    });

    test('the release build uses it', () {
      final provider = appCheckWebProvider(
        debug: false,
        siteKey: appCheckWebSiteKey,
      );
      expect(provider, isA<ReCaptchaEnterpriseProvider>());
      expect(provider!.siteKey, appCheckWebSiteKey);
    });

    test('no name in the file says token, secret or api key', () {
      final source = File(
        'lib/core/config/app_check_config.dart',
      ).readAsStringSync();
      final names = [
        for (final match in RegExp(
          r'^(?:const|final|[A-Za-z?<>]+)\s+([A-Za-z_]\w*)\s*[=(]',
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];
      expect(names, containsAll(['appCheckWebSiteKey', 'appCheckWebProvider']));
      for (final name in names) {
        expect(
          name,
          isNot(
            matches(RegExp(r'token|secret|api_?key', caseSensitive: false)),
          ),
          reason: name,
        );
      }
    });
  });
}
