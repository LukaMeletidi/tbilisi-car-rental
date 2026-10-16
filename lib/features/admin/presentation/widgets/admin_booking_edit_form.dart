import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_field_cards.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_conflict_dialog.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_price_card.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';

/// The fields of the edit form, the price card and the Save button.
///
/// The draft in the notifier is the single source of truth. This widget
/// only shows it and reports what the admin does. The text controllers are
/// made from the draft once, when this widget is created (they live in
/// [AdminBookingFieldCards]), and typing reports every change to the
/// notifier. When the notifier itself replaces the fields ("Load the
/// current booking", a change elsewhere while the form has no changes),
/// the screen builds this widget anew with a key made from
/// [AdminBookingEditState.formVersion]: the old controllers are disposed
/// and new ones are made from the new draft.
///
/// [state] must be in the "editing" status.
class AdminBookingEditForm extends ConsumerStatefulWidget {
  const AdminBookingEditForm({
    super.key,
    required this.bookingId,
    required this.state,
  });

  final String bookingId;
  final AdminBookingEditState state;

  @override
  ConsumerState<AdminBookingEditForm> createState() =>
      _AdminBookingEditFormState();
}

class _AdminBookingEditFormState extends ConsumerState<AdminBookingEditForm> {
  // One key per card, to scroll to the first card with an error.
  final _cardKeys = AdminFieldCardKeys();
  final _totalKey = GlobalKey();

  // The parts for which the admin chose "Keep editing" on the banner.
  Set<AdminBookingField> _bannerHiddenFor = const {};

  AdminBookingEditNotifier get _notifier =>
      ref.read(adminBookingEditProvider(widget.bookingId).notifier);

  /// Changes the draft. The newest draft is read from the notifier, so two
  /// changes in the same moment do not undo each other.
  void _change(AdminBookingDraft Function(AdminBookingDraft draft) change) {
    final draft = ref.read(adminBookingEditProvider(widget.bookingId)).draft;
    if (draft != null) _notifier.setDraft(change(draft));
  }

  /// The text of the first of [candidates] the form has. An error is shown
  /// after the first press of Save; a stored value in a wrong format at
  /// once, because nothing can be saved until it is corrected.
  String? _error(List<AdminBookingError> candidates) {
    final state = widget.state;
    final errors = state.errors;
    for (final error in candidates) {
      if (!errors.contains(error)) continue;
      if (state.showErrors || storedFormatErrorKinds.contains(error)) {
        return adminBookingErrorText(error);
      }
    }
    return null;
  }

  /// Save: stage 1 and 2 run in the notifier. After "Saved" the screen
  /// leaves by itself; here only the first card with an error is shown.
  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = adminBookingEditProvider(widget.bookingId);
    await ref
        .read(provider.notifier)
        .save(
          // The conflict dialog; "Cancel" when the form is gone.
          decide: (outcome) => mounted
              ? confirmDespiteConflicts(context, outcome)
              : Future.value(false),
        );
    if (!mounted) return;
    final after = ref.read(provider);
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
    final base = state.base!;
    final draft = state.draft!;
    final totals = state.totals!;
    final enabled = !state.saving;
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;

    final changedElsewhere = [
      for (final field in AdminBookingField.values)
        if (state.changedElsewhere.contains(field)) field,
    ];
    final showBanner =
        changedElsewhere.isNotEmpty &&
        notice != AdminBookingSaveNotice.conflict &&
        !setEquals(changedElsewhere.toSet(), _bannerHiddenFor);

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
                    Text(adminEditTitle, style: textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(adminTbilisiTimeNote, style: textTheme.bodySmall),
                  ],
                ),
              ),
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: _MessageWithChoices(
                    icon: Icons.sync_problem,
                    text: adminChangedElsewhereBanner([
                      for (final field in changedElsewhere) field.storedKey,
                    ]),
                    onKeepEditing: () => setState(
                      () => _bannerHiddenFor = changedElsewhere.toSet(),
                    ),
                    onLoadCurrent: enabled ? _notifier.loadCurrent : null,
                  ),
                ),
              AdminBookingFieldCards(
                draft: draft,
                onChanged: _change,
                enabled: enabled,
                cars: state.cars,
                locations: state.locations,
                extrasPrices: state.extrasPrices,
                errorText: _error,
                keys: _cardKeys,
                storedPickupLocation: base.pickupLocation,
                storedDropoffLocation: base.dropoffLocation,
              ),
              const SizedBox(height: 4),
              BookingSection(
                key: _totalKey,
                title: adminSectionTotal,
                child: AdminPriceCard(
                  totals: totals,
                  choice: draft.totalChoice,
                  enabled: enabled,
                  onChoose: _notifier.chooseTotal,
                ),
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
                          Text(state.checking ? adminChecking : adminSaving),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (notice != null && !state.saving) ...[
                      if (notice == AdminBookingSaveNotice.conflict)
                        _MessageWithChoices(
                          icon: Icons.sync_problem,
                          text: adminSaveNoticeText(
                            notice,
                            fields: state.noticeFields,
                          ),
                          onKeepEditing: _notifier.dismissNotice,
                          onLoadCurrent: _notifier.loadCurrent,
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AdminNote(
                                icon: notice == AdminBookingSaveNotice.noAnswer
                                    ? Icons.help_outline
                                    : Icons.error_outline,
                                text: adminSaveNoticeText(
                                  notice,
                                  fields: state.noticeFields,
                                ),
                              ),
                            ),
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
                        state.errors.isNotEmpty &&
                        !state.saving) ...[
                      const AdminNote(
                        icon: Icons.error_outline,
                        text: adminCorrectFields,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      // Disabled while nothing changed, while a save runs,
                      // and while a needed choice of the total is missing.
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

/// A message on the purple page with the two ways on: "Keep editing" and
/// "Load the current booking". Used before a save (the banner) and after a
/// refused one (the conflict).
class _MessageWithChoices extends StatelessWidget {
  const _MessageWithChoices({
    required this.icon,
    required this.text,
    required this.onKeepEditing,
    required this.onLoadCurrent,
  });

  final IconData icon;
  final String text;
  final VoidCallback onKeepEditing;
  final VoidCallback? onLoadCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminNote(icon: icon, text: text),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: onKeepEditing,
              child: const Text(adminKeepEditing),
            ),
            FilledButton(
              onPressed: onLoadCurrent,
              child: const Text(adminLoadCurrent),
            ),
          ],
        ),
      ],
    );
  }
}
