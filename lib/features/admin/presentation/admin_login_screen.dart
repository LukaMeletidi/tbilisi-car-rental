import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_sign_in_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The widest the sign-in card gets.
const adminLoginMaxWidth = 420.0;

/// The sign-in page of the admin area. Nothing in the public app links to
/// it. After a successful sign-in the router moves on by itself, because
/// the session changes.
class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        // Always to the catalog: a typed web address has no page to go
        // back to.
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: const AppBarLogo(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: adminLoginMaxWidth),
              child: const AppCard(child: _LoginForm()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fields and the button. Built inside the white card, so
/// Theme.of(context) is the dark-on-white one.
///
/// The password exists only in its text field. It is handed to the sign-in
/// call and cleared afterwards; it is never put into a provider or a log.
class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  var _passwordHidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final signedIn = await ref
        .read(adminSignInProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!mounted) return;

    final failure = ref.read(adminSignInProvider).failure;
    if (signedIn) {
      _password.clear();
      // Lets a password manager offer to save what was typed.
      TextInput.finishAutofillContext();
    } else if (failure != null && failure != AdminSignInFailure.missingInput) {
      // A request was sent and refused: the password must be typed again.
      // The e-mail stays.
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(adminSignInProvider);
    final working = state.isWorking;
    final failure = state.failure;

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(adminSignInTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            enabled: !working,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            decoration: const InputDecoration(labelText: adminEmailLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !working,
            obscureText: _passwordHidden,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            // Done on the keyboard, or Enter on web, sends the form.
            onSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: adminPasswordLabel,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordHidden ? Icons.visibility : Icons.visibility_off,
                ),
                tooltip: _passwordHidden
                    ? adminShowPassword
                    : adminHidePassword,
                onPressed: () =>
                    setState(() => _passwordHidden = !_passwordHidden),
              ),
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(child: Text(adminSignInFailureText(failure))),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            // Disabled while a request runs; the notifier refuses a second
            // call as well.
            onPressed: working ? null : _signIn,
            child: working
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: Text(adminSigningIn)),
                    ],
                  )
                : const Text(adminSignInButton),
          ),
        ],
      ),
    );
  }
}
