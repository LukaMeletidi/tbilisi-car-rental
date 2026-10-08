import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_date_defaults.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_fields.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_price_preview.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_state.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/contact_fields.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/date_time_field.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/extras_list.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/location_field.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/notes_field.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/price_summary.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/submit_area.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The booking form of one car, shown when the car, the extras prices and
/// the places are loaded.
///
/// The values live in [bookingFormProvider]; this widget owns only the text
/// controllers, the focus nodes and the keys used to scroll to a field. The
/// controllers start from the saved draft, so a draft comes back in the
/// fields when the user returns to the form.
class BookingForm extends ConsumerStatefulWidget {
  const BookingForm({
    super.key,
    required this.car,
    required this.extrasPrices,
    required this.locations,
  });

  final Car car;
  final ExtrasPrices extrasPrices;
  final List<PickupLocation> locations;

  @override
  ConsumerState<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<BookingForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _pickupOther;
  late final TextEditingController _dropoffOther;

  /// The text fields mark their field as touched when they lose the focus.
  /// For a place this is the text field of "Other place": a choice in the
  /// dropdown is never wrong, so it does not need to show an error early.
  late final Map<BookingFormField, FocusNode> _focusNodes = {
    for (final field in const [
      BookingFormField.fullName,
      BookingFormField.phone,
      BookingFormField.email,
      BookingFormField.pickupLocation,
      BookingFormField.dropoffLocation,
      BookingFormField.notes,
    ])
      field: _touchOnBlur(field),
  };

  /// One key per field, to scroll to the first field with an error.
  final Map<BookingFormField, GlobalKey> _fieldKeys = {
    for (final field in BookingFormField.values) field: GlobalKey(),
  };

  NotifierProvider<BookingFormNotifier, BookingFormState> get _provider =>
      bookingFormProvider(widget.car.id);

