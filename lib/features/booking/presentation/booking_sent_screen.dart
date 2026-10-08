import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// Shown after a booking request was sent: the thank-you sentence and the
/// way back to the cars. Step 2.8 adds the summary of the request.
///
/// The sent booking is kept in memory only. It is forgotten when the user
/// leaves this screen, because it contains personal data. Opened without a
/// sent booking (a page reload or a direct link), the screen goes to the
/// catalog.
class BookingSentScreen extends ConsumerStatefulWidget {
  const BookingSentScreen({super.key});

  @override
  ConsumerState<BookingSentScreen> createState() => _BookingSentScreenState();
}

class _BookingSentScreenState extends ConsumerState<BookingSentScreen> {
  late final SentBookingNotifier _sentBooking;
  late final bool _hasBooking;

  @override
  void initState() {
    super.initState();
    _sentBooking = ref.read(sentBookingProvider.notifier);
    _hasBooking = ref.read(sentBookingProvider) != null;
    if (!_hasBooking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.home);
      });
    }
  }

  @override
  void dispose() {
    // After this frame: providers must not change while widgets are removed.
    unawaited(Future.microtask(_sentBooking.clear));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        title: const AppBarLogo(),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: _hasBooking
            ? CatalogMessage(
                icon: Icons.check_circle_outline,
                text: l10n.bookingSentThanks,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(l10n.backToCars),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
