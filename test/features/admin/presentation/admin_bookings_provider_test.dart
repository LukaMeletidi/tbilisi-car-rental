import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// These tests build no widgets. They use testWidgets only for its clock:
/// inside it, time passes when the test says so, and a test fails by
/// itself when a timer is still running at its end.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;

  /// The clock the provider reads; it moves with [elapse].
  DateTime now = DateTime.utc(2026, 10, 9, 12);

  AdminBookingsState get state => container.read(adminBookingsProvider);

  AdminBookingsNotifier get notifier =>
      container.read(adminBookingsProvider.notifier);

  /// Lets everything that is waiting run, without time passing. The zero
  /// duration matters: outside a widget tree Riverpod rebuilds a provider
  /// from a timer of length zero, and only this lets such timers fire.
  Future<void> flush() => tester.pump(Duration.zero);

  /// Lets [duration] pass.
  Future<void> elapse(Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
  }

  Future<void> emit(
    List<RawBookingDocument> documents, {
    bool fromCache = false,
  }) async {
    bookings.emit(documents, fromCache: fromCache);
    await flush();
  }
}

/// Starts with a fake auth repository in [session] and a fake bookings
/// repository. With [watch] the bookings provider is kept alive, as the
/// screen does.
Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  List<Car> cars = const [],
  Object? carsError,
  bool watch = true,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository()
    ..cars = cars
    ..carsError = carsError;
  late final Harness harness;
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => harness.now),
    ],
  );
  harness = Harness(tester, container, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);

  // Let the session arrive before the list is first watched.
  container.read(adminSessionProvider);
  await harness.flush();
  if (watch) {
    final subscription = container.listen(adminBookingsProvider, (_, _) {});
    addTearDown(subscription.close);
    await harness.flush();
  }
  return harness;
}