  BookingFormNotifier get _notifier => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    final input = ref.read(_provider).input;
    _name = TextEditingController(text: input.fullName);
    _phone = TextEditingController(text: input.phone);
    _email = TextEditingController(text: input.email);
    _notes = TextEditingController(text: input.notes);
    _pickupOther = TextEditingController(text: input.pickupLocation?.text);
    _dropoffOther = TextEditingController(text: input.dropoffLocation?.text);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _notes,
      _pickupOther,
      _dropoffOther,
    ]) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _touchOnBlur(BookingFormField field) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted) _notifier.markTouched(field);
    });
    return node;
  }

  /// Shows a text of the draft that was changed from outside the field: the
  /// draft is emptied after a successful sending. While the user types, the
  /// draft and the field already hold the same text, so nothing is set and
  /// the cursor stays where it is.
  void _showDraft(BookingFormInput input) {
    void show(TextEditingController controller, String text) {
      if (controller.text != text) controller.text = text;
    }

    show(_name, input.fullName);
    show(_phone, input.phone);
    show(_email, input.email);
    show(_notes, input.notes);
    // The text of "Other place" is kept while a fixed place is chosen.
    if (input.pickupLocation == null) show(_pickupOther, '');
    if (input.dropoffLocation == null) show(_dropoffOther, '');
  }

  Future<void> _pickPickup() async {
    final now = ref.read(clockProvider)();
    final picked = await pickTbilisiDateTime(
      context,
      today: tbilisiToday(now),
      firstDay: earliestPickupDay(now),
      lastDay: latestPickupDay(now),
      start: ref.read(_provider).input.pickup ?? defaultPickup(now),
    );
    if (picked == null || !mounted) return;
    _notifier
      ..setPickup(picked)
      ..markTouched(BookingFormField.pickup);
  }

  Future<void> _pickDropoff() async {
    final now = ref.read(clockProvider)();
    final input = ref.read(_provider).input;
    final TbilisiDateTime? pickup = input.pickup;
    final picked = await pickTbilisiDateTime(
      context,
      today: tbilisiToday(now),
      firstDay: earliestDropoffDay(now, pickup: pickup),
      lastDay: latestDropoffDay(now, pickup: pickup),
      start: input.dropoff ?? defaultDropoff(now, pickup: pickup),
    );
    if (picked == null || !mounted) return;
    _notifier
      ..setDropoff(picked)
      ..markTouched(BookingFormField.dropoff);
  }

  /// A place chosen in a dropdown: a fixed place, or "Other place" with the
  /// text typed so far.
  BookingLocation _location(String id, TextEditingController other) {
    return id == otherLocationId
        ? BookingLocation.other(other.text)
        : BookingLocation.fixed(id);
  }

  Future<void> _send() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final errors = _notifier.validate(
      car: widget.car,
      locations: widget.locations,
    );
    // Taken now: after the request this widget may be gone.
    final sentBooking = ref.read(sentBookingProvider.notifier);

    final sent = await _notifier.submit(
      car: widget.car,
      extrasPrices: widget.extrasPrices,
      locations: widget.locations,
      language: ref.read(appLanguageProvider),
    );

    if (!mounted) {
      // The user has left the form (possible with the browser's Back
      // button). No thank-you screen will be shown, so the sent booking,
      // which contains personal data, is forgotten at once.
      if (sent) sentBooking.clear();
      return;
    }
    if (sent) {
      context.go(AppRoutes.bookingSent);
      return;
    }
    final field = firstFieldWithError(errors);
    if (field != null) _scrollTo(field);
  }

  /// Scrolls to [field] once its error is on the screen, and puts the cursor
  /// into it when it is a text field.
  void _scrollTo(BookingFormField field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _fieldKeys[field]!.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.1,
        duration: const Duration(milliseconds: 300),
      );
      if (field == BookingFormField.fullName ||
          field == BookingFormField.phone ||
          field == BookingFormField.email ||
          field == BookingFormField.notes) {
        _focusNodes[field]!.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_provider);
    final language = ref.watch(appLanguageProvider);
    final input = state.input;
    final enabled = !state.isSending;

    ref.listen(_provider, (previous, next) => _showDraft(next.input));

    final errors = _notifier.validate(
      car: widget.car,
      locations: widget.locations,
    );
    final visible = visibleErrors(
      errors,
      touched: state.touched,
      submitAttempted: state.submitAttempted,
    );
    String? errorOf(BookingFormField field) {
      final error = visible[field];
      return error == null ? null : bookingErrorText(l10n, error);
    }

    final failure = state.failure;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  l10n.bookingTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              AppCard(child: _CarHeader(car: widget.car)),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionContact,
                child: ContactFields(
                  enabled: enabled,
                  nameKey: _fieldKeys[BookingFormField.fullName]!,
                  nameController: _name,
                  nameFocusNode: _focusNodes[BookingFormField.fullName]!,
                  nameError: errorOf(BookingFormField.fullName),
                  onNameChanged: _notifier.setFullName,
                  phoneKey: _fieldKeys[BookingFormField.phone]!,
                  phoneController: _phone,
                  phoneFocusNode: _focusNodes[BookingFormField.phone]!,
                  phoneError: errorOf(BookingFormField.phone),
                  onPhoneChanged: _notifier.setPhone,
                  whatsapp: input.whatsapp,
                  onWhatsappChanged: _notifier.setWhatsapp,
                  telegram: input.telegram,
                  onTelegramChanged: _notifier.setTelegram,
                  emailKey: _fieldKeys[BookingFormField.email]!,
                  emailController: _email,
                  emailFocusNode: _focusNodes[BookingFormField.email]!,
                  emailError: errorOf(BookingFormField.email),
                  onEmailChanged: _notifier.setEmail,
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionDates,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DateTimeField(
                      key: _fieldKeys[BookingFormField.pickup],
                      label: l10n.bookingPickupDateTime,
                      value: input.pickup,
                      errorText: errorOf(BookingFormField.pickup),
                      enabled: enabled,
                      onTap: _pickPickup,
                    ),
                    const SizedBox(height: 16),
                    DateTimeField(
                      key: _fieldKeys[BookingFormField.dropoff],
                      label: l10n.bookingDropoffDateTime,
                      value: input.dropoff,
                      errorText: errorOf(BookingFormField.dropoff),
                      enabled: enabled,
                      onTap: _pickDropoff,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionLocations,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocationField(
                      key: _fieldKeys[BookingFormField.pickupLocation],
                      label: l10n.bookingPickupLocation,
                      locations: widget.locations,
                      language: language,
                      value: input.pickupLocation,
                      otherController: _pickupOther,
                      otherFocusNode:
                          _focusNodes[BookingFormField.pickupLocation]!,
                      errorText: errorOf(BookingFormField.pickupLocation),
                      enabled: enabled,
                      onChanged: (id) => _notifier.setPickupLocation(
                        _location(id, _pickupOther),
                      ),
                      onOtherTextChanged: (text) => _notifier.setPickupLocation(
                        BookingLocation.other(text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LocationField(
                      key: _fieldKeys[BookingFormField.dropoffLocation],
                      label: l10n.bookingDropoffLocation,
                      locations: widget.locations,
                      language: language,
                      value: input.dropoffLocation,
                      otherController: _dropoffOther,
                      otherFocusNode:
                          _focusNodes[BookingFormField.dropoffLocation]!,
                      errorText: errorOf(BookingFormField.dropoffLocation),
                      enabled: enabled,
                      onChanged: (id) => _notifier.setDropoffLocation(
                        _location(id, _dropoffOther),
                      ),
                      onOtherTextChanged: (text) => _notifier
                          .setDropoffLocation(BookingLocation.other(text)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionExtras,
                child: ExtrasList(
                  prices: widget.extrasPrices,
                  selected: input.extras,
                  enabled: enabled,
                  onChanged: (extra, selected) =>
                      _notifier.setExtra(extra, selected: selected),
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionNotes,
                child: NotesField(
                  key: _fieldKeys[BookingFormField.notes],
                  controller: _notes,
                  focusNode: _focusNodes[BookingFormField.notes]!,
                  length: input.notes.trim().length,
                  errorText: errorOf(BookingFormField.notes),
                  enabled: enabled,
                  onChanged: _notifier.setNotes,
                ),
              ),
              const SizedBox(height: 4),
              BookingSection(
                title: l10n.bookingSectionPrice,
                child: PriceSummary(
                  price: previewRentalPrice(
                    input: input,
                    car: widget.car,
                    extrasPrices: widget.extrasPrices,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SubmitArea(
                showCheckFields: state.submitAttempted && errors.isNotEmpty,
                failureText: failure == null
                    ? null
                    : bookingFailureText(l10n, failure),
                sending: state.isSending,
                onSend: _send,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// The car the request is for: its title and its price per day. Built inside
/// the white card, so Theme.of(context) is the dark-on-white one.
class _CarHeader extends StatelessWidget {
  const _CarHeader({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(carTitle(car), style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.pricePerDay(formatPrice(car.pricePerDay)),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
