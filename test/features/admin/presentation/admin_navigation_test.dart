import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_home_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';

const car = Car(
  id: 'car-1',
  brand: 'Toyota',
  model: 'Prius',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.hybrid,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: LocalizedText(en: 'A good car.'),
  photos: [],
  active: true,
);

/// The real router and the real screens; Firebase is replaced.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

late FakeAdminAuthRepository repository;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

/// Starts the app on the catalog. With [initial] null the session stays
/// "unknown" until the test reports one.
Future<void> pumpApp(
  WidgetTester tester, {
  AdminSession? initial = AdminSession.signedOut,
}) async {
  repository = FakeAdminAuthRepository(initial: initial);
  addTearDown(repository.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(repository),
        activeCarsProvider.overrideWith((ref) => Stream.value([car])),
        carProvider.overrideWith((ref, id) => Stream.value(car)),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

Future<void> open(WidgetTester tester, String address) async {
  containerOf(tester).read(appRouterProvider).go(address);
  await settle(tester);
}

String address(WidgetTester tester) => containerOf(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

void expectOnly(Type screen) {
  for (final type in [
    AdminLoginScreen,
    AdminCheckingScreen,
    AdminNoAccessScreen,
    AdminHomeScreen,
  ]) {
    expect(
      find.byType(type),
      type == screen ? findsOneWidget : findsNothing,
      reason: '$type',
    );
  }
}

void main() {
  group('signed out', () {
    testWidgets('/admin shows the login page, never the admin page', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      expectOnly(AdminLoginScreen);
      expect(address(tester), '/admin/login');
      expect(find.text(adminHomeSignedIn), findsNothing);
    });

    testWidgets('an address below /admin leads to the login page and is '
        'remembered', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/bookings/abc');

      expectOnly(AdminLoginScreen);
      expect(address(tester), '/admin/login?from=%2Fadmin%2Fbookings%2Fabc');
    });

    testWidgets('the no-access and checking pages lead to the login page', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/no-access');
      expectOnly(AdminLoginScreen);
      await open(tester, '/admin/checking');
      expectOnly(AdminLoginScreen);
    });

    testWidgets('the back arrow of the login page opens the catalog', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/login');

      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);

      expectOnly(Null);
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(address(tester), '/');
    });
  });

  group('session not known yet', () {
    testWidgets('only the spinner page is shown; no login page flashes', (
      tester,
    ) async {
      await pumpApp(tester, initial: null);
      await open(tester, '/admin');

      expectOnly(AdminCheckingScreen);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(adminSignInTitle), findsNothing);
      expect(find.text(adminHomeSignedIn), findsNothing);
    });

    testWidgets('then an admin lands on the admin page', (tester) async {
      await pumpApp(tester, initial: null);
      await open(tester, '/admin');

      repository.report(AdminSession.admin);
      await settle(tester);

      expectOnly(AdminHomeScreen);
      expect(address(tester), '/admin');
    });

    testWidgets('then a signed-out visitor lands on the login page', (
      tester,
    ) async {
      await pumpApp(tester, initial: null);
      await open(tester, '/admin');

      repository.report(AdminSession.signedOut);
      await settle(tester);

      expectOnly(AdminLoginScreen);
    });

    testWidgets('the public app works while the session is unknown', (
      tester,
    ) async {
      await pumpApp(tester, initial: null);

      expect(find.byType(CatalogScreen), findsOneWidget);
      await tester.tap(find.text('Toyota Prius, 2019'));
      await settle(tester);
      expect(find.byType(CarDetailScreen), findsOneWidget);
      expectOnly(Null);
    });
  });

  group('signing in', () {
    testWidgets('a successful sign-in opens the admin page', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      await tester.enterText(
        find.widgetWithText(TextField, adminEmailLabel),
        'someone@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, adminPasswordLabel),
        'made-up-password-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, adminSignInButton));
      await settle(tester);

      expectOnly(AdminHomeScreen);
      expect(address(tester), '/admin');
      expect(find.text(adminHomeTitle), findsOneWidget);
      expect(find.text(adminHomeSignedIn), findsOneWidget);
      // The placeholder shows nothing personal.
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('an account without the claim sees the no-access page', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.sessionAfterSignIn = AdminSession.noAccess;
      await open(tester, '/admin/login');

      await tester.enterText(
        find.widgetWithText(TextField, adminEmailLabel),
        'someone@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, adminPasswordLabel),
        'made-up-password-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, adminSignInButton));
      await settle(tester);

      expectOnly(AdminNoAccessScreen);
      expect(find.text(adminNoAccessText), findsOneWidget);
      expect(find.text(adminHomeSignedIn), findsNothing);
    });

    testWidgets('an admin who opens the login page goes on to "from"', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/login?from=%2Fadmin');
      expectOnly(AdminHomeScreen);

      await open(tester, '/admin/checking');
      expectOnly(AdminHomeScreen);
      expect(address(tester), '/admin');
    });
  });

  group('signing out', () {
    testWidgets('Sign out on the admin page leads to the login page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin');
      expectOnly(AdminHomeScreen);

      await tester.tap(find.widgetWithText(FilledButton, adminSignOutButton));
      await settle(tester);

      expect(repository.signOuts, 1);
      expectOnly(AdminLoginScreen);
      expect(find.text(adminHomeSignedIn), findsNothing);
    });

    testWidgets('Sign out on the no-access page leads to the login page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.noAccess);
      await open(tester, '/admin');
      expectOnly(AdminNoAccessScreen);

      await tester.tap(find.widgetWithText(FilledButton, adminSignOutButton));
      await settle(tester);

      expect(repository.signOuts, 1);
      expectOnly(AdminLoginScreen);
    });

    testWidgets('a session that ends by itself closes the admin page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin');

      // For example: the claim was removed and the token was renewed.
      repository.report(AdminSession.noAccess);
      await settle(tester);
      expectOnly(AdminNoAccessScreen);

      repository.report(AdminSession.signedOut);
      await settle(tester);
      expectOnly(AdminLoginScreen);
    });
  });

  group('the public app', () {
    for (final session in AdminSession.values) {
      testWidgets('is unchanged when the session is ${session.name}', (
        tester,
      ) async {
        await pumpApp(
          tester,
          initial: session == AdminSession.unknown ? null : session,
        );

        expect(find.byType(CatalogScreen), findsOneWidget);
        expect(address(tester), '/');

        await open(tester, '/cars/car-1');
        expect(find.byType(CarDetailScreen), findsOneWidget);
        expect(address(tester), '/cars/car-1');
        expectOnly(Null);
      });
    }

    testWidgets('a session change does not move a public visitor', (
      tester,
    ) async {
      await pumpApp(tester, initial: null);
      await open(tester, '/cars/car-1');

      for (final session in [
        AdminSession.signedOut,
        AdminSession.admin,
        AdminSession.noAccess,
      ]) {
        repository.report(session);
        await settle(tester);
        expect(find.byType(CarDetailScreen), findsOneWidget);
        expect(address(tester), '/cars/car-1');
      }
    });
  });

  group('the logo of the catalog', () {
    testWidgets('a long press opens the login page', (tester) async {
      await pumpApp(tester);

      await tester.longPress(find.byType(AppBarLogo));
      await settle(tester);

      expectOnly(AdminLoginScreen);
      expect(address(tester), '/admin/login');
    });

    testWidgets('a tap does nothing', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byType(AppBarLogo));
      await settle(tester);

      expectOnly(Null);
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(address(tester), '/');
    });

    testWidgets('a long press by an admin opens the admin page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);

      await tester.longPress(find.byType(AppBarLogo));
      await settle(tester);

      expectOnly(AdminHomeScreen);
    });

    testWidgets('gives no hint: no tooltip and no long-press action for '
        'screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      expect(
        find.ancestor(
          of: find.byType(AppBarLogo),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      final node = tester.getSemantics(find.byType(AppBarLogo));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        false,
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), false);
      handle.dispose();
    });

    testWidgets('the logo of the car screen has no long press', (tester) async {
      await pumpApp(tester);
      await open(tester, '/cars/car-1');

      await tester.longPress(find.byType(AppBarLogo));
      await settle(tester);

      expect(find.byType(CarDetailScreen), findsOneWidget);
      expectOnly(Null);
    });
  });
}
