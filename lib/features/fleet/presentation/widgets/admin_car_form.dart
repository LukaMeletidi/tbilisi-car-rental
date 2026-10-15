import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_field_cards.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_hide_car_dialog.dart';

/// The fields of the car form, the notices and the Save button.
///
/// The draft in the notifier is the single source of truth. The text
/// controllers are made from the draft once, when this widget is created,
/// and typing reports every change to the notifier. When the notifier
/// itself replaces the fields ("Load the current car", a change elsewhere
/// while the form has no changes), the screen builds this widget anew with
/// a key made from [AdminCarEditState.formVersion].
///
/// The photo rows keep one controller each; adding, removing and moving a
/// row changes the controllers in the same way as the draft, so a row
/// keeps its text and its cursor.
///
/// [state] must be in the "editing" status.
class AdminCarForm extends ConsumerStatefulWidget {
  const AdminCarForm({super.key, required this.carId, required this.state});

  final String carId;
  final AdminCarEditState state;

  @override
  ConsumerState<AdminCarForm> createState() => _AdminCarFormState();
}

class _AdminCarFormState extends ConsumerState<AdminCarForm> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _seats;
  late final TextEditingController _engineSize;
  late final TextEditingController _price;
  late final TextEditingController _descriptionKa;
  late final TextEditingController _descriptionRu;
  late final TextEditingController _descriptionEn;
  late final List<TextEditingController> _photos;

  AdminCarEditNotifier get _notifier =>
      ref.read(adminCarEditProvider(widget.carId).notifier);

  @override
  void initState() {
    super.initState();
    final draft = widget.state.draft!;
    _brand = TextEditingController(text: draft.brand);
    _model = TextEditingController(text: draft.model);
    _year = TextEditingController(text: draft.year);
    _seats = TextEditingController(text: draft.seats);
    _engineSize = TextEditingController(text: draft.engineSize);
    _price = TextEditingController(text: draft.pricePerDay);
    _descriptionKa = TextEditingController(text: draft.descriptionKa);
    _descriptionRu = TextEditingController(text: draft.descriptionRu);
    _descriptionEn = TextEditingController(text: draft.descriptionEn);
    _photos = [
      for (final photo in draft.photos) TextEditingController(text: photo),
    ];
  }

  @override
  void dispose() {
    for (final controller in [
      _brand,
      _model,
      _year,
      _seats,
      _engineSize,
      _price,
      _descriptionKa,
      _descriptionRu,
      _descriptionEn,
      ..._photos,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Changes the draft. The newest draft is read from the notifier, so two
  /// changes in the same moment do not undo each other.
  void _change(CarDraft Function(CarDraft draft) change) {
    final draft = ref.read(adminCarEditProvider(widget.carId)).draft;
    if (draft != null) _notifier.setDraft(change(draft));
  }

  void _addPhoto() {
    final draft = widget.state.draft!;
    if (draft.photos.length >= carMaxPhotos) return;
    setState(() => _photos.add(TextEditingController()));
    _change((d) => d.copyWith(photos: addPhotoRow(d.photos)));
  }

  void _removePhoto(int index) {
    final controller = _photos[index];
    setState(() => _photos.removeAt(index));
    // Disposed after this frame: the removed field may still be built.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    _change((d) => d.copyWith(photos: removePhotoAt(d.photos, index)));
  }

  void _movePhoto(int index, {required bool up}) {
    final other = up ? index - 1 : index + 1;
    if (other < 0 || other >= _photos.length) return;
    setState(() {
      final controller = _photos[index];
      _photos[index] = _photos[other];
      _photos[other] = controller;
    });
    _change((d) => d.copyWith(photos: movePhoto(d.photos, index, up: up)));
  }

  /// The text of the first of [candidates] the draft has, once errors are
  /// shown.
  String? _error(List<CarError> candidates) {
    final state = widget.state;
    if (!state.showErrors) return null;
    for (final error in candidates) {
      if (state.validation.errors.contains(error)) {
        return adminCarErrorText(error);
      }
    }
    return null;
  }

  /// Save, or "Save again" after "No answer". A save that hides the car
  /// asks first; "Save again" does not ask again.
  Future<void> _save({bool again = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current = ref.read(adminCarEditProvider(widget.carId));
    if (!again && current.asksHideConfirmation) {
      if (!await confirmHideCar(context)) return;
      if (!mounted) return;
    }
    await _notifier.save();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final draft = state.draft!;
    final enabled = !state.saving && !state.locked;
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final showBanner =
        state.changedElsewhere &&
        notice != CarSaveNotice.changedElsewhere &&
        !state.locked;

    TextField text(
      TextEditingController controller,
      String label,
      List<CarError> errors,
      CarDraft Function(CarDraft draft, String value) update, {
      TextInputType? keyboardType,
      bool multiline = false,
    }) {
      return TextField(
        controller: controller,
        enabled: enabled,
        onChanged: (value) => _change((d) => update(d, value)),
        keyboardType: multiline ? TextInputType.multiline : keyboardType,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          errorText: _error(errors),
          errorMaxLines: 3,
        ),
      );
    }

    const gap = SizedBox(height: 12);
    const decimal = TextInputType.numberWithOptions(decimal: true);

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
                child: Text(adminCarEditTitle, style: textTheme.headlineSmall),
              ),
              if (state.needsRepair)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: AdminNote(
                    icon: Icons.build_outlined,
                    text: adminCarRepairNote,
                  ),
                ),
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: _MessageWithButtons(
                    icon: Icons.sync_problem,
                    text: adminCarChangedElsewhereBanner,
                    buttons: [
                      FilledButton(
                        onPressed: state.saving ? null : _notifier.loadCurrent,
                        child: const Text(adminLoadCurrentCar),
                      ),
                    ],
                  ),
                ),
              BookingSection(
                title: adminCarSectionCar,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text(_brand, adminCarLabelBrand, const [
                      CarError.brandRequired,
                      CarError.brandTooLong,
                    ], (d, v) => d.copyWith(brand: v)),
                    gap,
                    text(_model, adminCarLabelModel, const [
                      CarError.modelRequired,
                      CarError.modelTooLong,
                    ], (d, v) => d.copyWith(model: v)),
                    gap,
                    text(
                      _year,
                      adminCarLabelYear,
                      const [
                        CarError.yearRequired,
                        CarError.yearNotWhole,
                        CarError.yearTooOld,
                        CarError.yearTooNew,
                      ],
                      (d, v) => d.copyWith(year: v),
                      keyboardType: TextInputType.number,
                    ),
                    gap,
                    AdminDropdown<Drivetrain>(
                      label: adminCarLabelDrivetrain,
                      value: draft.drivetrain,
                      enabled: enabled,
                      errorText: _error(const [CarError.drivetrainRequired]),
                      items: [
                        for (final value in Drivetrain.values)
                          (value: value, label: drivetrainLabel(value)),
                      ],
                      onChanged: (value) =>
                          _change((d) => d.copyWith(drivetrain: value)),
                    ),
                    gap,
                    AdminDropdown<Transmission>(
                      label: adminCarLabelTransmission,
                      value: draft.transmission,
                      enabled: enabled,
                      errorText: _error(const [CarError.transmissionRequired]),
                      items: [
                        for (final value in Transmission.values)
                          (value: value, label: adminTransmissionLabel(value)),
                      ],
                      onChanged: (value) =>
                          _change((d) => d.copyWith(transmission: value)),
                    ),
                    gap,
                    AdminDropdown<FuelType>(
                      label: adminCarLabelFuelType,
                      value: draft.fuelType,
                      enabled: enabled,
                      errorText: _error(const [CarError.fuelTypeRequired]),
                      items: [
                        for (final value in FuelType.values)
                          (value: value, label: adminFuelTypeLabel(value)),
                      ],
                      onChanged: (value) =>
                          _change((d) => d.copyWith(fuelType: value)),
                    ),
                    gap,
                    text(
                      _seats,
                      adminCarLabelSeats,
                      const [
                        CarError.seatsRequired,
                        CarError.seatsNotWhole,
                        CarError.seatsOutOfRange,
                      ],
                      (d, v) => d.copyWith(seats: v),
                      keyboardType: TextInputType.number,
                    ),
                    gap,
                    text(
                      _engineSize,
                      adminCarLabelEngineSize,
                      const [
                        CarError.engineSizeInvalid,
                        CarError.engineSizeOutOfRange,
                      ],
                      (d, v) => d.copyWith(engineSize: v),
                      keyboardType: decimal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: adminCarSectionPrice,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text(
                      _price,
                      adminCarLabelPrice,
                      const [
                        CarError.priceRequired,
                        CarError.priceInvalid,
                        CarError.priceOutOfRange,
                      ],
                      (d, v) => d.copyWith(pricePerDay: v),
                      keyboardType: decimal,
                    ),
                    const SizedBox(height: 8),
                    Text(adminCarPriceNote, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: adminCarSectionDescriptions,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text(
                      _descriptionKa,
                      adminCarLabelDescriptionKa,
                      const [
                        CarError.descriptionKaRequired,
                        CarError.descriptionKaTooLong,
                      ],
                      (d, v) => d.copyWith(descriptionKa: v),
                      multiline: true,
                    ),
                    gap,
                    text(
                      _descriptionRu,
                      adminCarLabelDescriptionRu,
                      const [
                        CarError.descriptionRuRequired,
                        CarError.descriptionRuTooLong,
                      ],
                      (d, v) => d.copyWith(descriptionRu: v),
                      multiline: true,
                    ),
                    gap,
                    text(
                      _descriptionEn,
                      adminCarLabelDescriptionEn,
                      const [
                        CarError.descriptionEnRequired,
                        CarError.descriptionEnTooLong,
                      ],
                      (d, v) => d.copyWith(descriptionEn: v),
                      multiline: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: adminCarSectionPhotos,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(adminCarPhotosNote, style: textTheme.bodySmall),
                    if (_error(const [CarError.tooManyPhotos])
                        case final error?) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    gap,
                    if (_photos.isEmpty) ...[const Text(adminCarNoPhotos), gap],
                    for (var i = 0; i < _photos.length; i++)
                      _PhotoRow(
                        key: ObjectKey(_photos[i]),
                        index: i,
                        count: _photos.length,
                        controller: _photos[i],
                        enabled: enabled,
                        errorText:
                            state.showErrors &&
                                state.validation.photoErrors[i] != null
                            ? adminCarPhotoErrorText(
                                state.validation.photoErrors[i]!,
                              )
                            : null,
                        onChanged: (value) => _change(
                          (d) => d.copyWith(
                            photos: setPhotoAt(d.photos, i, value),
                          ),
                        ),
                        onUp: () => _movePhoto(i, up: true),
                        onDown: () => _movePhoto(i, up: false),
                        onRemove: () => _removePhoto(i),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: enabled && draft.photos.length < carMaxPhotos
                            ? _addPhoto
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text(adminCarAddPhoto),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: adminCarSectionVisibility,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      value: draft.active,
                      onChanged: enabled
                          ? (value) => _change((d) => d.copyWith(active: value))
                          : null,
                      title: const Text(adminCarLabelVisible),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Text(adminHiddenCarNote, style: textTheme.bodySmall),
                  ],
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
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(adminSaving),
                        ],
                      ),
                      gap,
                    ],
                    if (notice != null && !state.saving) ...[
                      _notice(notice),
                      gap,
                    ],
                    if (state.showErrors &&
                        state.validation.hasErrors &&
                        !state.saving) ...[
                      const AdminNote(
                        icon: Icons.error_outline,
                        text: adminCorrectFields,
                      ),
                      gap,
                    ],
                    if (!state.locked)
                      FilledButton(
                        // Disabled while nothing changed (unless the car
                        // needs repair) and while a save runs.
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

  Widget _notice(CarSaveNotice notice) {
    final text = adminCarSaveNoticeText(notice);
    switch (notice) {
      case CarSaveNotice.noAnswer:
        return _MessageWithButtons(
          icon: Icons.help_outline,
          text: text,
          buttons: [
            FilledButton(
              onPressed: () => _save(again: true),
              child: const Text(adminSaveAgain),
            ),
            OutlinedButton(
              onPressed: _notifier.loadCurrent,
              child: const Text(adminLoadCurrentCar),
            ),
          ],
        );
      case CarSaveNotice.changedElsewhere:
        return _MessageWithButtons(
          icon: Icons.sync_problem,
          text: text,
          buttons: [
            OutlinedButton(
              onPressed: _notifier.dismissNotice,
              child: const Text(adminKeepEditing),
            ),
            FilledButton(
              onPressed: _notifier.loadCurrent,
              child: const Text(adminLoadCurrentCar),
            ),
          ],
        );
      case CarSaveNotice.saved:
      case CarSaveNotice.noConnection:
      case CarSaveNotice.refused:
      case CarSaveNotice.carMissing:
      case CarSaveNotice.unknown:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdminNote(icon: Icons.error_outline, text: text),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: adminDismissNotice,
              onPressed: _notifier.dismissNotice,
            ),
          ],
        );
    }
  }
}

/// One photo address with its buttons: up, down and remove.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    super.key,
    required this.index,
    required this.count,
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final int index;
  final int count;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: adminCarPhotoLabel(index),
              errorText: errorText,
              errorMaxLines: 3,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: adminCarMovePhotoUp,
                onPressed: enabled && index > 0 ? onUp : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: adminCarMovePhotoDown,
                onPressed: enabled && index < count - 1 ? onDown : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: adminCarRemovePhoto,
                onPressed: enabled ? onRemove : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A message on the purple page with its buttons.
class _MessageWithButtons extends StatelessWidget {
  const _MessageWithButtons({
    required this.icon,
    required this.text,
    required this.buttons,
  });

  final IconData icon;
  final String text;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminNote(icon: icon, text: text),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: buttons),
      ],
    );
  }
}
