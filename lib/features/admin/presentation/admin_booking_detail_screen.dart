import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_place_text.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_rental.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

/// One booking of the admin area: everything that is stored, live, and the
/// change of its status. The router shows it only to an account with the
/// admin claim, and the Firestore rules give and take the data only for
/// such an account.
class AdminBookingDetailScreen extends ConsumerWidget {
  const AdminBookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  /// Asks first when the change is hard on the customer, then changes.
  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    BookingStatus from,
    BookingStatus to,
  ) async {
    if (statusChangeNeedsConfirmation(from: from, to: to)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmDialog(from: from, to: to),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await ref
        .read(adminBookingDetailProvider(bookingId).notifier)
        .changeStatus(to);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminBookingDetailProvider(bookingId));
    final notifier = ref.read(adminBookingDetailProvider(bookingId).notifier);
    final booking = state.booking;
    final notice = state.notice;

    void back() => context.go(AppRoutes.admin);
    final backButton = FilledButton(
      onPressed: back,
      child: const Text(adminBackToBookings),
    );

    final Widget body;
    switch (state.status) {
      case AdminBookingDetailStatus.inactive:
      case AdminBookingDetailStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminBookingDetailStatus.missing:
        body = CatalogMessage(
          icon: Icons.search_off,
          text: adminBookingMissing,
          // After a change that found the booking gone.
          detail: notice == null
              ? null
              : adminStatusNoticeText(notice, fields: state.noticeFields),
          action: backButton,
        );
      case AdminBookingDetailStatus.unreadable:
        body = CatalogMessage(
          icon: Icons.warning_amber,
          text: adminBookingUnreadable,
          // For the developer only: which field is wrong. Never the
          // contents of the document.
          detail: kDebugMode ? state.unreadableReason : null,
          action: backButton,
        );
      case AdminBookingDetailStatus.failed:
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
              backButton,
            ],
          ),
        );
      case AdminBookingDetailStatus.found:
        body = booking == null
            ? const Center(child: CircularProgressIndicator())
            : _Detail(
                bookingId: bookingId,
                state: state,
                booking: booking,
                onChange: (to) => _change(context, ref, booking.status, to),
                onDismissNotice: notifier.dismissNotice,
              );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        leading: BackButton(onPressed: back),
        title: const AppBarLogo(),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.bookingId,
    required this.state,
    required this.booking,
    required this.onChange,
    required this.onDismissNotice,
  });

  final String bookingId;
  final AdminBookingDetailState state;
  final Booking booking;
  final ValueChanged<BookingStatus> onChange;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                  Text(adminBookingTitle, style: textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
                  if (state.showOfflineNote) ...[
                    const SizedBox(height: 8),
                    const AdminNote(
                      icon: Icons.cloud_off,
                      text: adminOfflineNote,
                    ),
                  ],
                ],
              ),
            ),
            BookingSection(
              title: adminSectionStatus,
              child: _StatusContent(
                status: booking.status,
                saving: state.saving,
                notice: state.notice,
                noticeFields: state.noticeFields,
                onChange: onChange,
                onDismissNotice: onDismissNotice,
              ),
            ),
            const SizedBox(height: 4),
            BookingSection(
              title: adminSectionCustomer,
              child: _CustomerContent(
                customer: booking.customer,
                language: booking.language,
              ),
            ),
            const SizedBox(height: 4),
            BookingSection(
              title: adminSectionRental,
              child: _RentalContent(booking: booking, car: state.car),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
              child: SelectableText(
                adminBookingIdText(bookingId),
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The status as the live read last delivered it, and the buttons that
/// change it. Built inside the white card.
class _StatusContent extends StatelessWidget {
  const _StatusContent({
    required this.status,
    required this.saving,
    required this.notice,
    required this.noticeFields,
    required this.onChange,
    required this.onDismissNotice,
  });

  final BookingStatus status;
  final bool saving;
  final AdminStatusChangeNotice? notice;
  final List<String> noticeFields;
  final ValueChanged<BookingStatus> onChange;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The same chip, word and colour as in the list.
        AdminStatusChip(status: status),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in selectableStatuses(status))
              OutlinedButton(
                // Disabled while a change is running: no second change.
                onPressed: saving ? null : () => onChange(choice),
                child: Text(adminChangeTo(choice)),
              ),
          ],
        ),
        if (saving) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(adminSaving),
            ],
          ),
        ],
        if (notice != null && !saving) ...[
          const SizedBox(height: 8),
          _NoticeLine(
            notice: notice,
            fields: noticeFields,
            onDismiss: onDismissNotice,
          ),
        ],
      ],
    );
  }
}

