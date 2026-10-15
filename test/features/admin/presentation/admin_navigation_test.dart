import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

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
late FakeAdminBookingsRepository bookingsRepository;

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
  bookingsRepository = FakeAdminBookingsRepository();
  addTearDown(repository.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(repository),
        adminBookingsRepositoryProvider.overrideWithValue(bookingsRepository),
        // The Cars section reads the fleet; this keeps Firebase out.
        fleetRepositoryProvider.overrideWithValue(FakeFleetRepository()),
        activeCarsProvider.overrideWith((ref) => Stream.value([car])),
        carProvider.overrideWith((ref, id) => Stream.value(car)),
        // The booking detail looks the names of the places up.
        pickupLocationsProvider.overrideWith((ref) => Stream.value(const [])),
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
    AdminBookingsScreen,
    AdminBookingDetailScreen,
    AdminBookingEditScreen,
    AdminNotFoundScreen,
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
      expect(bookingsRepository.activeListeners, 0);
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
      expect(bookingsRepository.activeListeners, 0);
    });

    testWidgets('then an admin lands on the admin page', (tester) async {
      await pumpApp(tester, initial: null);
      await open(tester, '/admin');

      repository.report(AdminSession.admin);
      await settle(tester);

      expectOnly(AdminBookingsScreen);
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

      expectOnly(AdminBookingsScreen);
      expect(address(tester), '/admin');
      // The list is asked for only now, by the admin.
      expect(bookingsRepository.limits, [50]);
      bookingsRepository.emit(const []);
      await settle(tester);
      expect(find.text(adminNoBookings), findsOneWidget);
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
      expect(bookingsRepository.activeListeners, 0);
    });

    testWidgets('an admin who opens the login page goes on to "from"', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/login?from=%2Fadmin');
      expectOnly(AdminBookingsScreen);

      await open(tester, '/admin/checking');
      expectOnly(AdminBookingsScreen);
      expect(address(tester), '/admin');
    });
  });

  group('signing out', () {
    testWidgets('Sign out on the admin page leads to the login page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin');
      expectOnly(AdminBookingsScreen);
      expect(bookingsRepository.activeListeners, 1);

      // On the bookings page Sign out is the icon in the app bar.
      await tester.tap(find.byTooltip(adminSignOutButton));
      await settle(tester);

      expect(repository.signOuts, 1);
      expectOnly(AdminLoginScreen);
      expect(bookingsRepository.activeListeners, 0);
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

      expectOnly(AdminBookingsScreen);
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

  group('the detail of a booking', () {
    testWidgets('a tap on a row opens it, and Back returns to the list', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin');
      bookingsRepository.emit([rawBooking('b1'), rawBooking('b2')]);
      await settle(tester);

      await tester.tap(find.text('Test Person').first);
      await settle(tester);

      // The list stays underneath; only the detail is on screen.
      expectOnly(AdminBookingDetailScreen);
      expect(address(tester), '/admin/bookings/b1');
      expect(bookingsRepository.watchedBookingIds, ['b1']);
      bookingsRepository.emitBooking(rawBooking('b1'));
      await settle(tester);
      expect(find.text(adminBookingTitle), findsOneWidget);
      expect(find.text(adminSectionStatus), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expectOnly(AdminBookingsScreen);
      expect(address(tester), '/admin');
      // The detail closed its listener; the list kept its own.
      expect(bookingsRepository.activeBookingListeners, 0);
      expect(bookingsRepository.activeListeners, 1);
      expect(bookingsRepository.limits, [50]);
    });

    testWidgets('"Back to the bookings" of a missing booking opens the list', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/bookings/gone');
      bookingsRepository.emitBooking(null);
      await settle(tester);
      expect(find.text(adminBookingMissing), findsOneWidget);

      await tester.tap(find.text(adminBackToBookings));
      await settle(tester);

      expectOnly(AdminBookingsScreen);
      expect(address(tester), '/admin');
    });

    testWidgets('its address opened directly by an admin shows it; the list '
        'underneath starts its listener too', (tester) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/bookings/b1');

      expectOnly(AdminBookingDetailScreen);
      expect(address(tester), '/admin/bookings/b1');
      expect(bookingsRepository.watchedBookingIds, ['b1']);
      // The accepted extra cost of a direct link: up to 50 reads.
      expect(bookingsRepository.limits, [50]);
    });

    testWidgets('signed out: the login page, and nothing is asked for; '
        'after the sign-in the admin lands on the booking', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/bookings/b1');

      expectOnly(AdminLoginScreen);
      expect(address(tester), '/admin/login?from=%2Fadmin%2Fbookings%2Fb1');
      expect(bookingsRepository.watchedBookingIds, isEmpty);
      expect(bookingsRepository.limits, isEmpty);

      repository.report(AdminSession.admin);
      await settle(tester);

      expectOnly(AdminBookingDetailScreen);
      expect(address(tester), '/admin/bookings/b1');
      expect(bookingsRepository.watchedBookingIds, ['b1']);
    });

    for (final session in [null, AdminSession.noAccess]) {
      testWidgets('${session?.name ?? 'unknown'}: never the booking, and '
          'nothing is asked for', (tester) async {
        await pumpApp(tester, initial: session);
        await open(tester, '/admin/bookings/b1');

        expectOnly(session == null ? AdminCheckingScreen : AdminNoAccessScreen);
        expect(bookingsRepository.watchedBookingIds, isEmpty);
        expect(bookingsRepository.limits, isEmpty);
      });
    }

    testWidgets('a session that ends while it is open closes it and both '
        'listeners', (tester) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/bookings/b1');
      bookingsRepository.emitBooking(rawBooking('b1'));
      await settle(tester);
      expect(find.text('Test Person'), findsOneWidget);

      repository.report(AdminSession.noAccess);
      await settle(tester);

      expectOnly(AdminNoAccessScreen);
      expect(find.text('Test Person'), findsNothing);
      expect(bookingsRepository.activeBookingListeners, 0);
      expect(bookingsRepository.activeListeners, 0);
    });

    testWidgets('an ID of an impossible shape in the address: "does not '
        'exist", and Firestore is not asked for it', (tester) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/bookings/a%20b');

      expectOnly(AdminBookingDetailScreen);
      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(bookingsRepository.watchedBookingIds, isEmpty);
    });

    testWidgets('"/admin/bookings" without an ID is "not found"', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/bookings');
      expectOnly(AdminNotFoundScreen);
    });
  });

  group('an address that does not exist', () {
    testWidgets('under /admin, an admin sees the admin "not found" page', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/admin/whatever');

      expectOnly(AdminNotFoundScreen);
      expect(find.text(adminNotFoundText), findsOneWidget);
      // No bookings are asked for on this page.
      expect(bookingsRepository.limits, isEmpty);

      await tester.tap(find.text(adminBackToBookings));
      await settle(tester);
      expectOnly(AdminBookingsScreen);
      expect(address(tester), '/admin');
    });

    testWidgets('under /admin, deeper addresses are "not found" as well', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      // "/admin/bookings/abc/edit" is the edit form since step 3.9b.
      await open(tester, '/admin/bookings/abc/edit/more');
      expectOnly(AdminNotFoundScreen);
      await open(tester, '/admin/bookings/abc/other');
      expectOnly(AdminNotFoundScreen);
    });

    testWidgets('under /admin, a visitor who is not an admin never sees it', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, '/admin/whatever');
      expectOnly(AdminLoginScreen);

      repository.report(AdminSession.noAccess);
      await settle(tester);
      expectOnly(AdminNoAccessScreen);
      expect(find.text(adminNotFoundText), findsNothing);
    });

    testWidgets('a visitor who signs in as admin on such an address lands on '
        'the "not found" page', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin/whatever');

      repository.report(AdminSession.admin);
      await settle(tester);

      expectOnly(AdminNotFoundScreen);
    });

    testWidgets('an unknown public address keeps the router\'s own screen', (
      tester,
    ) async {
      await pumpApp(tester, initial: AdminSession.admin);
      await open(tester, '/no-such-page');

      expectOnly(Null);
      expect(find.text(adminNotFoundText), findsNothing);
      expect(find.byType(CatalogScreen), findsNothing);
      expect(find.textContaining('Page Not Found'), findsOneWidget);
    });
  });
}
