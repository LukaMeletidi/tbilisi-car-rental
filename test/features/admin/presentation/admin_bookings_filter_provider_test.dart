import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_filter_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// These tests build no widgets; testWidgets gives them a clock that only
/// moves when the test says so.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;

  /// The fixed "now" the pickup order uses: 1 March 2026, 12:00 UTC.
  DateTime now = DateTime.utc(2026, 3, 1, 12);

  AdminBookingsFilter get filter => container.read(adminBookingsFilterProvider);

  AdminBookingsFilterNotifier get notifier =>
      container.read(adminBookingsFilterProvider.notifier);

  AdminBookingsView get view => container.read(adminBookingsViewProvider);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> report(AdminSession session) async {
    auth.report(session);
    await flush();
  }
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository();
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

  container.read(adminSessionProvider);
  await harness.flush();
  // Keep the providers alive, as the screen does.
  addTearDown(container.listen(adminBookingsProvider, (_, _) {}).close);
  addTearDown(container.listen(adminBookingsFilterProvider, (_, _) {}).close);
  addTearDown(container.listen(adminBookingsViewProvider, (_, _) {}).close);
  await harness.flush();
  return harness;
}

const chosen = AdminBookingsFilter(
  status: BookingStatus.confirmed,
  search: 'person',
  sort: AdminBookingsSort.pickupDate,
);

void choose(Harness h) {
  h.notifier
    ..setStatus(BookingStatus.confirmed)
    ..setSearch('person')
    ..setSort(AdminBookingsSort.pickupDate);
}

void main() {
  group('the choice', () {
    testWidgets('starts as all statuses, empty search, newest first', (
      tester,
    ) async {
      final h = await start(tester);
      expect(h.filter, const AdminBookingsFilter());
    });

    testWidgets('each setter changes its own value', (tester) async {
      final h = await start(tester);
      choose(h);
      expect(h.filter, chosen);

      h.notifier.setStatus(null);
      expect(h.filter.status, isNull);
      expect(h.filter.search, 'person');
      expect(h.filter.sort, AdminBookingsSort.pickupDate);
      await h.flush();
    });

    testWidgets('clear() drops the status and the search and keeps the '
        'order', (tester) async {
      final h = await start(tester);
      choose(h);

      h.notifier.clear();

      expect(
        h.filter,
        const AdminBookingsFilter(sort: AdminBookingsSort.pickupDate),
      );
      await h.flush();
    });

    testWidgets('it is kept while the admin stays signed in, also when the '
        'list is left', (tester) async {
      final h = await start(tester);
      choose(h);

      // New answers of the bookings query do not touch the choice.
      h.bookings.emit([rawBooking('a')]);
      await h.flush();
      expect(h.filter, chosen);

      // Nothing watches the filter for a while: it is not auto-dispose.
      final other = h.container.listen(adminBookingsFilterProvider, (_, _) {});
      other.close();
      await h.flush();
      expect(h.filter, chosen);
    });
  });

  group('reset with the session', () {
    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('a session that becomes ${session.name} resets the choice', (
        tester,
      ) async {
        final h = await start(tester);
        choose(h);
        expect(h.filter, chosen);

        // Not through the Sign out button: the session ends by itself.
        await h.report(session);

        expect(h.filter, const AdminBookingsFilter());
      });
    }

    testWidgets('after a new sign-in the choice is the default', (
      tester,
    ) async {
      final h = await start(tester);
      choose(h);

      await h.report(AdminSession.signedOut);
      await h.report(AdminSession.admin);

      expect(h.filter, const AdminBookingsFilter());
    });

    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('while the session is ${session?.name ?? 'unknown'} the '
          'choice cannot be changed', (tester) async {
        final h = await start(tester, session: session);

        choose(h);
        h.notifier.clear();

        expect(h.filter, const AdminBookingsFilter());
      });
    }
  });

  group('the view', () {
    testWidgets('applies the choice to the loaded bookings without a new '
        'query', (tester) async {
      final h = await start(tester);
      h.bookings.emit([
        rawBooking('a', fullName: 'Person One', status: 'new'),
        rawBooking('b', fullName: 'Person Two', status: 'confirmed'),
        rawBooking('c', fullName: 'Someone Else', status: 'confirmed'),
      ]);
      await h.flush();

      expect(h.view.visible.map((b) => b.id), ['a', 'b', 'c']);
      expect(h.view.total, 3);
      expect(h.view.loadedCount, 3);

      h.notifier.setStatus(BookingStatus.confirmed);
      await h.flush();
      expect(h.view.visible.map((b) => b.id), ['b', 'c']);
      // The counts ignore the chosen status.
      expect(h.view.counts[BookingStatus.newBooking], 1);
      expect(h.view.counts[BookingStatus.confirmed], 2);

      h.notifier.setSearch('person');
      await h.flush();
      expect(h.view.visible.map((b) => b.id), ['b']);
      // The counts follow the search.
      expect(h.view.counts[BookingStatus.confirmed], 1);
      expect(h.view.total, 2);
      expect(h.view.loadedCount, 3);

      // One query from the start, and no car read beyond the first.
      expect(h.bookings.limits, [50]);
      expect(h.bookings.carReads, 1);
    });

    testWidgets('a live update keeps the choice and is filtered too', (
      tester,
    ) async {
      final h = await start(tester);
      h.notifier.setStatus(BookingStatus.confirmed);
      h.bookings.emit([rawBooking('a', status: 'new')]);
      await h.flush();
      expect(h.view.visible, isEmpty);

      h.bookings.emit([
        rawBooking('b', status: 'confirmed'),
        rawBooking('a', status: 'new'),
      ]);
      await h.flush();

      expect(h.view.visible.map((b) => b.id), ['b']);
      expect(h.filter.status, BookingStatus.confirmed);
    });

    testWidgets('the pickup order takes "now" from the clock provider', (
      tester,
    ) async {
      final h = await start(tester);
      h.notifier.setSort(AdminBookingsSort.pickupDate);
      h.bookings.emit([
        rawBooking(
          'march',
          pickup: DateTime.utc(2026, 3, 10),
          dropoff: DateTime.utc(2026, 3, 12),
        ),
        rawBooking(
          'may',
          pickup: DateTime.utc(2026, 5, 10),
          dropoff: DateTime.utc(2026, 5, 12),
        ),
      ]);
      await h.flush();
      expect(h.view.visible.map((b) => b.id), ['march', 'may']);

      // In April the March pickup is past. The view is worked out again
      // when something changes, here the order chosen once more.
      h.now = DateTime.utc(2026, 4, 1);
      h.notifier
        ..setSort(AdminBookingsSort.newestFirst)
        ..setSort(AdminBookingsSort.pickupDate);
      await h.flush();
      expect(h.view.visible.map((b) => b.id), ['may', 'march']);
    });

    testWidgets('after the session ends nothing is shown and the choice is '
        'the default', (tester) async {
      final h = await start(tester);
      choose(h);
      h.bookings.emit([rawBooking('a', status: 'confirmed')]);
      await h.flush();
      expect(h.view.visible, hasLength(1));

      await h.report(AdminSession.signedOut);

      expect(h.view.visible, isEmpty);
      expect(h.view.loadedCount, 0);
      expect(h.filter, const AdminBookingsFilter());
    });
  });
}
