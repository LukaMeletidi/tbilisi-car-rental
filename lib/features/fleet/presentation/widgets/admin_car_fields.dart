import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_booking_field_cards.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';

/// Changes the draft of a car form. The form passes a function of the
/// draft; the owner applies it to the NEWEST draft it holds, so two changes
/// in the same moment do not undo each other.
typedef CarDraftChange = void Function(CarDraft Function(CarDraft draft));

/// The key of the "Popular" checkbox, for tests.
const adminCarPopularKey = ValueKey('admin-car-popular');

/// The fields of a car, shared by the edit form and the "new car" form:
/// the cards The car, Price, Descriptions, Photos and Visibility.
///
/// The draft of the owner is the single source of truth. The text
/// controllers are made from [draft] once, when this widget is created,
/// and typing reports every change through [onChanged]. When the owner
/// itself replaces the fields, it builds this widget anew with a new key.
///
/// The photo rows keep one controller each; adding, removing and moving a
/// row changes the controllers in the same way as the draft, so a row
/// keeps its text and its cursor.
class AdminCarFields extends StatefulWidget {
  const AdminCarFields({
    super.key,
    required this.draft,
    required this.validation,
    required this.showErrors,
    required this.enabled,
    required this.onChanged,
    required this.visibilityNote,
    this.otherVisiblePopular = 0,
  });

  final CarDraft draft;
  final CarValidation validation;

  /// True when the errors of [validation] are shown.
  final bool showErrors;

  /// False while a save runs or the fields are locked.
  final bool enabled;

  final CarDraftChange onChanged;

  /// The small text under the Visible switch.
  final String visibilityNote;

  /// How many OTHER visible cars are marked popular (otherVisiblePopularCount
  /// of the admin list; 0 when the list is not loaded). From 3 on, a ticked
  /// "Popular" shows a soft warning; it never blocks a save.
  final int otherVisiblePopular;

  @override
  State<AdminCarFields> createState() => _AdminCarFieldsState();
}

class _AdminCarFieldsState extends State<AdminCarFields> {
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

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
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

  void _change(CarDraft Function(CarDraft draft) change) =>
      widget.onChanged(change);

  void _addPhoto() {
    if (widget.draft.photos.length >= carMaxPhotos) return;
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
    if (!widget.showErrors) return null;
    for (final error in candidates) {
      if (widget.validation.errors.contains(error)) {
        return adminCarErrorText(error);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final enabled = widget.enabled;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              const _SmallNote(adminCarPriceNote),
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
              const _SmallNote(adminCarPhotosNote),
              if (_error(const [CarError.tooManyPhotos]) case final error?) ...[
                const SizedBox(height: 8),
                _SmallNote(error, isError: true),
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
                      widget.showErrors &&
                          widget.validation.photoErrors[i] != null
                      ? adminCarPhotoErrorText(
                          widget.validation.photoErrors[i]!,
                        )
                      : null,
                  onChanged: (value) => _change(
                    (d) => d.copyWith(photos: setPhotoAt(d.photos, i, value)),
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
              _SmallNote(widget.visibilityNote),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: adminCarPopularKey,
                value: draft.popular,
                onChanged: enabled
                    ? (value) =>
                          _change((d) => d.copyWith(popular: value ?? false))
                    : null,
                title: const Text(adminCarLabelPopular),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const _SmallNote(adminCarPopularNote),
              if (draft.popular &&
                  widget.otherVisiblePopular >= homePopularMax) ...[
                const SizedBox(height: 8),
                AdminNote(
                  icon: Icons.info_outline,
                  text: adminCarPopularTooMany(widget.otherVisiblePopular),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small note on a white card. Built inside the card, so its style comes
/// from the dark-on-white theme there (the step 6.5 contrast fix).
class _SmallNote extends StatelessWidget {
  const _SmallNote(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: isError ? theme.colorScheme.error : null,
      ),
    );
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

/// "Saving…" (or [text]) with a small spinner, while a write runs.
class AdminCarSaving extends StatelessWidget {
  const AdminCarSaving({super.key, this.text = adminSaving});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(text),
      ],
    );
  }
}

/// A message on the purple page with its buttons, used by both car forms.
class AdminCarMessage extends StatelessWidget {
  const AdminCarMessage({
    super.key,
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
