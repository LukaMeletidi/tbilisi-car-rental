import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// These tests build no widgets. They use testWidgets only for its clock:
/// inside it, time passes when the test says so, and a test fails by
/// itself when a timer is still running at its end.
class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth, this.id);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;
  final String id;

  /// The clock the provider reads; it moves with [elapse].
  DateTime now = DateTime.utc(2026, 10, 9, 12);

  AdminBookingDetailState get state =>
      container.read(adminBookingDetailProvider(id));

  AdminBookingDetailNotifier get notifier =>
      container.read(adminBookingDetailProvider(id).notifier);

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
    RawBookingDocument? document, {
    bool fromCache = false,
  }) async {
    bookings.emitBooking(document, fromCache: fromCache);
    await flush();
  }
}

/// Starts with a fake auth repository in [session] and a fake bookings
/// repository. With [watch] the detail provider is kept alive, as the
/// screen does.
Future<Harness> start(
  WidgetTester tester, {
  AdminSession? session = AdminSession.admin,
  String id = 'b1',
  List<Car>? cars,
  bool watch = true,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final bookings = FakeAdminBookingsRepository()..cars = cars ?? [testCar()];
  late final Harness harness;
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => harness.now),
    ],
  );
  harness = Harness(tester, container, bookings, auth, id);
  addTearDown(container.dispose);
  addTearDown(auth.close);

  // Let the session arrive before the detail is first watched.
  container.read(adminSessionProvider);
  await harness.flush();
  if (watch) {
    final subscription = container.listen(
      adminBookingDetailProvider(id),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await harness.flush();
  }
  return harness;
}

