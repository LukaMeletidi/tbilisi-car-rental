import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_created_booking_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_field_cards.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';

/// The "new booking" form of the admin area: a booking made by hand, for
/// example after a phone call. The router shows it only to an account with
/// the admin claim, and the Firestore rules accept the booking only from
/// such an account.
///
/// It lies below the bookings list: Back returns to the list. After the
/// server confirmed the booking, the detail of the new booking is opened.
class AdminBookingNewScreen extends ConsumerWidget {
  const AdminBookingNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminBookingNewProvider);

    void toList() => context.go(AppRoutes.admin);

    // The server confirmed that the booking exists: leave a one-time mark
    // for its detail, which then says "Saved", and open that detail. This
    // page is closed by that, and its form is forgotten with it: the next
    // "New booking" starts empty, with a new ID.
    ref.listen(adminBookingNewProvider, (previous, next) {
      final id = next.createdId;
      if (id == null || previous?.createdId == id) return;
      ref.read(adminCreatedBookingProvider.notifier).mark(id);
      context.go(AppRoutes.adminBooking(id));
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save or a check is running. When something would be lost the admin
    /// is asked first; when the booking may already exist, with the
    /// stronger words.
    Future<void> back() async {
      final current = ref.read(adminBookingNewProvider);
      if (current.saving) return;
      if (!current.hasSomethingToLose) {
        toList();
        return;
      }
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _LeaveDialog(mayAlreadyExist: current.mayAlreadyExist),
      );
      if (leave == true && context.mounted) toList();
    }

    return PopScope(
      // The system may close the page by itself only when nothing would be
      // lost. Otherwise it asks here first.
      canPop: !state.hasSomethingToLose && !state.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          leading: BackButton(onPressed: back),
          title: const AppBarLogo(),
        ),
        body: SafeArea(
          child: state.status == AdminBookingNewStatus.editing
              ? AdminBookingNewForm(state: state)
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

/// Asked before the form is left. White, with dark text.
///
/// Usually "Discard your changes?". When the server did not answer a save,
/// the booking may already exist; then the text says so and sends the
/// admin to the bookings list.
class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({required this.mayAlreadyExist});

  final bool mayAlreadyExist;

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(mayAlreadyExist ? adminLeaveTitle : adminDiscardTitle),
        content: mayAlreadyExist ? const Text(adminMayExistText) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(mayAlreadyExist ? adminStay : adminKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(mayAlreadyExist ? adminLeave : adminDiscard),
          ),
        ],
      ),
    );
  }
}

/// The fields of the "new booking" form, the total and the Save button.
///
/// The draft in the notifier is the single source of truth; this widget
/// shows it and reports what the admin does. [state] must be in the
/// "editing" status.
class AdminBookingNewForm extends ConsumerStatefulWidget {
  const AdminBookingNewForm({super.key, required this.state});

  final AdminBookingNewState state;

  @override
  ConsumerState<AdminBookingNewForm> createState() =>
      _AdminBookingNewFormState();
}

class _AdminBookingNewFormState extends ConsumerState<AdminBookingNewForm> {
  // One key per card, to scroll to the first card with an error.
  final _cardKeys = AdminFieldCardKeys();
  final _totalKey = GlobalKey();

  AdminBookingNewNotifier get _notifier =>
      ref.read(adminBookingNewProvider.notifier);

  /// Changes the draft. The newest draft is read from the notifier, so two
  /// changes in the same moment do not undo each other.
  void _change(
    AdminNewBookingDraft Function(AdminNewBookingDraft draft) change,
  ) {
    _notifier.setDraft(change(ref.read(adminBookingNewProvider).draft));
  }

  /// The text of the first of [candidates] the form has, after the first
  /// press of Save. The errors of the total are not shown at a field: the
  /// total card says in its own words why there is no total.
  String? _error(List<AdminBookingError> candidates) {
    final state = widget.state;
    if (!state.showErrors) return null;
    final errors = state.errors;
    for (final error in candidates) {
      if (errors.contains(error)) return adminBookingErrorText(error);
    }
    return null;
  }

  /// The errors that are shown at a field (all but those of the total).
  Set<AdminBookingError> _fieldErrors(Set<AdminBookingError> errors) => {
    for (final error in errors)
      if (_cardKeys.cardOf(error) != null) error,
  };

