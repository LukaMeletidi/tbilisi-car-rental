import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_date_format.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_rental.dart';

/// One booking in the admin list: a white card with the status, the
/// customer, the car, the dates in Tbilisi time, the days and the total.
/// It cannot be tapped yet; the detail screen comes in step 3.8.
class AdminBookingCard extends StatelessWidget {
  const AdminBookingCard({super.key, required this.booking, required this.car});

  final Booking booking;
  final AdminCarLabel car;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: _CardContent(booking: booking, car: car),
    );
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _CardContent extends StatelessWidget {
  const _CardContent({required this.booking, required this.car});

  final Booking booking;
  final AdminCarLabel car;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final createdAt = booking.createdAt;
    final daysAndTotal = [
      adminDays(booking.rentalDays),
      adminAmount(booking.totalPrice),
      // More than 7 days: the total is only an estimate.
      if (booking.isIndividualPrice) adminEstimate,
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap: on a narrow phone the chip moves under a long name.
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(booking.customer.fullName, style: textTheme.titleMedium),
            AdminStatusChip(status: booking.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(booking.customer.phone),
        const SizedBox(height: 8),
        Text(adminCarText(car), style: textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          '${formatAdminUtc(booking.pickup)} → '
          '${formatAdminUtc(booking.dropoff)}',
        ),
        const SizedBox(height: 4),
        Text(daysAndTotal),
        if (createdAt != null) ...[
          const SizedBox(height: 8),
          Text(
            adminReceived(formatAdminUtc(createdAt)),
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// The background of a status chip. The chip always shows the status as a
/// word as well.
Color adminStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.newBooking:
      return const Color(0xFF616161); // neutral grey
    case BookingStatus.pending:
      return const Color(0xFF8A5A00); // amber, dark enough for white text
    case BookingStatus.confirmed:
      return const Color(0xFF2E7D32); // green
    case BookingStatus.cancelled:
      return const Color(0xFFC62828); // red
  }
}

/// The status of a booking as a small coloured label with its name.
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: adminStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          adminStatusLabel(status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
