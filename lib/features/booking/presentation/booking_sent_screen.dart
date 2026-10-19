import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/sent_booking_provider.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/sent_booking_summary.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// Shown after a booking request was sent: the thank-you sentence, the
/// summary of the request, and the way back to the cars.
///
/// The sent booking is kept in memory only. This screen takes its own copy
/// when it opens and forgets the shared one when the user leaves, because it
/// contains personal data. Opened without a sent booking (a page reload or a
/// direct link), the screen goes to the catalog.
class BookingSentScreen extends ConsumerStatefulWidget {
  const BookingSentScreen({super.key});

  @override
  ConsumerState<BookingSentScreen> createState() => _BookingSentScreenState();
}

class _BookingSentScreenState extends ConsumerState<BookingSentScreen> {
  late final SentBookingNotifier _sentBooking;

  /// The copy this screen shows; it stays while the screen closes.
  late final SentBooking? _sent;

  @override
  void initState() {
    super.initState();
    _sentBooking = ref.read(sentBookingProvider.notifier);
    _sent = ref.read(sentBookingProvider);
    if (_sent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.cars);
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
    final sent = _sent;

    // Android's system Back leads to the catalog, never back into the
    // form (Phase 6b). On the web the browser's Back follows its history.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.cars);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          title: const AppBarLogo(),
          actions: const [LanguageMenuButton()],
        ),
        body: SafeArea(
          child: sent == null
              ? const SizedBox.shrink()
              : _SentBookingBody(sent: sent),
        ),
      ),
    );
  }
}

class _SentBookingBody extends StatelessWidget {
  const _SentBookingBody({required this.sent});

  final SentBooking sent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.bookingSentThanks,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SentBookingSummary(sent: sent),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go(AppRoutes.cars),
                child: Text(l10n.backToCars),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
