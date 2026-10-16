import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/admin_calendar_provider.dart';
import 'package:tbilisi_car_rental/features/calendar/presentation/widgets/calendar_grid_view.dart';

/// The Calendar section of the admin area: the confirmed bookings of the
/// next 14 days, one row per car, in Tbilisi time. Read only. A tap on a
/// booking opens its detail in the Bookings section. The router shows it
/// only to an admin.
///
/// The grid is drawn only from answers of the server
/// (AdminCalendarNotifier): without them the screen says "loading" or "no
/// connection", never "no bookings".
class AdminCalendarScreen extends ConsumerWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(adminCalendarProvider);
    final notifier = ref.read(adminCalendarProvider.notifier);
    final today = CalendarDay.ofUtc(ref.read(clockProvider)());

    final List<Widget> content;
    switch (state.status) {
      case AdminCalendarStatus.inactive:
      case AdminCalendarStatus.loading:
        content = const [
          _Message(icon: null, text: adminCalendarLoading, busy: true),
        ];
      case AdminCalendarStatus.failed:
        final failure = state.failure ?? AdminBookingsFailure.other;
        content = [
          _Message(
            icon: failure == AdminBookingsFailure.permissionDenied
                ? Icons.lock_outline
                : Icons.cloud_off,
            text: adminCalendarFailureText(failure),
            action: FilledButton(
              onPressed: notifier.retry,
              child: const Text(adminTryAgain),
            ),
          ),
        ];
      case AdminCalendarStatus.ready:
        content = state.rows.isEmpty
            ? const [
                _Message(icon: Icons.directions_car, text: adminCalendarNoCars),
              ]
            : [
                CalendarGridView(
                  window: state.window,
                  rows: state.rows,
                  today: today,
                  onOpenBooking: (id) => context.go(AppRoutes.adminBooking(id)),
                ),
                if (!calendarHasBars(state.rows)) ...[
                  const SizedBox(height: 12),
                  const Text(adminCalendarNoBookings),
                ],
              ];
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
        actions: const [AdminSignOutButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(adminCalendarTitle, style: textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
            const SizedBox(height: 8),
            _Controls(
              window: state.window,
              startsToday: state.window.first == today,
              onPrevious: notifier.showPrevious,
              onToday: notifier.showToday,
              onNext: notifier.showNext,
            ),
            if (state.status == AdminCalendarStatus.ready &&
                state.showOfflineNote) ...[
              const SizedBox(height: 8),
              const AdminNote(icon: Icons.cloud_off, text: adminOfflineNote),
            ],
            if (state.status == AdminCalendarStatus.ready &&
                state.unreadable > 0) ...[
              const SizedBox(height: 8),
              AdminNote(
                icon: Icons.warning_amber,
                text: adminCalendarUnreadable(state.unreadable),
              ),
            ],
            const SizedBox(height: 12),
            ...content,
          ],
        ),
      ),
    );
  }
}

/// Previous 7 days, Today, Next 7 days, and the days shown.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.window,
    required this.startsToday,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final CalendarWindow window;
  final bool startsToday;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: adminCalendarPrevious,
          onPressed: onPrevious,
        ),
        OutlinedButton(
          onPressed: startsToday ? null : onToday,
          child: const Text(adminCalendarToday),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: adminCalendarNext,
          onPressed: onNext,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            calendarRangeText(window),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// An icon (or a spinner) and a line, with an optional button below; for
/// the loading, error and empty states.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.busy = false,
    this.action,
  });

  final IconData? icon;
  final String text;
  final bool busy;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          if (busy)
            const CircularProgressIndicator()
          else if (icon != null)
            Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
