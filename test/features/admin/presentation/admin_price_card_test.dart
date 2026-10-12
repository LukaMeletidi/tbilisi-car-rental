import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_price_card.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// The choices that were tapped.
final chosen = <AdminTotalChoice>[];

Future<void> pumpCard(
  WidgetTester tester,
  AdminTotalComparison totals, {
  AdminTotalChoice? choice,
  bool enabled = true,
  double width = 600,
}) async {
  chosen.clear();
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: AppCard(
          child: AdminPriceCard(
            totals: totals,
            choice: choice,
            enabled: enabled,
            onChoose: chosen.add,
          ),
        ),
      ),
    ),
  );
}

/// Stored: 5 days, 225. New: [days] days and [totalCents].
AdminTotalComparison totals({
  bool changed = true,
  int? days = 7,
  int totalCents = 36050,
  double? carPerDay = 45,
  double? extrasPerDay = 6.5,
}) => AdminTotalComparison(
  storedCents: 22500,
  storedDays: 5,
  priceFieldsChanged: changed,
  newPrice: days == null
      ? null
      : RentalPrice(days: days, totalCents: totalCents),
  carPricePerDay: carPerDay,
  extrasPerDay: extrasPerDay,
);

const keep = 'Keep the stored total (\$225)';
const choose = 'Choose which total to save.';

void main() {
  testWidgets('nothing the price depends on changed: only the stored total', (
    tester,
  ) async {
    await pumpCard(tester, totals(changed: false));

    expect(find.text('Stored total: 5 days · \$225'), findsOneWidget);
    expect(find.text(adminTotalStays), findsOneWidget);
    expect(find.textContaining('New total'), findsNothing);
    expect(find.text(keep), findsNothing);
    expect(find.text(choose), findsNothing);
  });

  testWidgets('a new total that differs: both totals, the note about '
      'today\'s prices, two choices, none selected', (tester) async {
    await pumpCard(tester, totals());

    expect(find.text('Stored total: 5 days · \$225'), findsOneWidget);
    expect(
      find.text('New total: 7 days × (\$45 car + \$6.50 extras) = \$360.50'),
      findsOneWidget,
    );
    expect(find.text("The new total uses today's prices."), findsOneWidget);
    expect(find.text(keep), findsOneWidget);
    expect(find.text('Use the new total (\$360.50)'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.text(choose), findsOneWidget);
  });

  testWidgets('a tap reports the choice; the chosen one is marked and the '
      'request to choose goes away', (tester) async {
    await pumpCard(tester, totals());
    await tester.tap(find.text('Use the new total (\$360.50)'));
    await tester.tap(find.text(keep));
    expect(chosen, [AdminTotalChoice.useNew, AdminTotalChoice.keepStored]);

    await pumpCard(tester, totals(), choice: AdminTotalChoice.useNew);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.text(choose), findsNothing);
  });

  testWidgets('more than 7 days: the new total is marked as an estimate', (
    tester,
  ) async {
    await pumpCard(tester, totals(days: 10, totalCents: 51500));

    expect(
      find.text(
        'New total: 10 days × (\$45 car + \$6.50 extras) = \$515 · estimate',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the new total equals the stored one: no choice', (tester) async {
    await pumpCard(tester, totals(days: 5, totalCents: 22500));

    expect(find.textContaining('New total: 5 days'), findsOneWidget);
    expect(find.text(adminTotalStays), findsOneWidget);
    expect(find.text(keep), findsNothing);
    expect(find.text(choose), findsNothing);
  });

  testWidgets('prices not loaded: the reason, and only "Keep"', (tester) async {
    await pumpCard(
      tester,
      totals(days: null, carPerDay: null, extrasPerDay: null),
    );

    expect(find.text(adminNewTotalNoPrices), findsOneWidget);
    expect(find.text(keep), findsOneWidget);
    expect(find.textContaining('Use the new total'), findsNothing);
    expect(find.text(choose), findsOneWidget);
  });

  testWidgets('dates that cannot be priced: said so, and only "Keep"', (
    tester,
  ) async {
    await pumpCard(tester, totals(days: null));

    expect(find.text(adminNewTotalNoDates), findsOneWidget);
    expect(find.text(keep), findsOneWidget);
    expect(find.textContaining('Use the new total'), findsNothing);
  });

  testWidgets('a new total above the highest total: "Use the new total" '
      'cannot be tapped, and the reason is given', (tester) async {
    await pumpCard(tester, totals(days: 365, totalCents: 109500000));

    await tester.tap(find.textContaining('Use the new total'));
    expect(chosen, isEmpty);
    expect(find.text('The new total is too high to be saved.'), findsOneWidget);

    await tester.tap(find.text(keep));
    expect(chosen, [AdminTotalChoice.keepStored]);
  });

  testWidgets('while a save is running nothing can be chosen', (tester) async {
    await pumpCard(tester, totals(), enabled: false);

    await tester.tap(find.text(keep));
    await tester.tap(find.text('Use the new total (\$360.50)'));

    expect(chosen, isEmpty);
  });

  testWidgets('the text is dark on the white card and fits 280 wide', (
    tester,
  ) async {
    await pumpCard(tester, totals(), width: 280);

    final text = tester.renderObject<RenderParagraph>(find.text(keep));
    expect(text.text.style!.color!.computeLuminance(), lessThan(0.3));
    expect(tester.takeException(), isNull);
  });
}
