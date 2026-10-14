import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_filter_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_deleted_notice_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_bookings_controls.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';

/// The first page of the admin area: all bookings, newest first, live and
/// read only. The router shows it only to an account with the admin claim,
/// and the Firestore rules give the data only to such an account.
class AdminBookingsScreen extends ConsumerWidget {
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminBookingsProvider);
    final notifier = ref.read(adminBookingsProvider.notifier);
    // Set by the detail right after a booking was deleted; shown once.
    final deleted = ref.watch(adminDeletedNoticeProvider);

    final Widget body;
    switch (state.status) {
      case AdminBookingsStatus.inactive:
      case AdminBookingsStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminBookingsStatus.failed:
        final failure = state.failure ?? AdminBookingsFailure.other;
        body = CatalogMessage(
          icon: failure == AdminBookingsFailure.permissionDenied
              ? Icons.lock_outline
              : Icons.cloud_off,
          text: adminBookingsFailureText(failure),
          action: FilledButton(
            onPressed: notifier.retry,
            child: const Text(adminTryAgain),
          ),
        );
      case AdminBookingsStatus.ready:
        body = state.bookings.isEmpty && state.unreadable.isEmpty
            ? const CatalogMessage(icon: Icons.inbox, text: adminNoBookings)
            : _BookingsList(state: state, onLoadMore: notifier.loadMore);
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        title: const AppBarLogo(),
        automaticallyImplyLeading: false,
        // Closes the bookings listener first, then signs out.
        actions: const [AdminSignOutButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Above everything, so it is seen also when the list is empty.
            if (deleted != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: carDetailMaxWidth,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdminNote(
                            icon: Icons.check_circle_outline,
                            text: adminDeletedNoticeText(deleted),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: adminDismissNotice,
                          onPressed: ref
                              .read(adminDeletedNoticeProvider.notifier)
                              .clear,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
      // Always there on this page, also for an empty list. White with
      // purple text, like the filled buttons of the app.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.adminBookingNew),
        backgroundColor: Colors.white,
        foregroundColor: appBackgroundColor,
        icon: const Icon(Icons.add),
        label: const Text(adminNewBookingTitle),
      ),
    );
  }
}

/// The room left free under the last row of the list, so that the
/// floating "New booking" button never covers the last booking or "Load
/// more": the height of the button (56), its distance from the edge (16)
/// and some air.
const adminListBottomSpace = 96.0;

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.state, required this.onLoadMore});

  final AdminBookingsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final unreadable = state.unreadable;
    // The loaded bookings with the admin's status, search and order applied.
    final view = ref.watch(adminBookingsViewProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adminBookingsTitle, style: textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
                  if (state.showOfflineNote) ...[
                    const SizedBox(height: 8),
                    const AdminNote(
                      icon: Icons.cloud_off,
                      text: adminOfflineNote,
                    ),
                  ],
                  if (unreadable.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AdminNote(
                      icon: Icons.warning_amber,
                      text: adminUnreadableBookings(unreadable.length),
                    ),
                    // For the developer only: which documents, and why.
                    // The ID and the reason, never the contents.
                    if (kDebugMode)
                      for (final document in unreadable)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, top: 2),
                          child: Text(
                            '${document.id}: ${document.reason}',
                            style: textTheme.bodySmall,
                          ),
                        ),
                  ],
                ],
              ),
            ),
            if (state.bookings.isNotEmpty) ...[
              AdminBookingsControls(view: view),
              // Only while older bookings exist that are not loaded: the
              // filter, the counts and the order do not know them.
              if (state.hasMore)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    adminLoadedOnlyNote(view.loadedCount),
                    style: textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
            ],
            for (final booking in view.visible)
              AdminBookingCard(
                booking: booking,
                car: adminCarLabel(booking.carId, state.carsById),
                onTap: booking.id == null
                    ? null
                    : () => context.go(AppRoutes.adminBooking(booking.id!)),
              ),
            if (state.bookings.isNotEmpty && view.visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(adminNoMatch, style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: ref
                          .read(adminBookingsFilterProvider.notifier)
                          .clear,
                      child: const Text(adminClearFilters),
                    ),
                  ],
                ),
              ),
            if (state.hasMore) ...[
              const SizedBox(height: 8),
              Center(
                child: state.loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      )
                    : FilledButton(
                        onPressed: onLoadMore,
                        child: const Text(adminLoadMore),
                      ),
              ),
            ],
            const SizedBox(height: adminListBottomSpace),
          ],
        ),
      ),
    );
  }
}
