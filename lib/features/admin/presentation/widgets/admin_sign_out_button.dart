import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';

/// The Sign out button of the app bar of every admin section.
///
/// It first closes the listeners of the bookings list and of the fleet
/// list, each when it is alive (one may be, in the background, while the
/// other section is shown), and only then signs out: nothing is listening
/// when the sign-in token goes away. A list that is not alive is not
/// started for this.
class AdminSignOutButton extends ConsumerWidget {
  const AdminSignOutButton({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    final bookingsWereAlive = ref.exists(adminBookingsProvider);
    final carsWereAlive = ref.exists(adminCarsProvider);
    if (bookingsWereAlive) ref.read(adminBookingsProvider.notifier).stop();
    if (carsWereAlive) ref.read(adminCarsProvider.notifier).stop();
    try {
      await ref.read(adminSignInProvider.notifier).signOut();
    } catch (_) {
      // Still signed in: bring the lists back.
      if (bookingsWereAlive) ref.invalidate(adminBookingsProvider);
      if (carsWereAlive) ref.invalidate(adminCarsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: adminSignOutButton,
      onPressed: () => _signOut(ref),
    );
  }
}