void main() {
  group('tied to the admin session', () {
    for (final session in [
      null,
      AdminSession.signedOut,
      AdminSession.noAccess,
    ]) {
      testWidgets('${session?.name ?? 'unknown'}: inactive, and nothing is '
          'asked for', (tester) async {
        final h = await start(tester, session: session);

        expect(h.state.status, AdminBookingDetailStatus.inactive);
        expect(h.bookings.watchedBookingIds, isEmpty);
        expect(h.bookings.carIdsRead, isEmpty);
        expect(h.bookings.activeBookingListeners, 0);
      });
    }

    testWidgets('admin: one listener for exactly this booking', (tester) async {
      final h = await start(tester, id: 'made-up-id');

      expect(h.state.status, AdminBookingDetailStatus.loading);
      expect(h.bookings.watchedBookingIds, ['made-up-id']);
      expect(h.bookings.activeBookingListeners, 1);
      // The list is not this provider's business.
      expect(h.bookings.limits, isEmpty);
    });

    for (final id in ['a b', 'a/b', '..', 'a%20b', '']) {
      testWidgets('an ID of an impossible shape ("$id") is "missing" and '
          'Firestore is not asked', (tester) async {
        final h = await start(tester, id: id);

        expect(h.state.status, AdminBookingDetailStatus.missing);
        expect(h.bookings.watchedBookingIds, isEmpty);
        expect(h.bookings.activeBookingListeners, 0);
      });
    }

    for (final session in [AdminSession.signedOut, AdminSession.noAccess]) {
      testWidgets('when the session becomes ${session.name} the listener is '
          'closed by the provider and the booking is forgotten', (
        tester,
      ) async {
        final h = await start(tester);
        await h.emit(rawBooking('b1'));
        expect(h.state.booking, isNotNull);

        h.auth.report(session);
        await h.flush();

        expect(h.bookings.activeBookingListeners, 0);
        expect(h.state.status, AdminBookingDetailStatus.inactive);
        expect(h.state.booking, isNull);
      });
    }

    testWidgets('an error that arrives after the sign-out is not shown', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1'));

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingDetailStatus.inactive);
      expect(h.state.failure, isNull);
    });

    testWidgets('leaving the screen closes the listener', (tester) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(
        adminBookingDetailProvider('b1'),
        (_, _) {},
      );
      await h.flush();
      expect(h.bookings.activeBookingListeners, 1);

      subscription.close();
      await h.elapse(const Duration(seconds: 1));

      expect(h.bookings.activeBookingListeners, 0);
    });

    testWidgets('a new sign-in as admin loads the booking and its car again', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1'));
      h.auth.report(AdminSession.signedOut);
      await h.flush();

      h.auth.report(AdminSession.admin);
      await h.flush();
      await h.emit(rawBooking('b1'));

      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.car.state, AdminCarState.active);
      expect(h.bookings.carIdsRead, ['car-1', 'car-1']);
    });
  });

  group('reading the booking', () {
    testWidgets('an answer of the server is shown, with its car', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'pending'));

      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.booking!.id, 'b1');
      expect(h.state.booking!.status, BookingStatus.pending);
      expect(h.state.showOfflineNote, false);
      expect(h.state.saving, false);
      expect(h.state.notice, isNull);
      expect(h.bookings.carIdsRead, ['car-1']);
      expect(
        h.state.car,
        const AdminCarLabel(AdminCarState.active, 'Toyota Prius, 2019'),
      );
    });

    testWidgets('a hidden car is read too', (tester) async {
      final h = await start(
        tester,
        cars: [testCar(id: 'hidden-car', active: false)],
      );
      await h.emit(rawBooking('b1', carId: 'hidden-car'));

      expect(h.state.car.state, AdminCarState.hidden);
      expect(h.state.car.title, 'Toyota Prius, 2019');
    });

    testWidgets('a car that no longer exists is "not found"', (tester) async {
      final h = await start(tester, cars: const []);
      await h.emit(rawBooking('b1'));

      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.car.state, AdminCarState.notFound);
    });

    testWidgets('when the car cannot be loaded the booking is still shown', (
      tester,
    ) async {
      final h = await start(tester);
      h.bookings.carError = const AdminBookingsException(
        AdminBookingsFailure.other,
      );
      await h.emit(rawBooking('b1'));

      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.car.state, AdminCarState.notLoaded);
    });

    testWidgets('the car is read once, not for every answer', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      await h.emit(rawBooking('b1', status: 'pending'));
      await h.emit(rawBooking('b1', status: 'confirmed'));

      expect(h.bookings.carIdsRead, ['car-1']);
      expect(h.state.car.state, AdminCarState.active);
      expect(h.state.booking!.status, BookingStatus.confirmed);
    });

    testWidgets('a change of the car reads the new car', (tester) async {
      final h = await start(
        tester,
        cars: [
          testCar(),
          testCar(id: 'car-2', active: false),
        ],
      );
      await h.emit(rawBooking('b1'));
      await h.emit(rawBooking('b1', carId: 'car-2'));

      expect(h.bookings.carIdsRead, ['car-1', 'car-2']);
      expect(h.state.car.state, AdminCarState.hidden);
    });

    testWidgets('the server says there is no such booking: missing', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(null);

      expect(h.state.status, AdminBookingDetailStatus.missing);
      expect(h.state.booking, isNull);
    });

    testWidgets('a booking that is deleted while it is open becomes '
        'missing', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1'));

      await h.emit(null);

      expect(h.state.status, AdminBookingDetailStatus.missing);
      expect(h.state.booking, isNull);
    });

    testWidgets('a document that is not a booking is unreadable, with the '
        'reason', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', changes: {'status': 'approved'}));

      expect(h.state.status, AdminBookingDetailStatus.unreadable);
      expect(h.state.booking, isNull);
      expect(h.state.unreadableReason, contains('status'));
    });

    testWidgets('an error is shown as a failure and closes the listener', (
      tester,
    ) async {
      final h = await start(tester);
      h.bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.permissionDenied),
      );
      await h.flush();

      expect(h.state.status, AdminBookingDetailStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.permissionDenied);
      expect(h.bookings.activeBookingListeners, 0);
    });

    testWidgets('an error of another type is a general failure', (
      tester,
    ) async {
      final h = await start(tester);
      h.bookings.failBooking(StateError('made up'));
      await h.flush();

      expect(h.state.failure, AdminBookingsFailure.other);
    });

    testWidgets('retry starts a new listener', (tester) async {
      final h = await start(tester);
      h.bookings.failBooking(
        const AdminBookingsException(AdminBookingsFailure.other),
      );
      await h.flush();

      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminBookingDetailStatus.loading);
      expect(h.bookings.watchedBookingIds, ['b1', 'b1']);
      expect(h.bookings.activeBookingListeners, 1);

      await h.emit(rawBooking('b1'));
      expect(h.state.status, AdminBookingDetailStatus.found);
    });
  });

  group('saved data and the offline note', () {
    testWidgets('the saved copy not having the booking is NOT "missing": '
        'the screen keeps waiting for the server', (tester) async {
      final h = await start(tester);
      await h.emit(null, fromCache: true);
      expect(h.state.status, AdminBookingDetailStatus.loading);

      await h.elapse(const Duration(seconds: 1));
      await h.emit(rawBooking('b1'));

      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.showOfflineNote, false);
    });

    testWidgets('nothing saved and no answer of the server for 3 seconds: '
        '"could not load", not "missing"', (tester) async {
      final h = await start(tester);
      await h.emit(null, fromCache: true);

      await h.elapse(const Duration(seconds: 2));
      expect(h.state.status, AdminBookingDetailStatus.loading);
      await h.elapse(const Duration(seconds: 1));

      expect(h.state.status, AdminBookingDetailStatus.failed);
      expect(h.state.failure, AdminBookingsFailure.other);
      expect(h.bookings.activeBookingListeners, 0);
    });

    testWidgets('saved data shows no note at first: the server usually '
        'answers a moment later', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1'), fromCache: true);
      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.showOfflineNote, false);

      await h.elapse(const Duration(seconds: 1));
      await h.emit(rawBooking('b1'));

      expect(h.state.showOfflineNote, false);
      await h.elapse(offlineNoteDelay);
      expect(h.state.showOfflineNote, false);
    });

    testWidgets('after 3 seconds of saved data the note appears, and an '
        'answer of the server removes it', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1'), fromCache: true);

      await h.elapse(const Duration(milliseconds: 2900));
      expect(h.state.showOfflineNote, false);
      await h.elapse(const Duration(milliseconds: 100));
      expect(h.state.showOfflineNote, true);
      // The booking stays, and so do the choices.
      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.saving, false);

      await h.emit(rawBooking('b1'));
      expect(h.state.showOfflineNote, false);
    });

    testWidgets('the delay is the one of the list', (tester) async {
      expect(offlineNoteDelay, const Duration(seconds: 3));
    });
  });

  group('changing the status', () {
    testWidgets('writes once, with this booking and the new status', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));

      await h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();

      expect(h.bookings.statusChanges, [
        (id: 'b1', status: BookingStatus.pending),
      ]);
      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.saved);
    });

    testWidgets('"saving" lasts until the server has answered, and "saved" '
        'comes only then', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();

      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.notice, isNull);

      await h.elapse(const Duration(seconds: 5));
      expect(h.state.saving, true);
      expect(h.state.notice, isNull);

      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.saved);
    });

    testWidgets('the status shown follows the live read, never the attempt', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();

      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();
      expect(h.state.booking!.status, BookingStatus.newBooking);

      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();
      // "Saved", and still the old status until the live read delivers it.
      expect(h.state.notice, AdminStatusChangeNotice.saved);
      expect(h.state.booking!.status, BookingStatus.newBooking);

      await h.emit(rawBooking('b1', status: 'confirmed'));
      expect(h.state.booking!.status, BookingStatus.confirmed);
      expect(h.state.notice, AdminStatusChangeNotice.saved);
    });

    testWidgets('a second call while one is running does nothing', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();

      final first = h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();
      await h.notifier.changeStatus(BookingStatus.pending);
      await h.notifier.changeStatus(BookingStatus.cancelled);
      await h.flush();

      expect(h.bookings.statusChanges, hasLength(1));

      h.bookings.statusChangePending!.complete();
      await first;
      await h.flush();
      expect(h.bookings.statusChanges, hasLength(1));
    });

    testWidgets('two calls in the same moment write once', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));

      final first = h.notifier.changeStatus(BookingStatus.pending);
      final second = h.notifier.changeStatus(BookingStatus.pending);
      await Future.wait([first, second]);
      await h.flush();

      expect(h.bookings.statusChanges, hasLength(1));
    });

    testWidgets('the status it already has is not written', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'pending'));

      await h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();

      expect(h.bookings.statusChanges, isEmpty);
      expect(h.state.saving, false);
      expect(h.state.notice, isNull);
    });

    testWidgets('nothing is written before the booking is shown', (
      tester,
    ) async {
      final h = await start(tester);

      await h.notifier.changeStatus(BookingStatus.pending);
      await h.emit(null);
      await h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();

      expect(h.bookings.statusChanges, isEmpty);
    });

    testWidgets('no answer within the time limit is not "not saved"', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeNoAnswer();

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.noAnswer);
      // Whatever happened, the status shown is the one last read.
      expect(h.state.booking!.status, BookingStatus.newBooking);

      // The change arrived after all: the live read shows it.
      await h.emit(rawBooking('b1', status: 'confirmed'));
      expect(h.state.booking!.status, BookingStatus.confirmed);
    });

    const failures = {
      AdminStatusChangeFailure.noConnection:
          AdminStatusChangeNotice.noConnection,
      AdminStatusChangeFailure.refused: AdminStatusChangeNotice.refused,
      AdminStatusChangeFailure.bookingMissing:
          AdminStatusChangeNotice.bookingMissing,
      AdminStatusChangeFailure.unknown: AdminStatusChangeNotice.unknown,
    };
    for (final entry in failures.entries) {
      testWidgets('${entry.key.name}: not saved, the status stays, and the '
          'choices come back', (tester) async {
        final h = await start(tester);
        await h.emit(rawBooking('b1', status: 'new'));
        h.bookings.statusChangeError = AdminStatusChangeException(entry.key);

        await h.notifier.changeStatus(BookingStatus.confirmed);
        await h.flush();

        expect(h.state.saving, false);
        expect(h.state.notice, entry.value);
        expect(h.state.status, AdminBookingDetailStatus.found);
        expect(h.state.booking!.status, BookingStatus.newBooking);
      });
    }

    testWidgets('an error of an unexpected type is "please try again"', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = StateError('made up');

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.unknown);
    });

    testWidgets('after a failure the change can be tried again', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.noConnection,
      );
      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      h.bookings.statusChangeError = null;
      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();
      await change;
      await h.flush();

      expect(h.bookings.statusChanges, hasLength(2));
      expect(h.state.notice, AdminStatusChangeNotice.saved);
    });

    testWidgets('a new attempt removes the old notice while it runs', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      await h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();
      expect(h.state.notice, AdminStatusChangeNotice.saved);
      await h.emit(rawBooking('b1', status: 'pending'));

      h.bookings.statusChangePending = Completer<void>();
      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.notice, isNull);

      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();
    });

    testWidgets('a live answer during the change keeps "saving"', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();
      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      // The live read is often faster than the answer to the write.
      await h.emit(rawBooking('b1', status: 'confirmed'));
      expect(h.state.saving, true);
      expect(h.state.booking!.status, BookingStatus.confirmed);

      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();
      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.saved);
    });

    testWidgets('the booking is deleted meanwhile: "no longer exists", and '
        'the live read shows it as missing', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.bookingMissing,
      );

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();
      expect(h.state.notice, AdminStatusChangeNotice.bookingMissing);

      await h.emit(null);
      expect(h.state.status, AdminBookingDetailStatus.missing);
      expect(h.state.notice, AdminStatusChangeNotice.bookingMissing);
    });

    testWidgets('the session ends during the change: nothing is reported '
        'and nothing breaks', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();
      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      h.auth.report(AdminSession.signedOut);
      await h.flush();
      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();

      expect(h.state.status, AdminBookingDetailStatus.inactive);
      expect(h.state.saving, false);
      expect(h.state.notice, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen is left during the change: nothing breaks', (
      tester,
    ) async {
      final h = await start(tester, watch: false);
      final subscription = h.container.listen(
        adminBookingDetailProvider('b1'),
        (_, _) {},
      );
      await h.flush();
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangePending = Completer<void>();
      final change = h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      subscription.close();
      await h.elapse(const Duration(seconds: 1));
      h.bookings.statusChangePending!.complete();
      await change;
      await h.flush();

      expect(tester.takeException(), isNull);
    });

    testWidgets('not an admin: nothing is written', (tester) async {
      final h = await start(tester, session: AdminSession.noAccess);

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.bookings.statusChanges, isEmpty);
    });

    testWidgets('a booking with a field the rules do not know: not saved, '
        'and the field is named', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.unknownFields,
        fields: ['zzTest'],
      );

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.unknownFields);
      expect(h.state.noticeFields, ['zzTest']);
      expect(h.state.booking!.status, BookingStatus.newBooking);

      // The names stay with the notice through a live answer...
      await h.emit(rawBooking('b1', status: 'new'));
      expect(h.state.noticeFields, ['zzTest']);

      // ...and go with it.
      h.notifier.dismissNotice();
      await h.flush();
      expect(h.state.notice, isNull);
      expect(h.state.noticeFields, isEmpty);
    });

    testWidgets('a new attempt forgets the names of the last one', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.unknownFields,
        fields: ['zzTest'],
      );
      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      h.bookings.statusChangeError = null;
      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.notice, AdminStatusChangeNotice.saved);
      expect(h.state.noticeFields, isEmpty);
    });

    testWidgets('a booking without a creation date: not saved, said so', (
      tester,
    ) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.noCreatedAt,
      );

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.notice, AdminStatusChangeNotice.noCreatedAt);
      expect(h.state.noticeFields, isEmpty);
    });

    testWidgets('a stored value in a form the rules refuse: not saved, and '
        'the part is named', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      h.bookings.statusChangeError = const AdminStatusChangeException(
        AdminStatusChangeFailure.storedFormat,
        fields: ['phoneStoredFormat'],
      );

      await h.notifier.changeStatus(BookingStatus.confirmed);
      await h.flush();

      expect(h.state.saving, false);
      expect(h.state.notice, AdminStatusChangeNotice.storedFormat);
      expect(h.state.noticeFields, ['phoneStoredFormat']);
      expect(h.state.booking!.status, BookingStatus.newBooking);
    });

    testWidgets('showSaved: the "Saved" notice of a status change, used '
        'after an edit; only for a booking that is shown', (tester) async {
      final h = await start(tester);

      h.notifier.showSaved();
      await h.flush();
      expect(h.state.notice, isNull);

      await h.emit(rawBooking('b1', status: 'new'));
      h.notifier.showSaved();
      await h.flush();

      expect(h.state.notice, AdminStatusChangeNotice.saved);
      expect(h.state.noticeFields, isEmpty);
      expect(h.state.saving, false);
      expect(h.bookings.statusChanges, isEmpty);

      // It stays through a live answer and can be hidden like any notice.
      await h.emit(rawBooking('b1', fullName: 'Other Person'));
      expect(h.state.notice, AdminStatusChangeNotice.saved);
      h.notifier.dismissNotice();
      await h.flush();
      expect(h.state.notice, isNull);
    });

    testWidgets('the notice can be hidden', (tester) async {
      final h = await start(tester);
      await h.emit(rawBooking('b1', status: 'new'));
      await h.notifier.changeStatus(BookingStatus.pending);
      await h.flush();
      expect(h.state.notice, AdminStatusChangeNotice.saved);

      h.notifier.dismissNotice();
      await h.flush();

      expect(h.state.notice, isNull);
      expect(h.state.status, AdminBookingDetailStatus.found);
      expect(h.state.booking, isNotNull);
    });
  });
}
