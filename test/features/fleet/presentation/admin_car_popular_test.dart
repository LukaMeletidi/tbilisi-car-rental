import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_card.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_fields.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

const carId = 'car-1';
const listText = 'The fleet list';

late FakeFleetRepository fleet;
final now = DateTime.utc(2026, 10, 14, 12);

/// A stand-in for the admin list below the forms: it keeps the live list
/// of all cars alive, as the real Cars page does.
class _ListPage extends ConsumerWidget {
  const _ListPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminCarsProvider);
    return const Scaffold(body: Text(listText));
  }
}

/// A form at its real address, opened from the stand-in for the list, as
/// the admin opens it. The list first answers with [list].
Future<void> pumpForm(
  WidgetTester tester,
  String location, {
  List<FleetRawDocument> list = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  fleet = FakeFleetRepository();
  final router = GoRouter(
    initialLocation: AppRoutes.adminCars,
    routes: [
      GoRoute(
        path: AppRoutes.adminCars,
        builder: (context, state) => const _ListPage(),
        routes: [
          GoRoute(
            path: AppRoutes.adminCarNewPattern,
            builder: (context, state) => const AdminCarNewScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminCarEditPattern,
            builder: (context, state) =>
                AdminCarEditScreen(carId: state.pathParameters['carId']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        fleetRepositoryProvider.overrideWithValue(fleet),
        adminBookingsRepositoryProvider.overrideWithValue(
          FakeAdminBookingsRepository(),
        ),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);
  fleet.emit(list);
  await settle(tester);
  router.go(location);
  await settle(tester);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The edit form's car answers with [data].
Future<void> emitCar(WidgetTester tester, Map<String, dynamic> data) async {
  fleet.emitCar(carId, data);
  await settle(tester);
}

FleetRawDocument doc(String id, {bool active = true, bool popular = true}) => (
  id: id,
  data: rawCar(
    active: active,
    change: (d) {
      if (popular) d['popular'] = true;
    },
  ),
);

Finder get checkbox => find.byKey(adminCarPopularKey);

bool ticked(WidgetTester tester) =>
    tester.widget<CheckboxListTile>(checkbox).value ?? false;

Future<void> tapCheckbox(WidgetTester tester) async {
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await settle(tester);
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, adminSave));

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, adminSave);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await settle(tester);
}

/// The contrast ratio of two colours (WCAG).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('the edit form', () {
    testWidgets('a car without the mark: unticked, the note, Save disabled', (
      tester,
    ) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar());
      expect(ticked(tester), false);
      expect(find.text(adminCarLabelPopular), findsOneWidget);
      expect(find.text(adminCarPopularNote), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a tick enables Save; Save sends popular true', (tester) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar());
      await tapCheckbox(tester);
      expect(ticked(tester), true);
      expect(saveButton(tester).onPressed, isNotNull);

      await tapSave(tester);
      final saved = fleet.replaced.single.car;
      expect(saved.popular, true);
      expect(saved.toMap()['popular'], true);
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('a tick and an untick: no change, Save disabled again', (
      tester,
    ) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar());
      await tapCheckbox(tester);
      await tapCheckbox(tester);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a marked car opens ticked, without "Needs repair"; an '
        'untick and Save send the car without the key', (tester) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar(change: (d) => d['popular'] = true));
      expect(ticked(tester), true);
      expect(find.text(adminCarRepairNote), findsNothing);

      await tapCheckbox(tester);
      await tapSave(tester);
      final saved = fleet.replaced.single.car;
      expect(saved.popular, false);
      expect(saved.toMap().containsKey('popular'), false);
    });

    testWidgets('a stored false: unticked, no "Needs repair", Save disabled', (
      tester,
    ) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar(change: (d) => d['popular'] = false));
      expect(ticked(tester), false);
      expect(find.text(adminCarRepairNote), findsNothing);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a stored non-bool: "Needs repair"; one save drops it', (
      tester,
    ) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar(change: (d) => d['popular'] = 'true'));
      expect(ticked(tester), false);
      expect(find.text(adminCarRepairNote), findsOneWidget);

      await tapSave(tester);
      expect(fleet.replaced.single.car.toMap().containsKey('popular'), false);
    });

    testWidgets('a tick and Back: the discard question', (tester) async {
      await pumpForm(tester, AppRoutes.adminCarEdit(carId));
      await emitCar(tester, rawCar());
      await tapCheckbox(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);
    });
  });

  group('the soft warning', () {
    testWidgets('3 other visible marked cars: shown when ticked, never '
        'blocking', (tester) async {
      await pumpForm(
        tester,
        AppRoutes.adminCarEdit(carId),
        list: [doc(carId, popular: false), doc('a'), doc('b'), doc('c')],
      );
      await emitCar(tester, rawCar());
      final warning = adminCarPopularTooMany(3);
      expect(find.text(warning), findsNothing);

      await tapCheckbox(tester);
      expect(find.text(warning), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
      await tapSave(tester);
      expect(fleet.replaced.single.car.popular, true);
    });

    testWidgets('2 others, or hidden ones: no warning', (tester) async {
      await pumpForm(
        tester,
        AppRoutes.adminCarEdit(carId),
        list: [
          doc(carId, popular: false),
          doc('a'),
          doc('b'),
          doc('c', active: false),
          doc('d', active: false),
        ],
      );
      await emitCar(tester, rawCar());
      await tapCheckbox(tester);
      expect(find.textContaining('already marked popular'), findsNothing);
    });

    testWidgets('the car in the form does not count itself', (tester) async {
      await pumpForm(
        tester,
        AppRoutes.adminCarEdit(carId),
        list: [doc(carId), doc('a'), doc('b')],
      );
      await emitCar(tester, rawCar(change: (d) => d['popular'] = true));
      expect(find.textContaining('already marked popular'), findsNothing);
    });
  });

  group('the new-car form', () {
    testWidgets('starts unticked', (tester) async {
      await pumpForm(tester, AppRoutes.adminCarNew);
      expect(ticked(tester), false);
      expect(find.text(adminCarPopularNote), findsOneWidget);
    });

    testWidgets('ticked, the warning with 3 other visible marked cars', (
      tester,
    ) async {
      await pumpForm(
        tester,
        AppRoutes.adminCarNew,
        list: [doc('a'), doc('b'), doc('c')],
      );
      await tapCheckbox(tester);
      expect(ticked(tester), true);
      expect(find.text(adminCarPopularTooMany(3)), findsOneWidget);
    });
  });

  group('the card of the admin list', () {
    Future<void> pumpCard(WidgetTester tester, {required bool popular}) async {
      final car = Car.fromMap(
        carId,
        rawCar(change: (d) => popular ? d['popular'] = true : null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AdminCarCard(entry: FleetCarEntry(car, needsRepair: false)),
          ),
        ),
      );
    }

    testWidgets('a marked car shows the "Popular" badge', (tester) async {
      await pumpCard(tester, popular: true);
      expect(find.text(adminCarBadgePopular), findsOneWidget);
    });

    testWidgets('an unmarked car shows none', (tester) async {
      await pumpCard(tester, popular: false);
      expect(find.text(adminCarBadgePopular), findsNothing);
    });
  });

  testWidgets('every text on the cards of the car form is readable', (
    tester,
  ) async {
    await pumpForm(
      tester,
      AppRoutes.adminCarEdit(carId),
      list: [doc('a'), doc('b'), doc('c')],
    );
    await emitCar(tester, rawCar());
    await tapCheckbox(tester);
    expect(find.text(adminCarPopularTooMany(3)), findsOneWidget);
    final cards = find.byType(Card);
    expect(cards, findsWidgets);
    for (final card in cards.evaluate()) {
      final background = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byWidget(card.widget),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      final paragraphs = find.descendant(
        of: find.byWidget(card.widget),
        matching: find.byType(RichText),
      );
      for (final element in paragraphs.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final color = paragraph.text.style!.color!;
        expect(
          contrast(color, background),
          greaterThanOrEqualTo(4.5),
          reason: '"${paragraph.text.toPlainText()}" is $color on $background',
        );
      }
    }
  });
}
