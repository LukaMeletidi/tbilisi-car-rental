import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_fields.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_provider.dart';

/// The key of the price field of [extra], for tests.
Key adminExtraPriceFieldKey(Extra extra) =>
    ValueKey('admin-extra-price-${extra.name}');

/// The Extras & Prices page of Settings: the price per day of each of the
/// four extras. The router shows it only to an admin, and the Firestore
/// rules accept the write only from an admin. It behaves as the edit form
/// of a car.
///
/// It lies below Settings: Back returns to Settings, and so does a
/// successful save, with "Saved".
class AdminExtrasPricesScreen extends ConsumerWidget {
  const AdminExtrasPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminExtrasPricesProvider);
    final notifier = ref.read(adminExtrasPricesProvider.notifier);

    void toSettings() => context.go(AppRoutes.adminSettings);

    // After the server confirmed the save: "Saved", and back to Settings.
    ref.listen(adminExtrasPricesProvider, (previous, next) {
      if (next.notice != ExtrasSaveNotice.saved) return;
      if (previous?.notice == ExtrasSaveNotice.saved) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(adminExtrasSaved)));
      toSettings();
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save is running; with unsaved changes the admin is asked first.
    Future<void> back() async {
      final current = ref.read(adminExtrasPricesProvider);
      if (current.saving) return;
      if (!current.isDirty) {
        toSettings();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => const _DiscardDialog(),
      );
      if (discard == true && context.mounted) toSettings();
    }

    final backToSettings = FilledButton(
      onPressed: toSettings,
      child: const Text(adminBackToSettings),
    );

    final Widget body;
    switch (state.status) {
      case AdminExtrasPricesStatus.inactive:
      case AdminExtrasPricesStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminExtrasPricesStatus.unreadable:
        body = CatalogMessage(
          icon: Icons.warning_amber,
          text: adminExtrasUnreadable,
          action: backToSettings,
        );
      case AdminExtrasPricesStatus.failed:
        body = CatalogMessage(
          icon: Icons.cloud_off,
          text: adminExtrasFailureText(
            state.failure ?? ExtrasLoadFailure.other,
          ),
          action: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: notifier.retry,
                child: const Text(adminTryAgain),
              ),
              backToSettings,
            ],
          ),
        );
      case AdminExtrasPricesStatus.editing:
        body = state.draft == null
            ? const Center(child: CircularProgressIndicator())
            // A new version of the form gets a new key: the old text
            // controllers are disposed and new ones made from the draft.
            : _ExtrasForm(key: ValueKey(state.formVersion), state: state);
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

/// The form: the title, the note, the four fields on a white card, the
/// notices and Save.
class _ExtrasForm extends ConsumerStatefulWidget {
  const _ExtrasForm({super.key, required this.state});

  final AdminExtrasPricesState state;

  @override
  ConsumerState<_ExtrasForm> createState() => _ExtrasFormState();
}

class _ExtrasFormState extends ConsumerState<_ExtrasForm> {
  late final Map<Extra, TextEditingController> _controllers = {
    for (final extra in Extra.values)
      extra: TextEditingController(text: widget.state.draft![extra]),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(adminExtrasPricesProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final enabled = !state.saving && !state.locked;
    final showBanner =
        state.changedElsewhere &&
        notice != ExtrasSaveNotice.changedElsewhere &&
        !state.locked;

    /// Changes one price. The newest draft is read from the notifier, so
    /// two changes in the same moment do not undo each other.
    void change(Extra extra, String text) {
      final current = ref.read(adminExtrasPricesProvider).draft;
      if (current != null) notifier.setDraft({...current, extra: text});
    }

    void save() {
      FocusManager.instance.primaryFocus?.unfocus();
      notifier.save();
    }

    Widget noticeView(ExtrasSaveNotice notice) {
      final text = adminExtrasSaveNoticeText(notice);
      switch (notice) {
        case ExtrasSaveNotice.noAnswer:
          return AdminCarMessage(
            icon: Icons.help_outline,
            text: text,
            buttons: [
              FilledButton(onPressed: save, child: const Text(adminSaveAgain)),
              OutlinedButton(
                onPressed: notifier.loadCurrent,
                child: const Text(adminLoadCurrentPrices),
              ),
            ],
          );
        case ExtrasSaveNotice.changedElsewhere:
          return AdminCarMessage(
            icon: Icons.sync_problem,
            text: text,
            buttons: [
              OutlinedButton(
                onPressed: notifier.dismissNotice,
                child: const Text(adminKeepEditing),
              ),
              FilledButton(
                onPressed: notifier.loadCurrent,
                child: const Text(adminLoadCurrentPrices),
              ),
            ],
          );
        case ExtrasSaveNotice.saved:
        case ExtrasSaveNotice.noConnection:
        case ExtrasSaveNotice.refused:
        case ExtrasSaveNotice.unknown:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdminNote(icon: Icons.error_outline, text: text),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: adminDismissNotice,
                onPressed: notifier.dismissNotice,
              ),
            ],
          );
      }
    }

    const gap = SizedBox(height: 12);

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
                child: Text(
                  adminSettingsExtrasTitle,
                  style: textTheme.headlineSmall,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: AdminNote(
                  icon: Icons.info_outline,
                  text: adminExtrasNote,
                ),
              ),
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: AdminCarMessage(
                    icon: Icons.sync_problem,
                    text: adminExtrasChangedElsewhereBanner,
                    buttons: [
                      FilledButton(
                        onPressed: state.saving ? null : notifier.loadCurrent,
                        child: const Text(adminLoadCurrentPrices),
                      ),
                    ],
                  ),
                ),
              AppCard(
                child: _PriceFields(
                  controllers: _controllers,
                  problems: state.showErrors ? state.problems : const {},
                  enabled: enabled,
                  onChanged: change,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.saving) ...[
                      const AdminCarSaving(text: adminSaving),
                      gap,
                    ],
                    if (notice != null && !state.saving) ...[
                      noticeView(notice),
                      gap,
                    ],
                    if (state.showErrors &&
                        state.problems.isNotEmpty &&
                        !state.saving) ...[
                      const AdminNote(
                        icon: Icons.error_outline,
                        text: adminCorrectFields,
                      ),
                      gap,
                    ],
                    if (!state.locked)
                      FilledButton(
                        // Disabled while nothing changed and while a save
                        // runs.
                        onPressed: state.canSave ? save : null,
                        child: const Text(adminExtrasSave),
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

/// The four price fields. Built inside the white card, so Theme.of(context)
/// is the dark-on-white one.
class _PriceFields extends StatelessWidget {
  const _PriceFields({
    required this.controllers,
    required this.problems,
    required this.enabled,
    required this.onChanged,
  });

  final Map<Extra, TextEditingController> controllers;
  final Map<Extra, ExtraPriceProblem> problems;
  final bool enabled;
  final void Function(Extra extra, String text) onChanged;

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final extra in Extra.values) ...[
          if (extra != Extra.values.first) const SizedBox(height: 12),
          TextField(
            key: adminExtraPriceFieldKey(extra),
            controller: controllers[extra],
            enabled: enabled,
            keyboardType: decimal,
            autocorrect: false,
            onChanged: (text) => onChanged(extra, text),
            decoration: InputDecoration(
              labelText: adminExtraPriceLabel(extra),
              suffixText: adminExtrasPriceSuffix,
              errorText: problems[extra] == null
                  ? null
                  : adminExtraPriceProblemText(problems[extra]!),
              errorMaxLines: 3,
            ),
          ),
        ],
      ],
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
