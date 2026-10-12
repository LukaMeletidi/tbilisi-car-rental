import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_price_card.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/date_time_field.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';

/// The fields of the edit form, the price card and the Save button.
///
/// The draft in the notifier is the single source of truth. This widget
/// only shows it and reports what the admin does. The text controllers are
/// made from the draft once, when this widget is created, and typing
/// reports every change to the notifier. When the notifier itself replaces
/// the fields ("Load the current booking", a change elsewhere while the
/// form has no changes), the screen builds this widget anew with a key
/// made from [AdminBookingEditState.formVersion]: the old controllers are
/// disposed and new ones are made from the new draft.
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
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _pickupAddress;
  late final TextEditingController _dropoffAddress;

  // One key per card, to scroll to the first card with an error.
  final _customerKey = GlobalKey();
  final _carKey = GlobalKey();
  final _datesKey = GlobalKey();
  final _notesKey = GlobalKey();
  final _totalKey = GlobalKey();

  // The parts for which the admin chose "Keep editing" on the banner.
  Set<AdminBookingField> _bannerHiddenFor = const {};

  AdminBookingEditNotifier get _notifier =>
      ref.read(adminBookingEditProvider(widget.bookingId).notifier);

  @override
  void initState() {
    super.initState();
    final input = widget.state.draft!.input;
    _name = TextEditingController(text: input.fullName);
    _phone = TextEditingController(text: input.phone);
    _email = TextEditingController(text: input.email);
    _notes = TextEditingController(text: input.notes);
    _pickupAddress = TextEditingController(
      text: input.pickupLocation?.text ?? '',
    );
    _dropoffAddress = TextEditingController(
      text: input.dropoffLocation?.text ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _pickupAddress.dispose();
    _dropoffAddress.dispose();
    super.dispose();
  }

  /// Changes the draft. The newest draft is read from the notifier, so two
  /// changes in the same moment do not undo each other.
  void _change(AdminBookingDraft Function(AdminBookingDraft draft) change) {
    final draft = ref.read(adminBookingEditProvider(widget.bookingId)).draft;
    if (draft != null) _notifier.setDraft(change(draft));
  }

  void _edit(BookingFormInput Function(BookingFormInput input) change) =>
      _change((draft) => draft.copyWith(input: change(draft.input)));

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

  Future<void> _pickDate({required bool pickup}) async {
    final draft = widget.state.draft!;
    final today = TbilisiDateTime.fromUtc(ref.read(clockProvider)());
    final range = adminPickerRange(today);
    final picked = await pickTbilisiDateTime(
      context,
      today: today,
      firstDay: range.first,
      lastDay: range.last,
      start: (pickup ? draft.input.pickup : draft.input.dropoff) ?? today,
    );
    // The form may have been replaced while the pickers were open.
    if (picked == null || !mounted) return;
    _edit(
      (input) => pickup
          ? input.copyWith(pickup: picked)
          : input.copyWith(dropoff: picked),
    );
  }

  void _toggleExtra(Extra extra, bool selected) {
    _edit((input) {
      final extras = {...input.extras};
      selected ? extras.add(extra) : extras.remove(extra);
      return input.copyWith(extras: extras);
    });
  }

  /// Save: stage 1 and 2 run in the notifier. After "Saved" the screen
  /// leaves by itself; here only the first card with an error is shown.
  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = adminBookingEditProvider(widget.bookingId);
    await ref.read(provider.notifier).save();
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
        key = _cardOf(error);
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

  GlobalKey _cardOf(AdminBookingError error) {
    switch (error) {
      case AdminBookingError.nameRequired:
      case AdminBookingError.nameTooShort:
      case AdminBookingError.nameTooLong:
      case AdminBookingError.phoneRequired:
      case AdminBookingError.phoneInvalid:
      case AdminBookingError.emailRequired:
      case AdminBookingError.emailInvalid:
      case AdminBookingError.emailTooLong:
      case AdminBookingError.nameStoredFormat:
      case AdminBookingError.phoneStoredFormat:
      case AdminBookingError.emailStoredFormat:
        return _customerKey;
      case AdminBookingError.carRequired:
      case AdminBookingError.carMissing:
        return _carKey;
      case AdminBookingError.pickupRequired:
      case AdminBookingError.dropoffRequired:
      case AdminBookingError.dropoffNotAfterPickup:
      case AdminBookingError.rentalTooLong:
      case AdminBookingError.pickupLocationRequired:
      case AdminBookingError.pickupLocationUnknown:
      case AdminBookingError.pickupLocationTextRequired:
      case AdminBookingError.pickupLocationTextTooLong:
      case AdminBookingError.dropoffLocationRequired:
      case AdminBookingError.dropoffLocationUnknown:
      case AdminBookingError.dropoffLocationTextRequired:
      case AdminBookingError.dropoffLocationTextTooLong:
      case AdminBookingError.pickupLocationStoredFormat:
      case AdminBookingError.dropoffLocationStoredFormat:
        return _datesKey;
      case AdminBookingError.notesTooLong:
        return _notesKey;
      case AdminBookingError.totalChoiceRequired:
      case AdminBookingError.newTotalUnavailable:
      case AdminBookingError.totalTooHigh:
        return _totalKey;
    }
  }

  /// The places a dropdown offers: the ones of settings, then the place
  /// the booking already has when settings no longer has it, then "Other
  /// place".
  List<({String id, String label})> _places(BookingLocation stored) {
    final locations = widget.state.locations;
    return [
      for (final location in locations ?? const [])
        (id: location.id, label: location.name.forLanguage(AppLanguage.en)),
      if (!stored.isOther &&
          !(locations ?? const []).any((known) => known.id == stored.id))
        (
          id: stored.id,
          // While the places are not loaded nothing can be said about it.
          label: locations == null ? stored.id : adminPlaceNotInList(stored.id),
        ),
      (id: otherLocationId, label: adminOtherPlace),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final base = state.base!;
    final draft = state.draft!;
    final input = draft.input;
    final totals = state.totals!;
    final cars = state.cars;
    final enabled = !state.saving;
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final now = ref.watch(clockProvider)();

    final changedElsewhere = [
      for (final field in AdminBookingField.values)
        if (state.changedElsewhere.contains(field)) field,
    ];
    final showBanner =
        changedElsewhere.isNotEmpty &&
        notice != AdminBookingSaveNotice.conflict &&
        !setEquals(changedElsewhere.toSet(), _bannerHiddenFor);

    final notesLength = input.notes.trim().length;

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
              BookingSection(
                key: _customerKey,
                title: adminSectionCustomer,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      enabled: enabled,
                      onChanged: (value) =>
                          _edit((i) => i.copyWith(fullName: value)),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      // A name is personal data: the keyboard must not
                      // learn it, and no autofill service gets it.
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: null,
                      decoration: InputDecoration(
                        labelText: adminLabelName,
                        errorText: _error(const [
                          AdminBookingError.nameRequired,
                          AdminBookingError.nameTooShort,
                          AdminBookingError.nameTooLong,
                          AdminBookingError.nameStoredFormat,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      enabled: enabled,
                      onChanged: (value) =>
                          _edit((i) => i.copyWith(phone: value)),
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: null,
                      decoration: InputDecoration(
                        labelText: adminLabelPhone,
                        errorText: _error(const [
                          AdminBookingError.phoneRequired,
                          AdminBookingError.phoneInvalid,
                          AdminBookingError.phoneStoredFormat,
                        ]),
                      ),
                    ),
                    CheckboxListTile(
                      value: input.whatsapp,
                      onChanged: enabled
                          ? (value) =>
                                _edit((i) => i.copyWith(whatsapp: value!))
                          : null,
                      title: const Text(adminOnWhatsapp),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: input.telegram,
                      onChanged: enabled
                          ? (value) =>
                                _edit((i) => i.copyWith(telegram: value!))
                          : null,
                      title: const Text(adminOnTelegram),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _email,
                      enabled: enabled,
                      onChanged: (value) =>
                          _edit((i) => i.copyWith(email: value)),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: null,
                      decoration: InputDecoration(
                        labelText: adminLabelEmail,
                        errorText: _error(const [
                          AdminBookingError.emailRequired,
                          AdminBookingError.emailInvalid,
                          AdminBookingError.emailTooLong,
                          AdminBookingError.emailStoredFormat,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Dropdown<AppLanguage>(
                      label: adminLabelLanguage,
                      value: draft.language,
                      enabled: enabled,
                      items: [
                        for (final language in AppLanguage.values)
                          (
                            value: language,
                            label: adminLanguageLabel(language),
                          ),
                      ],
                      onChanged: (language) =>
                          _change((d) => d.copyWith(language: language)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                key: _carKey,
                title: adminSectionCar,
                child: _Dropdown<String>(
                  label: adminLabelCar,
                  value: draft.carId,
                  // Without the list of cars another car cannot be chosen.
                  enabled: enabled && cars != null,
                  errorText: _error(const [
                    AdminBookingError.carRequired,
                    AdminBookingError.carMissing,
                  ]),
                  helperText: cars == null ? adminCarsNotLoaded : null,
                  items: [
                    for (final car in cars ?? const [])
                      (
                        value: car.id,
                        label: car.active
                            ? carTitle(car)
                            : adminCarHidden(carTitle(car)),
                      ),
                    // The car of the booking was deleted, or the cars are
                    // not loaded: its ID is all that is known.
                    if (!(cars ?? const []).any((car) => car.id == draft.carId))
                      (
                        value: draft.carId,
                        label: cars == null
                            ? draft.carId
                            : adminCarNotFound(draft.carId),
                      ),
                  ],
                  onChanged: (carId) =>
                      _change((d) => d.copyWith(carId: carId)),
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                key: _datesKey,
                title: adminSectionDates,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DateField(
                      label: adminLabelPickupTime,
                      value: input.pickup,
                      enabled: enabled,
                      errorText: _error(const [
                        AdminBookingError.pickupRequired,
                      ]),
                      // Allowed for an admin; only said, never an error.
                      note: isPickupInPast(draft, now: now)
                          ? adminPickupInPastNote
                          : null,
                      onTap: () => _pickDate(pickup: true),
                    ),
                    const SizedBox(height: 12),
                    _PlaceField(
                      label: adminLabelPickupPlace,
                      places: _places(base.pickupLocation),
                      value: input.pickupLocation,
                      addressController: _pickupAddress,
                      enabled: enabled,
                      errorText: _error(const [
                        AdminBookingError.pickupLocationRequired,
                        AdminBookingError.pickupLocationUnknown,
                        AdminBookingError.pickupLocationTextRequired,
                        AdminBookingError.pickupLocationTextTooLong,
                        AdminBookingError.pickupLocationStoredFormat,
                      ]),
                      onChanged: (location) =>
                          _edit((i) => i.copyWith(pickupLocation: location)),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: adminLabelDropoffTime,
                      value: input.dropoff,
                      enabled: enabled,
                      errorText: _error(const [
                        AdminBookingError.dropoffRequired,
                        AdminBookingError.dropoffNotAfterPickup,
                        AdminBookingError.rentalTooLong,
                      ]),
                      onTap: () => _pickDate(pickup: false),
                    ),
                    const SizedBox(height: 12),
                    _PlaceField(
                      label: adminLabelDropoffPlace,
                      places: _places(base.dropoffLocation),
                      value: input.dropoffLocation,
                      addressController: _dropoffAddress,
                      enabled: enabled,
                      errorText: _error(const [
                        AdminBookingError.dropoffLocationRequired,
                        AdminBookingError.dropoffLocationUnknown,
                        AdminBookingError.dropoffLocationTextRequired,
                        AdminBookingError.dropoffLocationTextTooLong,
                        AdminBookingError.dropoffLocationStoredFormat,
                      ]),
                      onChanged: (location) =>
                          _edit((i) => i.copyWith(dropoffLocation: location)),
                    ),
                    if (state.locations == null) ...[
                      const SizedBox(height: 8),
                      const _Small(adminPlacesNotLoaded),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: adminSectionExtras,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final extra in Extra.values)
                      CheckboxListTile(
                        value: input.extras.contains(extra),
                        onChanged: enabled
                            ? (value) => _toggleExtra(extra, value!)
                            : null,
                        title: Text(
                          adminExtraWithPrice(
                            extra,
                            state.extrasPrices?.priceOf(extra),
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                key: _notesKey,
                title: adminSectionNotes,
                child: TextField(
                  controller: _notes,
                  enabled: enabled,
                  onChanged: (value) => _edit((i) => i.copyWith(notes: value)),
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  // Notes can hold personal data too.
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: null,
                  decoration: InputDecoration(
                    errorText: _error(const [AdminBookingError.notesTooLong]),
                    counterText: showsNotesCounter(notesLength)
                        ? notesCounterText(notesLength)
                        : null,
                  ),
                ),
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

/// Small grey text inside a white card.
class _Small extends StatelessWidget {
  const _Small(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
}

/// A dropdown that looks like a text field of the form.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
    this.errorText,
    this.helperText,
  });

  final String label;
  final T value;
  final List<({T value, String label})> items;
  final bool enabled;
  final ValueChanged<T> onChanged;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 3,
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          onChanged: enabled ? (value) => onChanged(value as T) : null,
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item.value,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

/// A date and time in Tbilisi time. It cannot be typed in: a tap opens the
/// pickers. [note] is a remark under the field that is not an error.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onTap,
    this.note,
  });

  final String label;
  final TbilisiDateTime? value;
  final bool enabled;
  final String? errorText;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = this.value;
    final note = this.note;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: value == null,
              decoration: InputDecoration(
                labelText: label,
                errorText: errorText,
                enabled: enabled,
                suffixIcon: const Icon(Icons.event),
              ),
              child: Text(
                value == null ? '' : formatAdminDateTime(value),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(note, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// A place: one of [places], or "Other place" with an address.
class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.places,
    required this.value,
    required this.addressController,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final String label;
  final List<({String id, String label})> places;
  final BookingLocation? value;
  final TextEditingController addressController;
  final bool enabled;
  final String? errorText;
  final ValueChanged<BookingLocation> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final isOther = value != null && value.isOther;
    final selectedId = value != null && places.any((p) => p.id == value.id)
        ? value.id
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          isEmpty: selectedId == null,
          decoration: InputDecoration(
            labelText: label,
            errorText: isOther ? null : errorText,
            enabled: enabled,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              isDense: true,
              onChanged: enabled
                  ? (id) => onChanged(
                      id == otherLocationId
                          ? BookingLocation.other(addressController.text)
                          : BookingLocation.fixed(id!),
                    )
                  : null,
              items: [
                for (final place in places)
                  DropdownMenuItem(
                    value: place.id,
                    child: Text(place.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ),
        if (isOther) ...[
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            enabled: enabled,
            onChanged: (text) => onChanged(BookingLocation.other(text)),
            textCapitalization: TextCapitalization.sentences,
            // An address can be a home address.
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: null,
            decoration: InputDecoration(
              labelText: adminLabelAddress,
              errorText: errorText,
            ),
          ),
        ],
      ],
    );
  }
}
