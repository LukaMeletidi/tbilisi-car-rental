import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/localization/app_language_provider.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_date_format.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_place_text.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_rental.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_texts.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/booking_section.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/price_summary.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The summary of a sent booking request, in two white cards: the request
/// (car, dates, places, extras, notes, days and total) and the customer's
/// contact details.
///
/// Every value is the one that was sent. The days come from the two dates
/// of the booking and the total is the stored one; nothing is calculated
/// again from the current prices. Only the names of the fixed places are
/// looked up in settings, in the current language; when they cannot be
/// found a neutral text is shown, so the summary never fails and no line is
/// empty.
class SentBookingSummary extends ConsumerWidget {
  const SentBookingSummary({super.key, required this.sent});

  final SentBooking sent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider);
    // Null while the places are loading or could not be loaded.
    final locations = ref.watch(pickupLocationsProvider).value;
    final booking = sent.booking;
    final customer = booking.customer;

    String place(BookingLocation location) =>
        bookingPlaceText(location, locations: locations, language: language) ??
        l10n.bookingSentUnknownPlace;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingSection(
          title: l10n.bookingSentSummaryTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryItem(
                label: l10n.bookingSentCar,
                lines: [carTitle(sent.car)],
              ),
              _DateAndPlace(
                label: l10n.bookingSentPickup,
                moment: booking.pickup,
                place: place(booking.pickupLocation),
              ),
              _DateAndPlace(
                label: l10n.bookingSentDropoff,
                moment: booking.dropoff,
                place: place(booking.dropoffLocation),
              ),
              _SummaryItem(
                label: l10n.bookingSectionExtras,
                lines: booking.extras.isEmpty
                    ? [l10n.bookingSentNoExtras]
                    : [
                        for (final extra in Extra.values)
                          if (booking.extras.contains(extra))
                            extraName(l10n, extra),
                      ],
              ),
              if (booking.notes.trim().isNotEmpty)
                _SummaryItem(
                  label: l10n.bookingSectionNotes,
                  lines: [booking.notes],
                ),
              const SizedBox(height: 4),
              PriceSummary(
                price: RentalPrice(
                  days: booking.rentalDays,
                  totalCents: booking.totalPriceCents,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        BookingSection(
          title: l10n.bookingSectionContact,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryItem(
                label: l10n.bookingFullName,
                lines: [customer.fullName],
              ),
              _SummaryItem(
                label: l10n.bookingPhone,
                lines: [
                  customer.phone,
                  if (customer.whatsapp) l10n.bookingSentWhatsapp,
                  if (customer.telegram) l10n.bookingSentTelegram,
                ],
              ),
              _SummaryItem(
                label: l10n.bookingEmail,
                lines: [customer.email],
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small label with one or more lines of text under it.
class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.lines,
    this.isLast = false,
  });

  final String label;
  final List<String> lines;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          for (final line in lines) Text(line, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// A pickup or a dropoff: the date and time in Tbilisi time, the line
/// "Tbilisi time (GMT+4)", and the place.
class _DateAndPlace extends StatelessWidget {
  const _DateAndPlace({
    required this.label,
    required this.moment,
    required this.place,
  });

  final String label;

  /// The stored UTC moment.
  final DateTime moment;

  final String place;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            formatTbilisiDateTime(TbilisiDateTime.fromUtc(moment)),
            style: textTheme.bodyLarge,
          ),
          Text(l10n.tbilisiTimeLabel, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(place, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
