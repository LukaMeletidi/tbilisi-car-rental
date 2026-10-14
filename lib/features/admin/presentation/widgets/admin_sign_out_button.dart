import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The Sign out button of the app bar of every admin section.
///
/// It first closes the listener of the bookings list, when that list is
/// alive (it may be, in the background, while another section is shown),
/// and only then signs out: nothing is listening when the sign-in token
/// goes away. A list that is not alive is not started for this.
class AdminSignOutButton extends ConsumerWidget {
  const AdminSignOutButton({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    final listWasAlive = ref.exists(adminBookingsProvider);
    if (listWasAlive) ref.read(adminBookingsProvider.notifier).stop();
    try {
      await ref.read(adminSignInProvider.notifier).signOut();
    } catch (_) {
      // Still signed in: bring the list back.
      if (listWasAlive) ref.invalidate(adminBookingsProvider);
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
