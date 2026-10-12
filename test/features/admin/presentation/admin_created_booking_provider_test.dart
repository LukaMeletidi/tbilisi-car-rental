import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_created_booking_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// These tests build no widgets. They use testWidgets only for its clock.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;

  String? get marker => container.read(adminCreatedBookingProvider);

  AdminCreatedBookingNotifier get notifier =>
      container.read(adminCreatedBookingProvider.notifier);

  AdminBookingDetailState detail(String id) =>
      container.read(adminBookingDetailProvider(id));

  Future<void> flush() => tester.pump(Duration.zero);

  /// Opens the detail of [id], as its screen does. Close the result to
  /// "leave" the detail.
  Future<ProviderSubscription<AdminBookingDetailState>> openDetail(
    String id,
  ) async {
    final subscription = container.listen(
      adminBookingDetailProvider(id),
      (_, _) {},
    );
    await flush();
    return subscription;
  }

  Future<void> emit(
    RawBookingDocument? document, {
    bool fromCache = false,
  }) async {
    bookings.emitBooking(document, fromCache: fromCache);
    await flush();
  }
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository()..cars = [testCar()];
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 9, 12)),
    ],
  );
  final harness = Harness(tester, container, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);

  container.read(adminSessionProvider);
  await harness.flush();
  // Keep the marker alive, as the app does while it runs.
  final subscription = container.listen(adminCreatedBookingProvider, (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

void main() {
  group('the marker by itself', () {
    testWidgets('starts empty; mark sets it; take answers once', (
      tester,
    ) async {
      final h = await start(tester);
      expect(h.marker, isNull);

      h.notifier.mark('new-1');
      expect(h.marker, 'new-1');

      expect(h.notifier.take('other'), false);
      expect(h.marker, 'new-1');
      expect(h.notifier.take('new-1'), true);
      expect(h.marker, isNull);
      expect(h.notifier.take('new-1'), false);
    });

    testWidgets('clearIf forgets only the marker of that booking', (
      tester,
    ) async {
      final h = await start(tester);
      h.notifier.mark('new-1');

      h.notifier.clearIf('other');
      expect(h.marker, 'new-1');
      h.notifier.clearIf('new-1');
      expect(h.marker, isNull);
    });

    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('it is forgotten when the session becomes ${session.name}', (
        tester,
      ) async {
        final h = await start(tester);
        h.notifier.mark('new-1');

        h.auth.report(session);
        await h.flush();

        expect(h.marker, isNull);
        // A new sign-in does not bring it back.
        h.auth.report(AdminSession.admin);
        await h.flush();
        expect(h.marker, isNull);
      });
    }

    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('nothing is marked while the session is '
          '${session?.name ?? 'unknown'}', (tester) async {
        final h = await start(tester, session: session);

        h.notifier.mark('new-1');

        expect(h.marker, isNull);
      });
    }
  });

  group('the detail and the marker', () {
    testWidgets('the detail of the marked booking says "Saved" when it has '
        'found the booking, and takes the marker', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      await h.openDetail('new-1');
      // Not yet: nothing was found so far.
      expect(h.marker, 'new-1');
      expect(h.detail('new-1').notice, isNull);

      await h.emit(rawBooking('new-1'));

      expect(h.detail('new-1').status, AdminBookingDetailStatus.found);
      expect(h.detail('new-1').notice, AdminStatusChangeNotice.saved);
      expect(h.detail('new-1').noticeFields, isEmpty);
      expect(h.marker, isNull);
    });

    testWidgets('"Saved" is shown once: a later answer does not show it '
        'again after it was hidden', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      await h.openDetail('new-1');
      await h.emit(rawBooking('new-1'));

      h.container
          .read(adminBookingDetailProvider('new-1').notifier)
          .dismissNotice();
      await h.emit(rawBooking('new-1', status: 'confirmed'));

      expect(h.detail('new-1').notice, isNull);
    });

    testWidgets('opening the same detail again later shows no "Saved"', (
      tester,
    ) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      final first = await h.openDetail('new-1');
      await h.emit(rawBooking('new-1'));
      first.close();
      await h.tester.pump(const Duration(seconds: 1));

      await h.openDetail('new-1');
      await h.emit(rawBooking('new-1'));

      expect(h.detail('new-1').status, AdminBookingDetailStatus.found);
      expect(h.detail('new-1').notice, isNull);
    });

    testWidgets('a first answer "not known yet" (saved copy without the '
        'booking) leaves the marker; the server answer then takes it', (
      tester,
    ) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      await h.openDetail('new-1');

      await h.emit(null, fromCache: true);
      expect(h.detail('new-1').status, AdminBookingDetailStatus.loading);
      expect(h.marker, 'new-1');

      await h.emit(rawBooking('new-1'));
      expect(h.detail('new-1').notice, AdminStatusChangeNotice.saved);
      expect(h.marker, isNull);
    });

    testWidgets('a first answer "missing" leaves the marker, and shows no '
        '"Saved"; a booking that appears afterwards takes it', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      await h.openDetail('new-1');

      await h.emit(null);
      expect(h.detail('new-1').status, AdminBookingDetailStatus.missing);
      expect(h.detail('new-1').notice, isNull);
      expect(h.marker, 'new-1');

      await h.emit(rawBooking('new-1'));
      expect(h.detail('new-1').notice, AdminStatusChangeNotice.saved);
      expect(h.marker, isNull);
    });

    testWidgets('leaving the detail of that booking forgets a marker that '
        'was never used', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      final detail = await h.openDetail('new-1');
      await h.emit(null);
      expect(h.marker, 'new-1');

      detail.close();
      await h.tester.pump(const Duration(seconds: 1));

      expect(h.marker, isNull);
    });

    testWidgets('the detail of ANOTHER booking neither shows "Saved" nor '
        'touches the marker, also when it is left', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      final other = await h.openDetail('b1');
      await h.emit(rawBooking('b1'));

      expect(h.detail('b1').status, AdminBookingDetailStatus.found);
      expect(h.detail('b1').notice, isNull);
      expect(h.marker, 'new-1');

      other.close();
      await h.tester.pump(const Duration(seconds: 1));
      expect(h.marker, 'new-1');
    });

    testWidgets('the session ends before the detail found the booking: the '
        'marker is gone and a later sign-in shows no "Saved"', (tester) async {
      final h = await start(tester);
      h.notifier.mark('new-1');
      await h.openDetail('new-1');

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.marker, isNull);

      h.auth.report(AdminSession.admin);
      await h.flush();
      await h.emit(rawBooking('new-1'));
      expect(h.detail('new-1').status, AdminBookingDetailStatus.found);
      expect(h.detail('new-1').notice, isNull);
    });

    testWidgets('without a marker the detail is as before', (tester) async {
      final h = await start(tester);
      await h.openDetail('b1');
      await h.emit(rawBooking('b1'));

      expect(h.detail('b1').notice, isNull);
      expect(h.marker, isNull);
    });
  });
}
