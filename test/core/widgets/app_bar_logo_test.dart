import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

Widget appWithLogo({AssetBundle? bundle}) {
  Widget home = Scaffold(appBar: AppBar(title: const AppBarLogo(height: 48)));
  if (bundle != null) {
    home = DefaultAssetBundle(bundle: bundle, child: home);
  }
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

/// An asset bundle in which no file can be found.
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Asset not found: $key');
}

void main() {
  testWidgets('builds in an app bar with the app name as its label', (
    tester,
  ) async {
    await tester.pumpWidget(appWithLogo());
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppBarLogo), findsOneWidget);
    // The fallback text is not shown, so the image file was found.
    expect(find.text('Tbilisi Car Rental'), findsNothing);
    expect(find.bySemanticsLabel('Tbilisi Car Rental'), findsOneWidget);
    expect(tester.getSize(find.byType(Image)).height, 48);
  });

  testWidgets('shows the app name as text when the image cannot be loaded', (
    tester,
  ) async {
    await tester.pumpWidget(appWithLogo(bundle: _EmptyBundle()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Tbilisi Car Rental'), findsOneWidget);
  });
}
