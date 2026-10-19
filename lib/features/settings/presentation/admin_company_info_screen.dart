import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_fields.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_provider.dart';

/// The text fields of the form, one controller each.
enum CompanyFormField {
  name,
  phone,
  email,
  addressKa,
  addressRu,
  addressEn,
  hoursKa,
  hoursRu,
  hoursEn,
  mapUrl,
  facebook,
  instagram,
  whatsapp,
  telegram,
}

/// The key of the text field [field], for tests.
Key adminCompanyFieldKey(CompanyFormField field) =>
    ValueKey('admin-company-${field.name}');

/// The Company Info page of Settings: what About Us shows. The router
/// shows it only to an admin, and the Firestore rules accept the write only
/// from an admin. It behaves as the Extras & Prices form.
///
/// It lies below Settings: Back returns to Settings, and so does a
/// successful save, with "Saved".
class AdminCompanyInfoScreen extends ConsumerWidget {
  const AdminCompanyInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCompanyInfoProvider);
    final notifier = ref.read(adminCompanyInfoProvider.notifier);

    void toSettings() => context.go(AppRoutes.adminSettings);

    // After the server confirmed the save: "Saved", and back to Settings.
    ref.listen(adminCompanyInfoProvider, (previous, next) {
      if (next.notice != CompanySaveNotice.saved) return;
      if (previous?.notice == CompanySaveNotice.saved) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(adminCompanySaved)));
      toSettings();
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save is running; with unsaved changes the admin is asked first.
    Future<void> back() async {
      final current = ref.read(adminCompanyInfoProvider);
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
      case AdminCompanyInfoStatus.inactive:
      case AdminCompanyInfoStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminCompanyInfoStatus.unreadable:
        body = CatalogMessage(
          icon: Icons.warning_amber,
          text: adminCompanyUnreadable,
          action: backToSettings,
        );
      case AdminCompanyInfoStatus.failed:
        body = CatalogMessage(
          icon: Icons.cloud_off,
          text: adminCompanyFailureText(
            state.failure ?? CompanyLoadFailure.other,
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
      case AdminCompanyInfoStatus.editing:
        body = state.draft == null
            ? const Center(child: CircularProgressIndicator())
            // A new version of the form gets a new key: the old text
            // controllers are disposed and new ones made from the draft.
            : _CompanyForm(key: ValueKey(state.formVersion), state: state);
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

/// The text of [field] in [input].
String _textOf(CompanyInput input, CompanyFormField field) {
  switch (field) {
    case CompanyFormField.name:
      return input.name;
    case CompanyFormField.phone:
      return input.phone;
    case CompanyFormField.email:
      return input.email;
    case CompanyFormField.addressKa:
      return input.address.ka;
    case CompanyFormField.addressRu:
      return input.address.ru;
    case CompanyFormField.addressEn:
      return input.address.en;
    case CompanyFormField.hoursKa:
      return input.workingHours.ka;
    case CompanyFormField.hoursRu:
      return input.workingHours.ru;
    case CompanyFormField.hoursEn:
      return input.workingHours.en;
    case CompanyFormField.mapUrl:
      return input.mapUrl;
    case CompanyFormField.facebook:
      return input.social[CompanySocialLink.facebook] ?? '';
    case CompanyFormField.instagram:
      return input.social[CompanySocialLink.instagram] ?? '';
    case CompanyFormField.whatsapp:
      return input.social[CompanySocialLink.whatsapp] ?? '';
    case CompanyFormField.telegram:
      return input.social[CompanySocialLink.telegram] ?? '';
  }
}

/// The form: the title, the note, the six cards, the notices and Save.
class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({super.key, required this.state});

  final AdminCompanyInfoState state;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  late final Map<CompanyFormField, TextEditingController> _controllers = {
    for (final field in CompanyFormField.values)
      field: TextEditingController(text: _textOf(widget.state.draft!, field)),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The whole form as the admin typed it now.
  CompanyInput _input() {
    String text(CompanyFormField field) => _controllers[field]!.text;
    return CompanyInput(
      name: text(CompanyFormField.name),
      phone: text(CompanyFormField.phone),
      email: text(CompanyFormField.email),
      address: LocalizedText(
        ka: text(CompanyFormField.addressKa),
        ru: text(CompanyFormField.addressRu),
        en: text(CompanyFormField.addressEn),
      ),
      workingHours: LocalizedText(
        ka: text(CompanyFormField.hoursKa),
        ru: text(CompanyFormField.hoursRu),
        en: text(CompanyFormField.hoursEn),
      ),
      mapUrl: text(CompanyFormField.mapUrl),
      social: {
        CompanySocialLink.facebook: text(CompanyFormField.facebook),
        CompanySocialLink.instagram: text(CompanyFormField.instagram),
        CompanySocialLink.whatsapp: text(CompanyFormField.whatsapp),
        CompanySocialLink.telegram: text(CompanyFormField.telegram),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(adminCompanyInfoProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final enabled = !state.saving && !state.locked;
    final problems = state.showErrors
        ? state.problems
        : const <CompanyField, CompanyProblem>{};
    final showBanner =
        state.changedElsewhere &&
        notice != CompanySaveNotice.changedElsewhere &&
        !state.locked;

    void changed() => notifier.setDraft(_input());

    void save() {
      FocusManager.instance.primaryFocus?.unfocus();
      notifier.save();
    }

    Widget card(String title, List<_FieldSpec> fields) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        child: _CardFields(
          title: title,
          fields: fields,
          controllers: _controllers,
          problems: problems,
          enabled: enabled,
          onChanged: changed,
        ),
      ),
    );

    Widget noticeView(CompanySaveNotice notice) {
      final text = adminCompanySaveNoticeText(notice);
      switch (notice) {
        case CompanySaveNotice.noAnswer:
          return AdminCarMessage(
            icon: Icons.help_outline,
            text: text,
            buttons: [
              FilledButton(onPressed: save, child: const Text(adminSaveAgain)),
              OutlinedButton(
                onPressed: notifier.loadCurrent,
                child: const Text(adminLoadCurrentInfo),
              ),
            ],
          );
        case CompanySaveNotice.changedElsewhere:
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
                child: const Text(adminLoadCurrentInfo),
              ),
            ],
          );
        case CompanySaveNotice.saved:
        case CompanySaveNotice.noConnection:
        case CompanySaveNotice.refused:
        case CompanySaveNotice.unknown:
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
    const url = TextInputType.url;

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
                  adminSettingsCompanyTitle,
                  style: textTheme.headlineSmall,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: AdminNote(icon: Icons.public, text: adminCompanyNote),
              ),
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: AdminCarMessage(
                    icon: Icons.sync_problem,
                    text: adminCompanyChangedElsewhereBanner,
                    buttons: [
                      FilledButton(
                        onPressed: state.saving ? null : notifier.loadCurrent,
                        child: const Text(adminLoadCurrentInfo),
                      ),
                    ],
                  ),
                ),
              card(adminCompanyCardCompany, const [
                _FieldSpec(
                  CompanyFormField.name,
                  adminCompanyLabelName,
                  CompanyField.name,
                ),
              ]),
              card(adminCompanyCardContacts, const [
                _FieldSpec(
                  CompanyFormField.phone,
                  adminCompanyLabelPhone,
                  CompanyField.phone,
                  keyboard: TextInputType.phone,
                ),
                _FieldSpec(
                  CompanyFormField.email,
                  adminCompanyLabelEmail,
                  CompanyField.email,
                  keyboard: TextInputType.emailAddress,
                ),
              ]),
              card(adminCompanyCardAddress, const [
                _FieldSpec(
                  CompanyFormField.addressKa,
                  adminCompanyLabelKa,
                  CompanyField.address,
                  marksOnly: true,
                ),
                _FieldSpec(
                  CompanyFormField.addressRu,
                  adminCompanyLabelRu,
                  CompanyField.address,
                  marksOnly: true,
                ),
                _FieldSpec(
                  CompanyFormField.addressEn,
                  adminCompanyLabelEn,
                  CompanyField.address,
                ),
              ]),
              card(adminCompanyCardHours, const [
                _FieldSpec(
                  CompanyFormField.hoursKa,
                  adminCompanyLabelKa,
                  CompanyField.workingHours,
                  marksOnly: true,
                  multiline: true,
                ),
                _FieldSpec(
                  CompanyFormField.hoursRu,
                  adminCompanyLabelRu,
                  CompanyField.workingHours,
                  marksOnly: true,
                  multiline: true,
                ),
                _FieldSpec(
                  CompanyFormField.hoursEn,
                  adminCompanyLabelEn,
                  CompanyField.workingHours,
                  multiline: true,
                ),
              ]),
              card(adminCompanyCardMap, const [
                _FieldSpec(
                  CompanyFormField.mapUrl,
                  adminCompanyLabelMap,
                  CompanyField.mapUrl,
                  keyboard: url,
                ),
              ]),
              card(adminCompanyCardSocial, const [
                _FieldSpec(
                  CompanyFormField.facebook,
                  adminCompanyLabelFacebook,
                  CompanyField.facebook,
                  keyboard: url,
                ),
                _FieldSpec(
                  CompanyFormField.instagram,
                  adminCompanyLabelInstagram,
                  CompanyField.instagram,
                  keyboard: url,
                ),
                _FieldSpec(
                  CompanyFormField.whatsapp,
                  adminCompanyLabelWhatsapp,
                  CompanyField.whatsapp,
                  keyboard: url,
                ),
                _FieldSpec(
                  CompanyFormField.telegram,
                  adminCompanyLabelTelegram,
                  CompanyField.telegram,
                  keyboard: url,
                ),
              ]),
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
                        child: const Text(adminCompanySave),
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

/// One text field of a card.
class _FieldSpec {
  const _FieldSpec(
    this.field,
    this.label,
    this.problemField, {
    this.keyboard,
    this.multiline = false,
    this.marksOnly = false,
  });

  final CompanyFormField field;
  final String label;

  /// The field of the checks whose problem belongs to this text field.
  final CompanyField problemField;
  final TextInputType? keyboard;
  final bool multiline;

  /// True for the Georgian and Russian fields of a translated text: they
  /// are marked red, and the text of the problem is shown only under the
  /// English field.
  final bool marksOnly;
}

/// The title and the fields of one card. Built inside the white card, so
/// Theme.of(context) is the dark-on-white one.
class _CardFields extends StatelessWidget {
  const _CardFields({
    required this.title,
    required this.fields,
    required this.controllers,
    required this.problems,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final List<_FieldSpec> fields;
  final Map<CompanyFormField, TextEditingController> controllers;
  final Map<CompanyField, CompanyProblem> problems;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: textTheme.titleMedium),
        for (final spec in fields) ...[
          const SizedBox(height: 12),
          TextField(
            key: adminCompanyFieldKey(spec.field),
            controller: controllers[spec.field],
            enabled: enabled,
            keyboardType: spec.multiline
                ? TextInputType.multiline
                : spec.keyboard,
            minLines: spec.multiline ? 2 : 1,
            maxLines: spec.multiline ? 6 : 1,
            autocorrect: false,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: spec.label,
              errorText: switch (problems[spec.problemField]) {
                null => null,
                // Marked red; the text is under the English field.
                _ when spec.marksOnly => '',
                final problem => adminCompanyProblemText(
                  spec.problemField,
                  problem,
                ),
              },
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