  /// Save: stage 1 and 2 run in the notifier. After "Saved" the screen
  /// leaves by itself; here only the first card with an error is shown.
  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _notifier.save();
    if (!mounted) return;
    final after = ref.read(adminBookingNewProvider);
    if (after.showErrors && after.notice == null) {
      _showFirstError(after.errors);
    }
  }

  void _showFirstError(Set<AdminBookingError> errors) {
    GlobalKey? key;
    for (final error in AdminBookingError.values) {
      if (errors.contains(error)) {
        key = _cardKeys.cardOf(error) ?? _totalKey;
        break;
      }
    }
    final target = key?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final draft = state.draft;
    // False while a save or a check runs, while the booking may already
    // exist, and after it was created: the form is locked then.
    final enabled = state.canEdit;
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final mayAlreadyExist = state.mayAlreadyExist;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(adminNewBookingTitle, style: textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
                  ],
                ),
              ),
              BookingSection(
                title: adminSectionStatus,
                child: AdminDropdown<BookingStatus>(
                  label: adminSectionStatus,
                  value: draft.status,
                  enabled: enabled,
                  items: [
                    for (final status in BookingStatus.values)
                      (value: status, label: adminStatusLabel(status)),
                  ],
                  onChanged: (status) =>
                      _change((d) => d.copyWith(status: status)),
                ),
              ),
              const SizedBox(height: 4),
              AdminBookingFieldCards(
                draft: draft.fields,
                onChanged: (change) =>
                    _change((d) => d.copyWith(fields: change(d.fields))),
                enabled: enabled,
                cars: state.cars,
                locations: state.locations,
                extrasPrices: state.extrasPrices,
                errorText: _error,
                keys: _cardKeys,
                // With the switch on, the e-mail field keeps its text but
                // is greyed out and not checked: a placeholder is stored.
                emailEnabled: !draft.noEmail,
                belowEmail: SwitchListTile(
                  value: draft.noEmail,
                  onChanged: enabled
                      ? (value) => _change((d) => d.copyWith(noEmail: value))
                      : null,
                  title: const Text(adminNoEmailSwitch),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                carsNotLoadedText: state.carsFailed
                    ? adminCarsLoadFailed
                    : adminCarsLoading,
                belowCar: state.carsFailed
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _notifier.reloadCars,
                          child: const Text(adminTryAgain),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              BookingSection(
                key: _totalKey,
                title: adminSectionTotal,
                child: _TotalLine(total: state.total),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.saving) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(mayAlreadyExist ? adminChecking : adminSaving),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (notice != null &&
                        notice != AdminBookingCreateNotice.saved &&
                        !state.saving) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AdminNote(
                              icon: mayAlreadyExist
                                  ? Icons.help_outline
                                  : Icons.error_outline,
                              text: adminCreateNoticeText(notice),
                            ),
                          ),
                          // While the booking may exist the message stays.
                          if (!mayAlreadyExist)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: adminDismissNotice,
                              onPressed: _notifier.dismissNotice,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.showErrors &&
                        _fieldErrors(state.errors).isNotEmpty &&
                        !state.saving) ...[
                      const AdminNote(
                        icon: Icons.error_outline,
                        text: adminCorrectFields,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (mayAlreadyExist)
                      // The form is locked; the only way on is to ask the
                      // server again, with the same ID and the same values.
                      FilledButton(
                        onPressed: state.canCheckAgain
                            ? _notifier.checkAgain
                            : null,
                        child: const Text(adminCheckAgain),
                      )
                    else
                      FilledButton(
                        // Disabled while nothing is filled in, while a save
                        // runs, and while the prices are not loaded.
                        onPressed: state.canSave ? _save : null,
                        child: const Text(adminSave),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The total of a new booking, or why there is none yet. Built inside the
/// white card. It never shows the text the edit form has for "no new
/// total" ("Keep the stored total."): a new booking has no stored total.
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.total});

  final AdminNewTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final hasTotal =
        total.state == AdminNewTotalState.ready ||
        total.state == AdminNewTotalState.tooHigh;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          adminNewBookingTotalText(total),
          style: hasTotal ? textTheme.bodyLarge : textTheme.bodyMedium,
        ),
        if (hasTotal) ...[
          const SizedBox(height: 2),
          Text(adminTotalUsesTodaysPrices, style: textTheme.bodySmall),
        ],
        if (total.state == AdminNewTotalState.tooHigh) ...[
          const SizedBox(height: 4),
          Text(
            adminBookingErrorText(AdminBookingError.totalTooHigh),
            style: textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