/// What happened to the last attempt, as words; the icon only supports
/// them.
class _NoticeLine extends StatelessWidget {
  const _NoticeLine({
    required this.notice,
    required this.fields,
    required this.onDismiss,
  });

  final AdminStatusChangeNotice notice;
  final List<String> fields;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    switch (notice) {
      case AdminStatusChangeNotice.saved:
        icon = Icons.check_circle_outline;
        color = adminStatusColor(BookingStatus.confirmed);
      case AdminStatusChangeNotice.noAnswer:
        icon = Icons.help_outline;
        color = scheme.onSurface;
      case AdminStatusChangeNotice.noConnection:
      case AdminStatusChangeNotice.refused:
      case AdminStatusChangeNotice.bookingMissing:
      case AdminStatusChangeNotice.unknownFields:
      case AdminStatusChangeNotice.noCreatedAt:
      case AdminStatusChangeNotice.unknown:
        icon = Icons.error_outline;
        color = scheme.error;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(adminStatusNoticeText(notice, fields: fields))),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: adminDismissNotice,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}

/// Built inside the white card.
class _CustomerContent extends StatelessWidget {
  const _CustomerContent({required this.customer, required this.language});

  final BookingCustomer customer;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final messengers = [
      if (customer.whatsapp) adminOnWhatsapp,
      if (customer.telegram) adminOnTelegram,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: adminLabelName,
          children: [Text(customer.fullName, style: style)],
        ),
        _Field(
          label: adminLabelPhone,
          children: [
            // Selectable, so the number can be copied into a phone app.
            SelectableText(customer.phone, style: style),
            if (messengers.isNotEmpty) Text(messengers.join(', ')),
          ],
        ),
        _Field(
          label: adminLabelEmail,
          children: [SelectableText(customer.email, style: style)],
        ),
        _Field(
          label: adminLabelLanguage,
          isLast: true,
          children: [Text(adminLanguageLabel(language), style: style)],
        ),
      ],
    );
  }
}

/// Built inside the white card. Every value is the stored one: the days
/// follow from the two stored dates and the total is the stored total.
/// Only the names of the fixed places are looked up in settings.
class _RentalContent extends ConsumerWidget {
  const _RentalContent({required this.booking, required this.car});

  final Booking booking;
  final AdminCarLabel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodyLarge;
    // Null while the places are loading or could not be loaded.
    final locations = ref.watch(pickupLocationsProvider).value;
    final createdAt = booking.createdAt;
    final createdBy = booking.createdBy;

    String place(BookingLocation location) =>
        bookingPlaceText(
          location,
          locations: locations,
          language: AppLanguage.en,
        ) ??
        adminUnknownPlace;

    final daysAndTotal = [
      adminDays(booking.rentalDays),
      adminAmount(booking.totalPrice),
      // More than 7 days: the total is only an estimate.
      if (booking.isIndividualPrice) adminEstimate,
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: adminLabelCar,
          children: [Text(adminCarText(car), style: style)],
        ),
        _Field(
          label: adminLabelPickup,
          children: [
            Text(formatAdminUtc(booking.pickup), style: style),
            Text(place(booking.pickupLocation), style: style),
          ],
        ),
        _Field(
          label: adminLabelDropoff,
          children: [
            Text(formatAdminUtc(booking.dropoff), style: style),
            Text(place(booking.dropoffLocation), style: style),
          ],
        ),
        _Field(
          label: adminLabelExtras,
          children: booking.extras.isEmpty
              ? [Text(adminNoExtras, style: style)]
              : [
                  for (final extra in Extra.values)
                    if (booking.extras.contains(extra))
                      Text(adminExtraName(extra), style: style),
                ],
        ),
        if (booking.notes.trim().isNotEmpty)
          _Field(
            label: adminLabelNotes,
            children: [Text(booking.notes, style: style)],
          ),
        _Field(
          label: adminLabelTotal,
          isLast: createdAt == null && createdBy == null,
          children: [Text(daysAndTotal, style: style)],
        ),
        if (createdAt != null)
          Text(
            adminReceived(formatAdminUtc(createdAt)),
            style: textTheme.bodySmall,
          ),
        if (createdBy != null && createdBy.trim().isNotEmpty)
          Text(adminCreatedBy(createdBy), style: textTheme.bodySmall),
      ],
    );
  }
}

/// A small label with one or more lines under it.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.children,
    this.isLast = false,
  });

  final String label;
  final List<Widget> children;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          ...children,
        ],
      ),
    );
  }
}

/// "Are you sure?" before a change that is hard on the customer. White,
/// with dark text.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.from, required this.to});

  final BookingStatus from;
  final BookingStatus to;

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(adminConfirmTitle),
        content: Text(adminConfirmText(from, to)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(adminConfirmNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(adminConfirmYes),
          ),
        ],
      ),
    );
  }
}
