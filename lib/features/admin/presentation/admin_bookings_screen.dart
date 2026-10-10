import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_card.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';

/// The first page of the admin area: all bookings, newest first, live and
/// read only. The router shows it only to an account with the admin claim,
/// and the Firestore rules give the data only to such an account.
class AdminBookingsScreen extends ConsumerWidget {
  const AdminBookingsScreen({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    // First close the bookings listener, then sign out: nothing is
    // listening when the sign-in token goes away.
    ref.read(adminBookingsProvider.notifier).stop();
    try {
      await ref.read(adminSignInProvider.notifier).signOut();
    } catch (_) {
      // Still signed in: bring the list back.
      ref.invalidate(adminBookingsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminBookingsProvider);
    final notifier = ref.read(adminBookingsProvider.notifier);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: adminSignOutButton,
            onPressed: () => _signOut(ref),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _BookingsList extends StatelessWidget {
  const _BookingsList({required this.state, required this.onLoadMore});

  final AdminBookingsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unreadable = state.unreadable;

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
                    const _Note(icon: Icons.cloud_off, text: adminOfflineNote),
                  ],
                  if (unreadable.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _Note(
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
            for (final booking in state.bookings)
              AdminBookingCard(
                booking: booking,
                car: adminCarLabel(booking.carId, state.carsById),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// A short line with an icon, on the purple page.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
