import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_deleted_notice_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_gate_screens.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The real router and the real screens; Firebase is replaced. Every value
/// is made up.
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

const detailAddress = '/admin/bookings/b1';
const deletedText = 'Booking deleted.';

late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_App)));

String address(WidgetTester tester) => containerOf(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

Future<void> open(WidgetTester tester, String address) async {
  containerOf(tester).read(appRouterProvider).go(address);
  await settle(tester);
}

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(800, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  bookings = FakeAdminBookingsRepository()
    ..cars = [testCar(), testCar(id: 'hidden-car', active: false)];
  addTearDown(auth.close);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 9, 12)),
        activeCarsProvider.overrideWith((ref) => Stream.value([testCar()])),
        pickupLocationsProvider.overrideWith(
          (ref) => Stream.value(const <PickupLocation>[]),
        ),
      ],
      child: const _App(),
    ),
  );
  await settle(tester);
}

/// Opens the detail of the booking "b1" (customer "Delete Test One").
Future<void> openDetail(
  WidgetTester tester, {
  String status = 'new',
  String carId = 'car-1',
  Size size = const Size(800, 2400),
}) async {
  await pumpApp(tester, size: size);
  await open(tester, detailAddress);
  bookings.emitBookingToAll(
    rawBooking('b1', fullName: 'Delete Test One', status: status, carId: carId),
  );
  await settle(tester);
}

Finder get deleteButton => find.widgetWithText(TextButton, adminDeleteButton);

Finder get confirmDelete => find.widgetWithText(FilledButton, adminDeleteYes);

Future<void> tapDelete(WidgetTester tester) async {
  await tester.ensureVisible(deleteButton);
  await tester.tap(deleteButton);
  await settle(tester);
}

/// The text of the dialog, in one piece.
String dialogText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .join('\n');

