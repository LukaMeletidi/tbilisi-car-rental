import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The empty Calendar page (step 5.5a). It must read nothing.
late FakeAdminBookingsRepository bookings;
late FakeFleetRepository fleet;

Future<void> pumpPage(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  bookings = FakeAdminBookingsRepository();
  fleet = FakeFleetRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        fleetRepositoryProvider.overrideWithValue(fleet),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminCalendarScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the title, the time zone, the not-ready line and Sign out; '
      'no back arrow', (tester) async {
    await pumpPage(tester, const Size(800, 1000));
    expect(find.text(adminCalendarTitle), findsOneWidget);
    expect(find.text(adminTbilisiTimeNote), findsOneWidget);
    expect(find.text(adminCalendarNotReady), findsOneWidget);
    expect(find.byTooltip(adminSignOutButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('it reads nothing', (tester) async {
    await pumpPage(tester, const Size(800, 1000));
    expect(bookings.limits, isEmpty);
    expect(bookings.carReads, 0);
    expect(bookings.watchedBookingIds, isEmpty);
    expect(bookings.confirmedReads, isEmpty);
    expect(fleet.queries, 0);
    expect(fleet.carReads, isEmpty);
  });

  for (final size in [const Size(320, 640), const Size(1200, 900)]) {
    testWidgets('${size.width.toInt()} px wide: nothing overflows', (
      tester,
    ) async {
      await pumpPage(tester, size);
      expect(tester.takeException(), isNull);
    });
  }
}
