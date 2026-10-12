import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/date_time_field.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';

/// The keys of the cards of [AdminBookingFieldCards], so that a form can
/// scroll to the first card with an error.
class AdminFieldCardKeys {
  final customer = GlobalKey();
  final car = GlobalKey();
  final dates = GlobalKey();
  final notes = GlobalKey();

  /// The card that shows [error]; null for an error of the total, which
  /// has its own card in each form.
  GlobalKey? cardOf(AdminBookingError error) {
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
        return customer;
      case AdminBookingError.carRequired:
      case AdminBookingError.carMissing:
        return car;
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
        return dates;
      case AdminBookingError.notesTooLong:
        return notes;
      case AdminBookingError.totalChoiceRequired:
      case AdminBookingError.newTotalUnavailable:
      case AdminBookingError.totalTooHigh:
        return null;
    }
  }
}

/// The cards with the fields a booking has in the admin forms: customer,
/// car, dates and places, extras, notes. The edit form and the "new
/// booking" form both show them.
///
/// The draft of the form is the single source of truth. This widget only
/// shows [draft] and reports what the admin does through [onChanged]. The
/// text controllers are made from the draft once, when this widget is
/// created. A form that replaces its fields itself builds this widget anew
/// (with a new key): the old controllers are disposed and new ones are
/// made from the new draft.
class AdminBookingFieldCards extends ConsumerStatefulWidget {
  const AdminBookingFieldCards({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.enabled,
    required this.cars,
    required this.locations,
    required this.extrasPrices,
    required this.errorText,
    required this.keys,
    this.storedPickupLocation,
    this.storedDropoffLocation,
    this.emailEnabled = true,
    this.belowEmail,
    this.belowCar,
    this.carsNotLoadedText = adminCarsNotLoaded,
  });

  /// The fields as the admin entered them.
  final AdminBookingDraft draft;

  /// Reports a change. The form applies [change] to its newest draft, so
  /// two changes in the same moment do not undo each other.
  final void Function(
    AdminBookingDraft Function(AdminBookingDraft draft) change,
  )
  onChanged;

  /// False while the form is locked (for example while a save runs).
  final bool enabled;

  /// Every car, also the hidden ones; null while not loaded.
  final List<Car>? cars;

  /// The fixed places from settings; null while not loaded.
  final List<PickupLocation>? locations;

  /// The current prices of the extras; null while not loaded.
  final ExtrasPrices? extrasPrices;

  /// The text to show for the first of the given errors the form has, or
  /// null. The form decides when an error is shown.
  final String? Function(List<AdminBookingError> candidates) errorText;

  /// The keys of the cards.
  final AdminFieldCardKeys keys;

  /// The places the stored booking has, when one is edited: a place that
  /// settings no longer has stays in the list. Null for a new booking.
  final BookingLocation? storedPickupLocation;
  final BookingLocation? storedDropoffLocation;

  /// False when the e-mail field is switched off ("the customer has no
  /// e-mail"): it keeps its text, is greyed out and shows no error.
  final bool emailEnabled;

  /// Shown under the e-mail field, when given.
  final Widget? belowEmail;

  /// Shown under the choice of the car, when given.
  final Widget? belowCar;

  /// Said under the choice of the car while there is no list of cars.
  final String carsNotLoadedText;

  @override
  ConsumerState<AdminBookingFieldCards> createState() =>
      _AdminBookingFieldCardsState();
}