void main() {
  group('the button', () {
    testWidgets('is at the end of the detail, red, for a booking in every '
        'status', (tester) async {
      for (final status in BookingStatus.values) {
        await openDetail(tester, status: status.storedName);

        expect(deleteButton, findsOneWidget, reason: status.name);
        // Below the booking ID, the last thing on the page.
        expect(
          tester.getTopLeft(deleteButton).dy,
          greaterThan(tester.getTopLeft(find.text('Booking ID: b1')).dy),
        );
        final label = tester.renderObject<RenderParagraph>(
          find.text(adminDeleteButton),
        );
        final colour = label.text.style!.color!;
        expect(colour.r, greaterThan(colour.b), reason: 'red');
        expect(colour.r, greaterThan(colour.g), reason: 'red');
      }
    });

    testWidgets('is not there while loading, for a missing booking or for '
        'one that cannot be read', (tester) async {
      await pumpApp(tester);
      await open(tester, detailAddress);
      expect(deleteButton, findsNothing);

      bookings.emitBookingToAll(
        rawBooking('b1', changes: {'status': 'approved'}),
      );
      await settle(tester);
      expect(find.text(adminBookingUnreadable), findsOneWidget);
      expect(deleteButton, findsNothing);

      bookings.emitBookingToAll(null);
      await settle(tester);
      expect(find.text(adminBookingMissing), findsOneWidget);
      expect(deleteButton, findsNothing);
    });

    testWidgets('fits a phone 320 wide, with the dialog open', (tester) async {
      await openDetail(
        tester,
        status: 'confirmed',
        size: const Size(320, 2800),
      );
      await tapDelete(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the question', () {
    testWidgets('says which booking it is (name, car, pickup, status), that '
        'it cannot be undone, and that Cancelled is the softer way', (
      tester,
    ) async {
      await openDetail(tester, status: 'pending');
      await tapDelete(tester);

      expect(find.text(adminDeleteTitle), findsOneWidget);
      final text = dialogText(tester);
      expect(text, contains('Delete Test One'));
      expect(text, contains('Toyota Prius, 2019'));
      // Stored 14:00 UTC; Tbilisi time.
      expect(text, contains('Pickup: 10 Jan 2026 18:00'));
      expect(text, contains('Status: Pending'));
      expect(text, contains('This cannot be undone.'));
      expect(text, contains('Cancelled'));
      expect(text, isNot(contains(adminDeleteConfirmedWarning)));
      // No phone and no e-mail in the question.
      expect(text, isNot(contains('+995')));
      expect(text, isNot(contains('@')));
      expect(find.widgetWithText(TextButton, adminConfirmNo), findsOneWidget);
      expect(confirmDelete, findsOneWidget);
      // Nothing happened yet.
      expect(bookings.deletes, isEmpty);
    });

    testWidgets('a confirmed booking gets one more line, and the same '
        'buttons', (tester) async {
      await openDetail(tester, status: 'confirmed');
      await tapDelete(tester);

      final text = dialogText(tester);
      expect(text, contains('Status: Confirmed'));
      expect(
        text,
        contains('This booking is confirmed. The customer expects the car.'),
      );
      expect(find.widgetWithText(TextButton, adminConfirmNo), findsOneWidget);
      expect(confirmDelete, findsOneWidget);
    });

    for (final status in ['new', 'pending', 'cancelled']) {
      testWidgets('no extra line for the status $status', (tester) async {
        await openDetail(tester, status: status);
        await tapDelete(tester);

        expect(dialogText(tester), isNot(contains('expects the car')));
      });
    }

    testWidgets('a hidden car is named as such', (tester) async {
      await openDetail(tester, carId: 'hidden-car');
      await tapDelete(tester);

      expect(dialogText(tester), contains('Toyota Prius, 2019 (hidden)'));
    });

    testWidgets('it is dark text on white, and "Delete" is red', (
      tester,
    ) async {
      await openDetail(tester);
      await tapDelete(tester);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, Colors.white);
      final title = tester.renderObject<RenderParagraph>(
        find.text(adminDeleteTitle),
      );
      expect(title.text.style!.color!.computeLuminance(), lessThan(0.3));
      final background = tester
          .widget<FilledButton>(confirmDelete)
          .style!
          .backgroundColor!
          .resolve({})!;
      expect(background.r, greaterThan(background.b));
      expect(background.r, greaterThan(background.g));
    });
  });

  group('only "Delete" deletes', () {
    testWidgets('"Keep" closes the question and deletes nothing', (
      tester,
    ) async {
      await openDetail(tester);
      await tapDelete(tester);

      await tester.tap(find.widgetWithText(TextButton, adminConfirmNo));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.deletes, isEmpty);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), detailAddress);
    });

    testWidgets('a tap beside the question closes it and deletes nothing', (
      tester,
    ) async {
      await openDetail(tester);
      await tapDelete(tester);

      await tester.tapAt(const Offset(5, 5));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.deletes, isEmpty);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
    });

    testWidgets('Back closes the question and deletes nothing', (tester) async {
      await openDetail(tester);
      await tapDelete(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.deletes, isEmpty);
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(address(tester), detailAddress);
    });

    testWidgets('"Delete" deletes once, with the status that was shown', (
      tester,
    ) async {
      await openDetail(tester, status: 'pending');
      await tapDelete(tester);

      await tester.tap(confirmDelete);
      await settle(tester);

      expect(bookings.deletes, [
        (id: 'b1', shownStatus: BookingStatus.pending),
      ]);
    });
  });

  group('deleting', () {
    testWidgets('after "Deleted" the list is shown with "Booking deleted." '
        'once; the detail never says "does not exist"', (tester) async {
      await openDetail(tester);
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(find.byType(AdminBookingDetailScreen), findsNothing);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(address(tester), '/admin');
      expect(find.text(deletedText), findsOneWidget);
      expect(find.text(adminBookingMissing), findsNothing);

      // The list updates by itself; the notice is also seen when it is
      // empty.
      bookings.emit(const []);
      await settle(tester);
      expect(find.text(adminNoBookings), findsOneWidget);
      expect(find.text(deletedText), findsOneWidget);
    });

    testWidgets('"Deleting…": the delete button, the status buttons and the '
        'pencil are disabled until the server answered', (tester) async {
      await openDetail(tester);
      bookings.deletePending = Completer<void>();
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(find.text(adminDeleting), findsOneWidget);
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.edit))
            .onPressed,
        isNull,
      );
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
      expect(find.text(deletedText), findsNothing);

      // A second tap does nothing.
      await tester.tap(deleteButton, warnIfMissed: false);
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.deletes, hasLength(1));

      bookings.deletePending!.complete();
      await settle(tester);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsOneWidget);
      expect(bookings.deletes, hasLength(1));
    });

    testWidgets('the live read says "missing" before the server answered: '
        'no "does not exist" flashes; then the list with "Booking deleted."', (
      tester,
    ) async {
      await openDetail(tester);
      bookings.deletePending = Completer<void>();
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      bookings.emitBookingToAll(null);
      await settle(tester);

      expect(find.text(adminBookingMissing), findsNothing);
      expect(find.text(adminDeleting), findsOneWidget);
      expect(find.text('Delete Test One'), findsOneWidget);

      bookings.deletePending!.complete();
      await settle(tester);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsOneWidget);
    });

    testWidgets('"missing" first, then NO ANSWER from the server: the '
        'booking is gone, the list says "Booking deleted."', (tester) async {
      await openDetail(tester);
      bookings
        ..deletePending = Completer<void>()
        ..deleteError = const AdminBookingDeleteNoAnswer();
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);
      bookings.emitBookingToAll(null);
      await settle(tester);

      bookings.deletePending!.complete();
      await settle(tester);

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsOneWidget);
      expect(find.textContaining('No answer from the server'), findsNothing);
    });

    testWidgets('already deleted: the list, with its own words', (
      tester,
    ) async {
      await openDetail(tester);
      bookings.deleteResult = AdminBookingDeleteResult.alreadyDeleted;
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text('This booking was already deleted.'), findsOneWidget);
      expect(find.text(deletedText), findsNothing);
    });

    const texts = {
      AdminBookingDeleteFailure.noConnection: 'Not deleted. No connection.',
      AdminBookingDeleteFailure.refused: 'Not deleted. The change was refused.',
      AdminBookingDeleteFailure.statusChanged:
          'Not deleted. The status of this booking was changed elsewhere. '
          'Look at it again.',
      AdminBookingDeleteFailure.unknown: 'Not deleted. Please try again.',
    };
    for (final entry in texts.entries) {
      testWidgets('${entry.key.name}: "${entry.value}"; the booking stays '
          'and the button comes back', (tester) async {
        await openDetail(tester);
        bookings.deleteError = AdminBookingDeleteException(entry.key);
        await tapDelete(tester);
        await tester.tap(confirmDelete);
        await settle(tester);

        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
        expect(find.text('Delete Test One'), findsOneWidget);
        expect(find.text(adminDeleting), findsNothing);
        expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);
        expect(address(tester), detailAddress);
      });
    }

    testWidgets('no answer, and the booking is still shown: said so; when '
        'it goes after all, the page says "does not exist" by itself', (
      tester,
    ) async {
      await openDetail(tester);
      bookings.deleteError = const AdminBookingDeleteNoAnswer();
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(
        find.text(
          'No answer from the server. If the booking is still shown here, '
          'it was not deleted.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Not deleted'), findsNothing);
      expect(find.text('Delete Test One'), findsOneWidget);

      bookings.emitBookingToAll(null);
      await settle(tester);
      expect(find.text(adminBookingMissing), findsOneWidget);
    });

    testWidgets('the status changed while the question was open: nothing '
        'is sent, and it says so', (tester) async {
      await openDetail(tester, status: 'new');
      await tapDelete(tester);
      expect(dialogText(tester), contains('Status: New'));

      // Confirmed elsewhere, behind the open question.
      bookings.emitBookingToAll(
        rawBooking('b1', fullName: 'Delete Test One', status: 'confirmed'),
      );
      await settle(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(bookings.deletes, isEmpty);
      expect(
        find.textContaining('The status of this booking was changed'),
        findsOneWidget,
      );
      expect(find.byType(AdminBookingDetailScreen), findsOneWidget);
    });

    testWidgets('the message of a failed delete can be hidden', (tester) async {
      await openDetail(tester);
      bookings.deleteError = const AdminBookingDeleteException(
        AdminBookingDeleteFailure.noConnection,
      );
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      await tester.ensureVisible(find.byTooltip(adminDismissNotice));
      await tester.tap(find.byTooltip(adminDismissNotice));
      await settle(tester);

      expect(find.text('Not deleted. No connection.'), findsNothing);
    });
  });

  group('the notice on the list', () {
    Future<void> deleteAndLand(WidgetTester tester) async {
      await openDetail(tester);
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);
      expect(find.text(deletedText), findsOneWidget);
    }

    testWidgets('can be closed', (tester) async {
      await deleteAndLand(tester);

      await tester.tap(find.byTooltip(adminDismissNotice));
      await settle(tester);

      expect(find.text(deletedText), findsNothing);
      expect(containerOf(tester).read(adminDeletedNoticeProvider), isNull);
    });

    testWidgets('is gone after another booking was opened', (tester) async {
      await deleteAndLand(tester);

      await open(tester, '/admin/bookings/b2');
      bookings.emitBookingToAll(rawBooking('b2'));
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsNothing);
    });

    testWidgets('is gone after the "new booking" form was opened', (
      tester,
    ) async {
      await deleteAndLand(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsNothing);
    });

    testWidgets('is gone after the list was left', (tester) async {
      await deleteAndLand(tester);

      await open(tester, '/');
      expect(find.byType(CatalogScreen), findsOneWidget);
      await open(tester, '/admin');

      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsNothing);
    });

    testWidgets('is gone when the session ends, and does not come back '
        'with a new sign-in', (tester) async {
      await deleteAndLand(tester);

      auth.report(AdminSession.noAccess);
      await settle(tester);
      expect(find.byType(AdminNoAccessScreen), findsOneWidget);
      expect(containerOf(tester).read(adminDeletedNoticeProvider), isNull);

      auth.report(AdminSession.admin);
      await settle(tester);
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text(deletedText), findsNothing);
    });

    testWidgets('is not shown without a delete', (tester) async {
      await pumpApp(tester);
      await open(tester, '/admin');

      expect(find.text(deletedText), findsNothing);
      expect(find.byTooltip(adminDismissNotice), findsNothing);
    });

    testWidgets('fits a phone 320 wide', (tester) async {
      await openDetail(tester, size: const Size(320, 2800));
      await tapDelete(tester);
      await tester.tap(confirmDelete);
      await settle(tester);

      expect(find.text(deletedText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the marker by itself', () {
    testWidgets('is not set while nobody is signed in as an admin', (
      tester,
    ) async {
      await pumpApp(tester);
      auth.report(AdminSession.signedOut);
      await settle(tester);

      containerOf(tester)
          .read(adminDeletedNoticeProvider.notifier)
          .show(AdminDeletedNotice.deleted);

      expect(containerOf(tester).read(adminDeletedNoticeProvider), isNull);
    });

    testWidgets('holds only which of the two sentences to say', (tester) async {
      await pumpApp(tester);
      final notifier = containerOf(
        tester,
      ).read(adminDeletedNoticeProvider.notifier);

      notifier.show(AdminDeletedNotice.alreadyDeleted);
      expect(
        containerOf(tester).read(adminDeletedNoticeProvider),
        AdminDeletedNotice.alreadyDeleted,
      );
      notifier.clear();
      expect(containerOf(tester).read(adminDeletedNoticeProvider), isNull);
    });
  });
}
