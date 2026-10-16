import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/widgets/calendar_grid_view.dart';

import '../../../support/fake_admin_bookings_repository.dart';

DateTime tb(int month, int day, [int hour = 0]) =>
    TbilisiDateTime(2026, month, day, hour).toUtc();

Booking booking(
  String id,
  DateTime pickup,
  DateTime dropoff, {
  String carId = 'car-a',
}) => Booking.fromMap(
  id,
  rawBooking(
    id,
    carId: carId,
    pickup: pickup,
    dropoff: dropoff,
    status: 'confirmed',
    fullName: 'Made Up Name',
    phone: '+995555000123',
  ).data,
);

Car car(String id, String brand, {bool active = true}) => Car(
  id: id,
  brand: brand,
  model: 'Civic',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: const LocalizedText(),
  photos: const [],
  active: active,
);

final october16 = CalendarWindow(CalendarDay(2026, 10, 16));
final today = CalendarDay(2026, 10, 16);

late List<String> opened;

Future<void> pumpGrid(
  WidgetTester tester, {
  List<Car>? cars,
  List<Booking> bookings = const [],
  CalendarWindow? window,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  opened = [];
  final shown = window ?? october16;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CalendarGridView(
              window: shown,
              rows: calendarRows(
                cars: cars ?? [car('car-a', 'Honda')],
                bookings: bookings,
                window: shown,
              ),
              today: today,
              onOpenBooking: opened.add,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder bar(String id) => find.byKey(calendarBarKey(id));

Finder get daysScroll => find.descendant(
  of: find.byKey(calendarDaysScrollKey),
  matching: find.byType(Scrollable),
);

void main() {
  group('the day header', () {
    testWidgets('14 cells, today first and marked, with the full date for '
        'a screen reader', (tester) async {
      await pumpGrid(tester);
      for (var i = 0; i < calendarDayCount; i++) {
        expect(find.byKey(calendarDayKey(i)), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.byKey(calendarDayKey(0))),
        isSemantics(label: 'Friday 16 Oct 2026, today', isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(calendarDayKey(1))),
        isSemantics(label: 'Saturday 17 Oct 2026', isSelected: false),
      );
      expect(find.text('Fri'), findsNWidgets(2));
      expect(find.text('16 Oct'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('the 1st of a month names the month', (tester) async {
      await pumpGrid(tester, window: CalendarWindow(CalendarDay(2026, 10, 25)));
      expect(find.text('25 Oct'), findsOneWidget);
      expect(find.text('1 Nov'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(calendarDayKey(7))),
        isSemantics(label: 'Sunday 1 Nov 2026', isSelected: false),
      );
    });

    testWidgets('a window without today marks no day', (tester) async {
      await pumpGrid(tester, window: october16.next().next());
      for (var i = 0; i < calendarDayCount; i++) {
        final label = tester.getSemantics(find.byKey(calendarDayKey(i))).label;
        expect(label, isNot(contains('today')));
      }
    });
  });

  group('the rows', () {
    testWidgets('visible cars in order, a hidden car marked, an unknown car '
        'with its short ID', (tester) async {
      await pumpGrid(
        tester,
        cars: [
          car('car-k', 'Kia'),
          car('car-a', 'Audi'),
          car('car-h', 'BMW', active: false),
        ],
        bookings: [
          booking('b1', tb(10, 17, 10), tb(10, 18, 10), carId: 'car-h'),
          booking('b2', tb(10, 17, 10), tb(10, 18, 10), carId: 'abcdefghijkl'),
        ],
      );
      final tops = [
        for (final id in ['car-a', 'car-k', 'car-h', 'abcdefghijkl'])
          tester.getTopLeft(find.byKey(calendarCarKey(id))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('Audi Civic, 2019'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(calendarCarKey('car-h')),
          matching: find.text(adminCalendarHiddenCar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(calendarCarKey('abcdefghijkl')),
          matching: find.text(adminCalendarUnknownCar),
        ),
        findsOneWidget,
      );
      expect(find.text('abcdefgh…'), findsOneWidget);
    });

    testWidgets('the car column and the days line up, also with two lanes', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        cars: [car('car-a', 'Audi'), car('car-k', 'Kia')],
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 10)),
          booking('b', tb(10, 18, 18), tb(10, 20, 10)),
        ],
      );
      final name = find.byKey(calendarCarKey('car-a'));
      expect(tester.getSize(name).height, calendarRowHeight(2));
      final next = find.byKey(calendarCarKey('car-k'));
      expect(tester.getSize(next).height, calendarRowHeight(1));
      // Bar b sits in the second lane of the row of car-a.
      final rowTop = tester.getTopLeft(name).dy;
      expect(
        tester.getTopLeft(bar('b')).dy,
        rowTop + calendarRowPadding + calendarLaneHeight + 2,
      );
      expect(tester.getTopLeft(bar('a')).dy, rowTop + calendarRowPadding + 2);
    });
  });

  group('the bars', () {
    testWidgets('placed by time; the pickup time on the bar; the times in '
        'the tooltip and the label; no name or phone anywhere', (tester) async {
      await pumpGrid(
        tester,
        bookings: [booking('a', tb(10, 16, 12), tb(10, 18, 18))],
      );
      final day0 = tester.getRect(find.byKey(calendarDayKey(0)));
      final rect = tester.getRect(bar('a'));
      expect(rect.left, closeTo(day0.left + day0.width * 0.5, 0.01));
      expect(rect.right, closeTo(day0.left + day0.width * 2.75, 0.01));
      expect(
        find.descendant(of: bar('a'), matching: find.text('12:00')),
        findsOneWidget,
      );

      const label =
          'Confirmed booking, 16 Oct 2026 12:00 to 18 Oct 2026 18:00 '
          '(Tbilisi time). Opens the booking.';
      expect(find.byTooltip(label), findsOneWidget);
      expect(
        tester.getSemantics(bar('a')),
        isSemantics(label: label, isButton: true),
      );
      expect(find.textContaining('Made Up'), findsNothing);
      expect(find.textContaining('555'), findsNothing);
      expect(find.textContaining('example.com'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Made Up|555')), findsNothing);
    });

    testWidgets('a tap opens the booking', (tester) async {
      await pumpGrid(
        tester,
        bookings: [booking('a', tb(10, 16, 12), tb(10, 18, 18))],
      );
      await tester.tap(bar('a'));
      await tester.pump();
      expect(opened, ['a']);
    });

    testWidgets('two close bookings: two lanes, neither hidden, both marked', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 18)),
          booking('b', tb(10, 18, 21), tb(10, 20, 12)),
        ],
      );
      final a = tester.getRect(bar('a'));
      final b = tester.getRect(bar('b'));
      expect(a.overlaps(b), isFalse);
      expect(b.top, greaterThan(a.top));
      for (final id in ['a', 'b']) {
        expect(
          find.descendant(
            of: bar(id),
            matching: find.byIcon(Icons.warning_amber),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester.getSemantics(bar('b')),
        isSemantics(
          label:
              'Confirmed booking, 18 Oct 2026 21:00 to 20 Oct 2026 12:00 '
              '(Tbilisi time). Too close to another booking of this car. '
              'Opens the booking.',
        ),
      );
    });

    testWidgets('cut at both ends: chevrons, and no pickup time', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        bookings: [booking('long', tb(10, 10, 9), tb(11, 5, 9))],
      );
      expect(
        find.descendant(
          of: bar('long'),
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bar('long'),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar('long'), matching: find.text('09:00')),
        findsNothing,
      );
    });

    testWidgets('a very short booking is still wide enough to tap', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        bookings: [booking('short', tb(10, 29, 23), tb(10, 30))],
      );
      final rect = tester.getRect(bar('short'));
      expect(rect.width, calendarMinBarWidth);
      // Kept inside the last day.
      final last = tester.getRect(
        find.byKey(calendarDayKey(calendarDayCount - 1)),
      );
      expect(rect.right, lessThanOrEqualTo(last.right + 0.01));
      await tester.tap(bar('short'));
      expect(opened, ['short']);
    });
  });

  group('widths', () {
    testWidgets('1200 px: every day fits, no sideways scroll, no overflow', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        bookings: [booking('a', tb(10, 16, 10), tb(10, 18, 18))],
      );
      expect(tester.takeException(), isNull);
      final position = tester.state<ScrollableState>(daysScroll).position;
      expect(position.maxScrollExtent, 0);
      expect(
        tester.getSize(find.byKey(calendarDayKey(0))).width,
        greaterThan(calendarMinDayWidth),
      );
    });

    testWidgets('320 px: no overflow; the days scroll sideways and the car '
        'column stays', (tester) async {
      await pumpGrid(
        tester,
        size: const Size(320, 700),
        bookings: [
          booking('a', tb(10, 16, 10), tb(10, 18, 18)),
          booking('b', tb(10, 18, 21), tb(10, 20, 12)),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(calendarDayKey(0))).width,
        calendarMinDayWidth,
      );
      final position = tester.state<ScrollableState>(daysScroll).position;
      expect(position.maxScrollExtent, greaterThan(0));

      final nameBefore = tester.getTopLeft(find.byKey(calendarCarKey('car-a')));
      final dayBefore = tester.getTopLeft(find.byKey(calendarDayKey(0)));
      await tester.drag(
        find.byKey(calendarDaysScrollKey),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(calendarCarKey('car-a'))),
        nameBefore,
      );
      expect(
        tester.getTopLeft(find.byKey(calendarDayKey(0))).dx,
        lessThan(dayBefore.dx - 100),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