class _AdminBookingFieldCardsState
    extends ConsumerState<AdminBookingFieldCards> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _pickupAddress;
  late final TextEditingController _dropoffAddress;

  @override
  void initState() {
    super.initState();
    final input = widget.draft.input;
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

  void _edit(BookingFormInput Function(BookingFormInput input) change) =>
      widget.onChanged((draft) => draft.copyWith(input: change(draft.input)));

  Future<void> _pickDate({required bool pickup}) async {
    final draft = widget.draft;
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

  /// The places a dropdown offers: the ones of settings, then the place
  /// the booking already has when settings no longer has it, then "Other
  /// place".
  List<({String id, String label})> _places(BookingLocation? stored) {
    final locations = widget.locations;
    return [
      for (final location in locations ?? const <PickupLocation>[])
        (id: location.id, label: location.name.forLanguage(AppLanguage.en)),
      if (stored != null &&
          !stored.isOther &&
          !(locations ?? const <PickupLocation>[]).any(
            (known) => known.id == stored.id,
          ))
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
    final draft = widget.draft;
    final input = draft.input;
    final cars = widget.cars;
    final enabled = widget.enabled;
    final errorText = widget.errorText;
    final keys = widget.keys;
    final belowEmail = widget.belowEmail;
    final belowCar = widget.belowCar;
    final now = ref.watch(clockProvider)();
    final notesLength = input.notes.trim().length;

    final carChoice = AdminDropdown<String>(
      label: adminLabelCar,
      // No car is chosen yet in a new form.
      value: draft.carId.isEmpty ? null : draft.carId,
      // Without the list of cars another car cannot be chosen.
      enabled: enabled && cars != null,
      errorText: errorText(const [
        AdminBookingError.carRequired,
        AdminBookingError.carMissing,
      ]),
      helperText: cars == null ? widget.carsNotLoadedText : null,
      items: [
        for (final car in cars ?? const <Car>[])
          (
            value: car.id,
            label: car.active ? carTitle(car) : adminCarHidden(carTitle(car)),
          ),
        // The car of the booking was deleted, or the cars are not loaded:
        // its ID is all that is known.
        if (draft.carId.isNotEmpty &&
            !(cars ?? const <Car>[]).any((car) => car.id == draft.carId))
          (
            value: draft.carId,
            label: cars == null ? draft.carId : adminCarNotFound(draft.carId),
          ),
      ],
      onChanged: (carId) => widget.onChanged((d) => d.copyWith(carId: carId)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingSection(
          key: keys.customer,
          title: adminSectionCustomer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                enabled: enabled,
                onChanged: (value) => _edit((i) => i.copyWith(fullName: value)),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                // A name is personal data: the keyboard must not learn it,
                // and no autofill service gets it.
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: null,
                decoration: InputDecoration(
                  labelText: adminLabelName,
                  errorText: errorText(const [
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
                onChanged: (value) => _edit((i) => i.copyWith(phone: value)),
                keyboardType: TextInputType.phone,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: null,
                decoration: InputDecoration(
                  labelText: adminLabelPhone,
                  errorText: errorText(const [
                    AdminBookingError.phoneRequired,
                    AdminBookingError.phoneInvalid,
                    AdminBookingError.phoneStoredFormat,
                  ]),
                ),
              ),
              CheckboxListTile(
                value: input.whatsapp,
                onChanged: enabled
                    ? (value) => _edit((i) => i.copyWith(whatsapp: value!))
                    : null,
                title: const Text(adminOnWhatsapp),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: input.telegram,
                onChanged: enabled
                    ? (value) => _edit((i) => i.copyWith(telegram: value!))
                    : null,
                title: const Text(adminOnTelegram),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _email,
                enabled: enabled && widget.emailEnabled,
                onChanged: (value) => _edit((i) => i.copyWith(email: value)),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: null,
                decoration: InputDecoration(
                  labelText: adminLabelEmail,
                  errorText: widget.emailEnabled
                      ? errorText(const [
                          AdminBookingError.emailRequired,
                          AdminBookingError.emailInvalid,
                          AdminBookingError.emailTooLong,
                          AdminBookingError.emailStoredFormat,
                        ])
                      : null,
                ),
              ),
              ?belowEmail,
              const SizedBox(height: 12),
              AdminDropdown<AppLanguage>(
                label: adminLabelLanguage,
                value: draft.language,
                enabled: enabled,
                items: [
                  for (final language in AppLanguage.values)
                    (value: language, label: adminLanguageLabel(language)),
                ],
                onChanged: (language) =>
                    widget.onChanged((d) => d.copyWith(language: language)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        BookingSection(
          key: keys.car,
          title: adminSectionCar,
          child: belowCar == null
              ? carChoice
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [carChoice, belowCar],
                ),
        ),
        const SizedBox(height: 4),
        BookingSection(
          key: keys.dates,
          title: adminSectionDates,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateField(
                label: adminLabelPickupTime,
                value: input.pickup,
                enabled: enabled,
                errorText: errorText(const [AdminBookingError.pickupRequired]),
                // Allowed for an admin; only said, never an error.
                note: isPickupInPast(draft, now: now)
                    ? adminPickupInPastNote
                    : null,
                onTap: () => _pickDate(pickup: true),
              ),
              const SizedBox(height: 12),
              _PlaceField(
                label: adminLabelPickupPlace,
                places: _places(widget.storedPickupLocation),
                value: input.pickupLocation,
                addressController: _pickupAddress,
                enabled: enabled,
                errorText: errorText(const [
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
                errorText: errorText(const [
                  AdminBookingError.dropoffRequired,
                  AdminBookingError.dropoffNotAfterPickup,
                  AdminBookingError.rentalTooLong,
                ]),
                onTap: () => _pickDate(pickup: false),
              ),
              const SizedBox(height: 12),
              _PlaceField(
                label: adminLabelDropoffPlace,
                places: _places(widget.storedDropoffLocation),
                value: input.dropoffLocation,
                addressController: _dropoffAddress,
                enabled: enabled,
                errorText: errorText(const [
                  AdminBookingError.dropoffLocationRequired,
                  AdminBookingError.dropoffLocationUnknown,
                  AdminBookingError.dropoffLocationTextRequired,
                  AdminBookingError.dropoffLocationTextTooLong,
                  AdminBookingError.dropoffLocationStoredFormat,
                ]),
                onChanged: (location) =>
                    _edit((i) => i.copyWith(dropoffLocation: location)),
              ),
              if (widget.locations == null) ...[
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
                      widget.extrasPrices?.priceOf(extra),
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
          key: keys.notes,
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
              errorText: errorText(const [AdminBookingError.notesTooLong]),
              counterText: showsNotesCounter(notesLength)
                  ? notesCounterText(notesLength)
                  : null,
            ),
          ),
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

/// A dropdown that looks like a text field of the form. With a null
/// [value] nothing is chosen yet.
class AdminDropdown<T extends Object> extends StatelessWidget {
  const AdminDropdown({
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
  final T? value;
  final List<({T value, String label})> items;
  final bool enabled;
  final ValueChanged<T> onChanged;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      isEmpty: value == null,
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
          onChanged: enabled ? (value) => onChanged(value!) : null,
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
