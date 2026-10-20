import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_tab_app_bar.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The content of the page is never wider than this (as Home, FAQ and
/// Contact).
const notFoundMaxWidth = 720.0;

/// The public page for an address that does not exist (step 7.2), built by
/// the router's last top-level route (and by its errorBuilder for a router
/// error). It lies outside the public shell, so there is no bottom bar; "Go
/// to Home" and the logo lead back. It never shows the address that was
/// typed.
///
/// Android's system Back goes to Home, as on the other tabs. On the web the
/// browser's Back follows its history and is never intercepted.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // White on the purple page.
    final onPage = theme.colorScheme.onSurface;
    void goHome() => context.go(AppRoutes.home);

    return PopScope(
      canPop: kIsWeb,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        appBar: const PublicTabAppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: notFoundMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: onPage),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.notFoundTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: onPage,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.notFoundText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: onPage),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: goHome,
                      child: Text(l10n.notFoundGoHome),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
