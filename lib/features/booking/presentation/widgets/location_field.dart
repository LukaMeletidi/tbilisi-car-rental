import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// A pickup or dropoff place: a dropdown with the places from settings in
/// the current language, then "Other place". "Other place" shows a text
/// field for the address.
class LocationField extends StatelessWidget {
  const LocationField({
    super.key,
    required this.label,
    required this.locations,
    required this.language,
    required this.value,
    required this.otherController,
    required this.otherFocusNode,
    required this.errorText,
    required this.enabled,
    required this.onChanged,
    required this.onOtherTextChanged,
  });

  final String label;
  final List<PickupLocation> locations;
  final AppLanguage language;

  /// Null while nothing is chosen.
  final BookingLocation? value;

  /// The text of "Other place". It belongs to the form, so the text is kept
  /// when the user switches to a fixed place and back.
  final TextEditingController otherController;
  final FocusNode otherFocusNode;

  /// Shown under the text field when "Other place" is chosen, otherwise
  /// under the dropdown.
  final String? errorText;

  /// False while the request is being sent.
  final bool enabled;

  /// A place was chosen in the dropdown: the id of a fixed place, or
  /// [otherLocationId].
  final ValueChanged<String> onChanged;

  final ValueChanged<String> onOtherTextChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = this.value;
    final isOther = value != null && value.isOther;

    // A place that is no longer in settings cannot be shown as selected.
    final knownIds = {for (final location in locations) location.id};
    final selectedId = value == null
        ? null
        : isOther
        ? otherLocationId
        : knownIds.contains(value.id)
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
              onChanged: enabled ? (id) => onChanged(id!) : null,
              items: [
                for (final location in locations)
                  DropdownMenuItem(
                    value: location.id,
                    child: Text(
                      location.name.forLanguage(language),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                DropdownMenuItem(
                  value: otherLocationId,
                  child: Text(
                    l10n.bookingLocationOther,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOther) ...[
          const SizedBox(height: 12),
          TextField(
            controller: otherController,
            focusNode: otherFocusNode,
            enabled: enabled,
            onChanged: onOtherTextChanged,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.bookingLocationOtherText,
              errorText: errorText,
            ),
          ),
        ],
      ],
    );
  }
}
