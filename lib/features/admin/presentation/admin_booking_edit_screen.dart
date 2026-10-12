import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_edit_form.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';

/// The edit form of one booking of the admin area. The router shows it
/// only to an account with the admin claim, and the Firestore rules accept
/// a change only from such an account.
///
/// It lies below the detail of the booking: Back returns to the detail,
/// and so does a successful save.
class AdminBookingEditScreen extends ConsumerWidget {
  const AdminBookingEditScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminBookingEditProvider(bookingId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    void toDetail() => context.go(AppRoutes.adminBooking(bookingId));

    // After the server confirmed the edit: tell the detail to say "Saved"
    // (the notice it already has for a status change) and return to it.
    ref.listen(provider, (previous, next) {
      if (next.notice != AdminBookingSaveNotice.saved) return;
      if (previous?.notice == AdminBookingSaveNotice.saved) return;
      ref.read(adminBookingDetailProvider(bookingId).notifier).showSaved();
      toDetail();
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save is running; with unsaved changes the admin is asked first.
    Future<void> back() async {
      final current = ref.read(provider);
      if (current.saving) return;
      if (!current.isDirty) {
        toDetail();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => const _DiscardDialog(),
      );
      if (discard == true && context.mounted) toDetail();
    }

    final backToBookings = FilledButton(
      onPressed: () => context.go(AppRoutes.admin),
      child: const Text(adminBackToBookings),
    );

    final Widget body;
    switch (state.status) {
      case AdminBookingEditStatus.inactive:
      case AdminBookingEditStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminBookingEditStatus.missing:
        body = CatalogMessage(
          icon: Icons.search_off,
          text: adminBookingMissing,
          action: backToBookings,
        );
      case AdminBookingEditStatus.unreadable:
        body = CatalogMessage(
          icon: Icons.warning_amber,
          text: adminBookingUnreadable,
          action: backToBookings,
        );
      case AdminBookingEditStatus.failed:
        final failure = state.failure ?? AdminBookingsFailure.other;
        body = CatalogMessage(
          icon: failure == AdminBookingsFailure.permissionDenied
              ? Icons.lock_outline
              : Icons.cloud_off,
          text: adminBookingFailureText(failure),
          action: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: notifier.retry,
                child: const Text(adminTryAgain),
              ),
              backToBookings,
            ],
          ),
        );
      case AdminBookingEditStatus.editing:
        body = state.base == null || state.draft == null
            ? const Center(child: CircularProgressIndicator())
            // A new version of the form gets a new key: Flutter then
            // disposes the old form with its text controllers and builds
            // a new one from the draft.
            : AdminBookingEditForm(
                key: ValueKey(state.formVersion),
                bookingId: bookingId,
                state: state,
              );
    }

    return PopScope(
      // The system may close the page by itself only when nothing would be
      // lost. Otherwise it asks here first.
      canPop: !state.isDirty && !state.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          leading: BackButton(onPressed: back),
          title: const AppBarLogo(),
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

/// "Discard your changes?" before the form is left with unsaved changes.
/// White, with dark text.
class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog();

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(adminDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(adminKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(adminDiscard),
          ),
        ],
      ),
    );
  }
}
