import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The UTC moment of a Tbilisi date and time in 2026.
DateTime tb(int month, int day, [int hour = 0]) =>
    TbilisiDateTime(2026, month, day, hour).toUtc();

/// A made-up confirmed booking of [carId] from 18 Oct 10:00 to 20 Oct
/// 18:00 Tbilisi time, unless said otherwise.
RawBookingDocument confirmed(
  String id, {
  String carId = 'car-a',
  DateTime? pickup,
  DateTime? dropoff,
}) => rawBooking(
  id,
  carId: carId,
  status: 'confirmed',
  pickup: pickup ?? tb(10, 18, 10),
  dropoff: dropoff ?? tb(10, 20, 18),
);

final carA = (id: 'car-a', data: rawCar(brand: 'Kia'));
final carB = (id: 'car-b', data: rawCar(brand: 'Audi'));

/// These tests build no widgets. They use testWidgets only for its clock:
/// time passes when the test says so, and a timer that is still running at
/// the end fails the test.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.fleet, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeFleetRepository fleet;
  final FakeAdminAuthRepository auth;

  /// 12:00 on 16 Oct 2026 in Tbilisi.
  DateTime now = DateTime.utc(2026, 10, 16, 8);

  AdminCalendarState get state => container.read(adminCalendarProvider);

  AdminCalendarNotifier get notifier =>
      container.read(adminCalendarProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> elapse(Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
  }

  Future<void> emitBookings(
    List<RawBookingDocument> documents, {
    bool fromCache = false,
  }) async {
    bookings.emitConfirmed(documents, fromCache: fromCache);
    await flush();
  }

  Future<void> emitCars(
    List<FleetRawDocument> documents, {
    bool fromCache = false,
  }) async {
    fleet.emit(documents, fromCache: fromCache);
    await flush();
  }

  /// Both reads answered by the server.
  Future<void> ready({
    List<RawBookingDocument>? bookings,
    List<FleetRawDocument>? cars,
  }) async {
    await emitBookings(bookings ?? [confirmed('b1')]);
    await emitCars(cars ?? [carA]);
  }

  List<String?> get drawnIds => [
    for (final row in state.rows)
      for (final lane in row.lanes)
        for (final bar in lane) bar.booking.id,
  ];
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository();
  final fleet = FakeFleetRepository();
  late final Harness harness;
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      fleetRepositoryProvider.overrideWithValue(fleet),
      clockProvider.overrideWithValue(() => harness.now),
    ],
  );
  harness = Harness(tester, container, bookings, fleet, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await harness.flush();
  final subscription = container.listen(adminCalendarProvider, (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, nothing read', (
        tester,
      ) async {
        final h = await start(tester, session: session);
        expect(h.state.status, AdminCalendarStatus.inactive);
        expect(h.bookings.confirmedWatches, 0);
        expect(h.fleet.queries, 0);
        expect(h.bookings.limits, isEmpty);
      });
    }

    testWidgets('admin: loading, with one listener for the bookings and one '
        'for the cars, from today', (tester) async {
      final h = await start(tester);
      expect(h.state.status, AdminCalendarStatus.loading);
      expect(h.bookings.activeConfirmedListeners, 1);
      expect(h.fleet.activeListeners, 1);
      expect(h.bookings.limits, isEmpty);
      expect(h.state.window.first, CalendarDay(2026, 10, 16));
      expect(h.state.rows, isEmpty);
    });

    testWidgets('a sign-out closes both listeners', (tester) async {
      final h = await start(tester);
      await h.ready();
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.inactive);
      expect(h.state.rows, isEmpty);
      expect(h.bookings.activeConfirmedListeners, 0);
      expect(h.fleet.activeListeners, 0);
    });

    testWidgets('stop() closes both listeners and forgets the data', (
      tester,
    ) async {
      final h = await start(tester);
      await h.ready();
      h.notifier.stop();
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.inactive);
      expect(h.state.bookings, isEmpty);
      expect(h.state.cars, isEmpty);
      expect(h.bookings.activeConfirmedListeners, 0);
      expect(h.fleet.activeListeners, 0);
    });
  });

  group('the grid needs a server answer of both reads', () {
    testWidgets('bookings first, then the cars', (tester) async {
      final h = await start(tester);
      await h.emitBookings([confirmed('b1')]);
      expect(h.state.status, AdminCalendarStatus.loading);
      await h.emitCars([carA]);
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.state.rows.map((row) => row.carId), ['car-a']);
      expect(h.drawnIds, ['b1']);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('cars first, then the bookings', (tester) async {
      final h = await start(tester);
      await h.emitCars([carA, carB]);
      expect(h.state.status, AdminCalendarStatus.loading);
      await h.emitBookings([confirmed('b1')]);
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.state.rows.map((row) => row.carId), ['car-b', 'car-a']);
    });

    testWidgets('empty answers of the server: ready, with no bookings', (
      tester,
    ) async {
      final h = await start(tester);
      await h.ready(bookings: [], cars: []);
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.state.rows, isEmpty);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCalendarStatus.ready);
    });

    testWidgets('answers from memory, also NOT empty, are ignored: loading, '
        'then "no connection", never an empty grid', (tester) async {
      final h = await start(tester);
      await h.emitBookings([confirmed('b1')], fromCache: true);
      await h.emitCars([carA], fromCache: true);
      expect(h.state.status, AdminCalendarStatus.loading);
      expect(h.state.rows, isEmpty);
      expect(h.state.bookings, isEmpty);

      await h.elapse(serverAnswerWait - const Duration(milliseconds: 1));
      expect(h.state.status, AdminCalendarStatus.loading);
      await h.elapse(const Duration(milliseconds: 1));
      expect(h.state.status, AdminCalendarStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.noConnection);
      expect(h.state.rows, isEmpty);
      // The listeners stay open.
      expect(h.bookings.activeConfirmedListeners, 1);
      expect(h.fleet.activeListeners, 1);
    });

    testWidgets('after "no connection" the server answers: the grid appears '
        'by itself', (tester) async {
      final h = await start(tester);
      await h.emitBookings([], fromCache: true);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCalendarStatus.failed);

      await h.ready();
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.drawnIds, ['b1']);
      expect(h.state.failure, isNull);
    });

    testWidgets('the bookings from the server, the cars only from memory: '
        'still "no connection"', (tester) async {
      final h = await start(tester);
      await h.emitBookings([confirmed('b1')]);
      await h.emitCars([carA], fromCache: true);
      expect(h.state.status, AdminCalendarStatus.loading);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCalendarStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.noConnection);

      await h.emitCars([carA]);
      expect(h.state.status, AdminCalendarStatus.ready);
    });

    testWidgets('the cars from the server, the bookings only from memory: '
        'still "no connection"', (tester) async {
      final h = await start(tester);
      await h.emitCars([carA]);
      await h.emitBookings([confirmed('b1')], fromCache: true);
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCalendarStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.noConnection);
    });

    testWidgets('a server answer within the wait: no failure later', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emitBookings([confirmed('b1')], fromCache: true);
      await h.elapse(const Duration(seconds: 1));
      await h.ready();
      await h.elapse(serverAnswerWait);
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('a second answer from memory does not restart the wait', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emitBookings([], fromCache: true);
      await h.elapse(const Duration(seconds: 2));
      await h.emitCars([], fromCache: true);
      await h.elapse(const Duration(seconds: 1));
      expect(h.state.status, AdminCalendarStatus.failed);
    });
  });

  group('errors', () {
    testWidgets('the bookings are refused: no access, both listeners '
        'closed', (tester) async {
      final h = await start(tester);
      h.bookings.failConfirmed(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.permissionDenied);
      expect(h.bookings.activeConfirmedListeners, 0);
      expect(h.fleet.activeListeners, 0);
    });

    for (final (error, failure) in [
      (
        const FleetLoadException(FleetLoadFailure.permissionDenied),
        AdminBookingsFailure.permissionDenied,
      ),
      (
        const FleetLoadException(FleetLoadFailure.noConnection),
        AdminBookingsFailure.noConnection,
      ),
      (
        const FleetLoadException(FleetLoadFailure.other),
        AdminBookingsFailure.other,
      ),
    ]) {
      testWidgets('the cars fail with ${error.failure.name}: '
          '${failure.name}', (tester) async {
        final h = await start(tester);
        h.fleet.fail(error);
        await h.flush();
        expect(h.state.status, AdminCalendarStatus.failed);
        expect(h.state.failure, failure);
        expect(h.fleet.activeListeners, 0);
        expect(h.bookings.activeConfirmedListeners, 0);
      });
    }

    testWidgets('an unknown error: other', (tester) async {
      final h = await start(tester);
      h.bookings.failConfirmed(StateError('made up'));
      await h.flush();
      expect(h.state.failure, AdminBookingsFailure.other);
    });

    testWidgets('an error after the grid was shown: failed, the data is '
        'gone', (tester) async {
      final h = await start(tester);
      await h.ready();
      h.bookings.failConfirmed(
        const AdminBookingsException(AdminBookingsFailure.other),
      );
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.failed);
      expect(h.state.rows, isEmpty);
    });

    testWidgets('an error while signed out is not shown', (tester) async {
      final h = await start(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      // The listeners were closed; a late error of the first one changes
      // nothing.
      expect(h.state.status, AdminCalendarStatus.inactive);
      expect(h.state.failure, isNull);
    });

    testWidgets('retry starts both listeners again, from loading', (
      tester,
    ) async {
      final h = await start(tester);
      h.bookings.failConfirmed(
        const AdminBookingsException(AdminBookingsFailure.other),
      );
      await h.flush();
      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.loading);
      expect(h.bookings.confirmedWatches, 2);
      expect(h.fleet.queries, 2);
      expect(h.bookings.activeConfirmedListeners, 1);
      expect(h.fleet.activeListeners, 1);

      await h.ready();
      expect(h.state.status, AdminCalendarStatus.ready);
    });

    testWidgets('retry after "no connection" also works', (tester) async {
      final h = await start(tester);
      await h.emitBookings([], fromCache: true);
      await h.elapse(serverAnswerWait);
      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.loading);
      expect(h.bookings.activeConfirmedListeners, 1);
      expect(h.bookings.confirmedWatches, 2);
      await h.ready();
      expect(h.state.status, AdminCalendarStatus.ready);
    });

    testWidgets('retry while not an admin does nothing', (tester) async {
      final h = await start(tester, session: AdminSession.signedOut);
      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminCalendarStatus.inactive);
      expect(h.bookings.confirmedWatches, 0);
    });
  });

  group('offline after the grid was shown', () {
    testWidgets('bookings from memory: the grid stays, the note after the '
        'delay; the server takes it away', (tester) async {
      final h = await start(tester);
      await h.ready();
      await h.emitBookings([confirmed('b1')], fromCache: true);
      expect(h.state.status, AdminCalendarStatus.ready);
      expect(h.drawnIds, ['b1']);
      expect(h.state.showOfflineNote, isFalse);

      await h.elapse(offlineNoteDelay);
      expect(h.state.showOfflineNote, isTrue);
      expect(h.drawnIds, ['b1']);

      await h.emitBookings([confirmed('b1')]);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('cars from memory: the note too', (tester) async {
      final h = await start(tester);
      await h.ready();
      await h.emitCars([carA], fromCache: true);
      await h.elapse(offlineNoteDelay);
      expect(h.state.showOfflineNote, isTrue);
      await h.emitCars([carA]);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('only when both answers come from the server again', (
      tester,
    ) async {
      final h = await start(tester);
      await h.ready();
      await h.emitBookings([confirmed('b1')], fromCache: true);
      await h.emitCars([carA], fromCache: true);
      await h.elapse(offlineNoteDelay);
      await h.emitBookings([confirmed('b1')]);
      expect(h.state.showOfflineNote, isTrue);
      await h.emitCars([carA]);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('a short spell from memory shows no note', (tester) async {
      final h = await start(tester);
      await h.ready();
      await h.emitBookings([confirmed('b1')], fromCache: true);
      await h.elapse(const Duration(seconds: 1));
      await h.emitBookings([confirmed('b1')]);
      await h.elapse(offlineNoteDelay);
      expect(h.state.showOfflineNote, isFalse);
    });

    testWidgets('an empty answer from memory keeps what is shown', (
      tester,
    ) async {
      final h = await start(tester);
      await h.ready();
      await h.emitBookings([], fromCache: true);
      await h.emitCars([], fromCache: true);
      expect(h.drawnIds, ['b1']);
      expect(h.state.rows.map((row) => row.carId), ['car-a']);
      await h.elapse(offlineNoteDelay);
      expect(h.state.showOfflineNote, isTrue);
    });
  });

  group('the data', () {
    testWidgets('a new answer of the server is drawn: a booking confirmed '
        'elsewhere appears', (tester) async {
      final h = await start(tester);
      await h.ready();
      await h.emitBookings([
        confirmed('b1'),
        confirmed('b2', pickup: tb(10, 22, 10), dropoff: tb(10, 23, 10)),
      ]);
      expect(h.drawnIds, unorderedEquals(['b1', 'b2']));
    });

    testWidgets('unreadable booking documents are counted, not drawn', (
      tester,
    ) async {
      final h = await start(tester);
      final broken = rawBooking(
        'bad',
        status: 'confirmed',
        changes: {'carId': 7},
      );
      await h.ready(bookings: [confirmed('b1'), broken]);
      expect(h.state.unreadable, 1);
      expect(h.drawnIds, ['b1']);
      expect(h.state.bookings.map((b) => b.id), ['b1']);
    });

    testWidgets('a car document that cannot be read: its booking is in an '
        'unknown row', (tester) async {
      final h = await start(tester);
      await h.ready(
        bookings: [confirmed('b1', carId: 'car-x')],
        cars: [
          carA,
          (id: 'car-x', data: <String, dynamic>{'brand': 3}),
        ],
      );
      expect(h.state.rows.map((row) => row.carId), ['car-a', 'car-x']);
      expect(h.state.rows.last.car, isNull);
    });

    testWidgets('a hidden car: a row only with a booking in the window', (
      tester,
    ) async {
      final h = await start(tester);
      final hidden = (id: 'car-h', data: rawCar(brand: 'Audi', active: false));
      await h.ready(
        bookings: [confirmed('b1', carId: 'car-h')],
        cars: [carA, hidden],
      );
      expect(h.state.rows.map((row) => row.carId), ['car-a', 'car-h']);
      expect(h.state.rows.last.hidden, isTrue);

      await h.emitBookings([]);
      expect(h.state.rows.map((row) => row.carId), ['car-a']);
    });
  });

  group('the window', () {
    testWidgets('next, previous and today; the rows follow', (tester) async {
      final h = await start(tester);
      final later = confirmed(
        'later',
        pickup: tb(11, 3, 10),
        dropoff: tb(11, 4, 10),
      );
      await h.ready(bookings: [confirmed('b1'), later]);
      expect(h.drawnIds, ['b1']);

      h.notifier.showNext();
      expect(h.state.window.first, CalendarDay(2026, 10, 23));
      expect(h.drawnIds, ['later']);

      h.notifier.showNext();
      expect(h.state.window.first, CalendarDay(2026, 10, 30));
      expect(h.drawnIds, ['later']);

      h.notifier.showPrevious();
      h.notifier.showPrevious();
      h.notifier.showPrevious();
      expect(h.state.window.first, CalendarDay(2026, 10, 9));
      expect(h.drawnIds, ['b1']);

      h.notifier.showToday();
      expect(h.state.window.first, CalendarDay(2026, 10, 16));
    });

    testWidgets('a new answer keeps the window', (tester) async {
      final h = await start(tester);
      await h.ready();
      h.notifier.showNext();
      await h.emitBookings([confirmed('b1')]);
      expect(h.state.window.first, CalendarDay(2026, 10, 23));
    });

    testWidgets('the window can move while loading; the grid then opens '
        'there', (tester) async {
      final h = await start(tester);
      h.notifier.showNext();
      expect(h.state.status, AdminCalendarStatus.loading);
      expect(h.state.rows, isEmpty);
      await h.ready(
        bookings: [
          confirmed('b1'),
          confirmed('b2', pickup: tb(10, 25, 10), dropoff: tb(10, 26, 10)),
        ],
      );
      expect(h.state.window.first, CalendarDay(2026, 10, 23));
      expect(h.drawnIds, ['b2']);
    });

    testWidgets('today is the Tbilisi date: 20:00 UTC is the next day', (
      tester,
    ) async {
      final h = await start(tester);
      h.now = DateTime.utc(2026, 10, 16, 20);
      h.notifier.showToday();
      expect(h.state.window.first, CalendarDay(2026, 10, 17));
    });
  });
}