List<RawBookingDocument> documents(int count) => [
  for (var i = 0; i < count; i++) rawBooking('booking-$i'),
];

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, and no query is '
          'started', (tester) async {
        final h = await start(tester, session: session);

        expect(h.state.status, AdminBookingsStatus.inactive);
        expect(h.bookings.limits, isEmpty);
        expect(h.bookings.carReads, 0);
        expect(h.bookings.activeListeners, 0);
      });
    }

    testWidgets('admin: one query for the newest 50 and one read of the '
        'cars', (tester) async {
      final h = await start(tester);

      expect(h.state.status, AdminBookingsStatus.loading);
      expect(adminBookingsPageSize, 50);
      expect(h.bookings.limits, [50]);
      expect(h.bookings.carReads, 1);
      expect(h.bookings.activeListeners, 1);
    });

    testWidgets('the listener starts when the session becomes admin', (
      tester,
    ) async {
      final h = await start(tester, session: AdminSession.signedOut);
      expect(h.bookings.limits, isEmpty);

      h.auth.report(AdminSession.admin);
      await h.flush();

      expect(h.state.status, AdminBookingsStatus.loading);
      expect(h.bookings.activeListeners, 1);
    });

    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('when the session becomes ${session.name} the listener is '
          'closed by the provider and the list is forgotten', (tester) async {
        final h = await start(tester);
        await h.emit([rawBooking('a'), rawBooking('b')]);
        expect(h.state.bookings, hasLength(2));
        expect(h.bookings.activeListeners, 1);

        h.auth.report(session);
        await h.flush();

        expect(h.bookings.activeListeners, 0);
        expect(h.state.status, AdminBookingsStatus.inactive);
        expect(h.state.bookings, isEmpty);
        expect(h.state.failure, isNull);
      });
    }

    testWidgets('stop() closes the listener at once, before any sign-out', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')]);

      h.notifier.stop();

      // Closed although the session is still admin.
      expect(h.container.read(adminSessionProvider), AdminSession.admin);
      expect(h.bookings.activeListeners, 0);
      expect(h.state.status, AdminBookingsStatus.inactive);
      expect(h.state.bookings, isEmpty);
    });

    testWidgets('an error that arrives after the sign-out is not shown', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')]);

      // The session is gone, and the refusal of the rules arrives late.
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.fail(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingsStatus.inactive);
      expect(h.state.failure, isNull);
    });

    testWidgets('leaving the screen closes the listener', (tester) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(adminBookingsProvider, (_, _) {});
      await h.flush();
      expect(h.bookings.activeListeners, 1);

      subscription.close();
      await h.elapse(const Duration(seconds: 1));

      expect(h.bookings.activeListeners, 0);
    });
  });

  group('the list', () {
    testWidgets('an answer becomes the ready list, in the order given', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('new'), rawBooking('old')]);

      expect(h.state.status, AdminBookingsStatus.ready);
      expect(h.state.bookings.map((b) => b.id), ['new', 'old']);
      expect(h.state.unreadable, isEmpty);
      expect(h.state.hasMore, false);
      expect(h.state.showOfflineNote, false);
    });

    testWidgets('an empty answer is a ready, empty list', (tester) async {
      final h = await start(tester);
      await h.emit(const []);

      expect(h.state.status, AdminBookingsStatus.ready);
      expect(h.state.bookings, isEmpty);
    });

    testWidgets('unreadable documents are kept apart from the bookings', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([
        rawBooking('good'),
        rawBooking('bad', status: 'completed'),
      ]);

      expect(h.state.bookings.map((b) => b.id), ['good']);
      expect(h.state.unreadable.map((u) => u.id), ['bad']);
    });

    testWidgets('a later answer replaces the list, with the same query', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')]);
      await h.emit([rawBooking('b'), rawBooking('a')]);

      expect(h.state.bookings.map((b) => b.id), ['b', 'a']);
      expect(h.bookings.limits, hasLength(1));
    });

    testWidgets('the cars are read once and kept by id, also the hidden '
        'ones', (tester) async {
      final h = await start(
        tester,
        cars: [
          testCar(),
          testCar(id: 'car-2', active: false),
        ],
      );
      await h.emit([rawBooking('a')]);
      await h.emit([rawBooking('b'), rawBooking('a')]);

      final cars = h.state.carsById!;
      expect(cars.keys, ['car-1', 'car-2']);
      expect(cars['car-2']!.active, false);
      // New answers of the bookings query do not read the cars again.
      expect(h.bookings.carReads, 1);
    });

    testWidgets('cars that cannot be loaded leave the list working', (
      tester,
    ) async {
      final h = await start(
        tester,
        carsError: const AdminBookingsException(AdminBookingsFailure.other),
      );
      await h.emit([rawBooking('a')]);

      expect(h.state.status, AdminBookingsStatus.ready);
      expect(h.state.bookings, hasLength(1));
      expect(h.state.carsById, isNull);
    });
  });

  group('load more', () {
    testWidgets('offered only when the answer is exactly as long as the '
        'limit', (tester) async {
      final h = await start(tester);
      await h.emit(documents(49));
      expect(h.state.hasMore, false);

      await h.emit(documents(50));
      expect(h.state.hasMore, true);
    });

    testWidgets('unreadable documents count towards the limit', (tester) async {
      final h = await start(tester);
      await h.emit([...documents(49), rawBooking('bad', status: 'completed')]);

      expect(h.state.bookings, hasLength(49));
      expect(h.state.unreadable, hasLength(1));
      expect(h.state.hasMore, true);
    });

    testWidgets('starts a new query for 50 more and closes the old one', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(documents(50));

      h.notifier.loadMore();
      await h.flush();

      expect(h.bookings.limits, [50, 100]);
      expect(h.bookings.activeListeners, 1);
      // The old list stays while the new one loads.
      expect(h.state.loadingMore, true);
      expect(h.state.bookings, hasLength(50));

      await h.emit(documents(73));
      expect(h.state.loadingMore, false);
      expect(h.state.bookings, hasLength(73));
      expect(h.state.hasMore, false);
    });

    testWidgets('does nothing when there is no more, or while one is '
        'running', (tester) async {
      final h = await start(tester);

      h.notifier.loadMore(); // still loading
      await h.emit(documents(10));
      h.notifier.loadMore(); // no more
      expect(h.bookings.limits, [50]);

      await h.emit(documents(50));
      h.notifier
        ..loadMore()
        ..loadMore();
      expect(h.bookings.limits, [50, 100]);
    });

    testWidgets('a new sign-in starts again with 50', (tester) async {
      final h = await start(tester);
      await h.emit(documents(50));
      h.notifier.loadMore();
      await h.flush();

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.auth.report(AdminSession.admin);
      await h.flush();

      expect(h.bookings.limits, [50, 100, 50]);
    });
  });

  group('failures', () {
    testWidgets('permission denied ends in the failed state and closes the '
        'listener', (tester) async {
      final h = await start(tester);
      h.bookings.fail(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingsStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.permissionDenied);
      expect(h.state.bookings, isEmpty);
      expect(h.bookings.activeListeners, 0);
    });

    testWidgets('any other error is the "other" failure', (tester) async {
      final h = await start(tester);
      h.bookings.fail(StateError('broken'));
      await h.flush();

      expect(h.state.failure, AdminBookingsFailure.other);
    });

    testWidgets('retry starts a new query and can succeed', (tester) async {
      final h = await start(tester);
      h.bookings.fail(const AdminBookingsException(AdminBookingsFailure.other));
      await h.flush();

      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminBookingsStatus.loading);
      expect(h.bookings.limits, [50, 50]);

      await h.emit([rawBooking('a')]);
      expect(h.state.status, AdminBookingsStatus.ready);
      expect(h.state.failure, isNull);
    });
  });

  group('the offline note', () {
    testWidgets('not shown on the first answer from the saved copy', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);

      expect(h.state.status, AdminBookingsStatus.ready);
      expect(h.state.showOfflineNote, false);

      // Let the pending timer run out before the test ends.
      await h.emit([rawBooking('a')]);
    });

    testWidgets('not shown when the server answers within 3 seconds', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);
      await h.elapse(const Duration(seconds: 2));
      await h.emit([rawBooking('a')]);
      await h.elapse(const Duration(seconds: 5));

      expect(h.state.showOfflineNote, false);
    });

    testWidgets('shown after 3 seconds of saved data without a break', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);
      await h.elapse(const Duration(milliseconds: 2900));
      expect(h.state.showOfflineNote, false);

      await h.elapse(const Duration(milliseconds: 200));
      expect(h.state.showOfflineNote, true);
    });

    testWidgets('more answers from the saved copy do not restart the 3 '
        'seconds', (tester) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);
      await h.elapse(const Duration(seconds: 2));
      await h.emit([rawBooking('a')], fromCache: true);
      await h.elapse(const Duration(milliseconds: 1100));

      expect(h.state.showOfflineNote, true);
    });

    testWidgets('it disappears as soon as the server answers', (tester) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);
      await h.elapse(const Duration(seconds: 4));
      expect(h.state.showOfflineNote, true);

      await h.emit([rawBooking('a')]);
      expect(h.state.showOfflineNote, false);
    });

    testWidgets('the timer is cancelled when the listener is closed', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit([rawBooking('a')], fromCache: true);

      h.notifier.stop();
      await h.elapse(const Duration(seconds: 10));

      expect(h.state.showOfflineNote, false);
      // A timer that was still running here would fail this test at its
      // end: testWidgets does not allow one to be left behind.
    });
  });
}
