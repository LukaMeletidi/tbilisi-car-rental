import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';

/// The app bar of the four tab pages of the public app: the logo (with the
/// hidden admin entry) and the language menu. No back arrow: a tab page is
/// a first page.
class PublicTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PublicTabAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(appBarLogoToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: appBarLogoToolbarHeight,
      automaticallyImplyLeading: false,
      title: const _LogoWithAdminEntry(),
      actions: const [LanguageMenuButton()],
    );
  }
}

/// The logo of the tab pages. A long press on it opens the admin sign-in
/// page: the only way into the admin area on a phone, where no address can
/// be typed.
///
/// It gives no hint to the public: no tooltip, no ripple, no hand cursor,
/// and nothing extra for screen readers, which still read only the app
/// name. A normal tap does nothing.
class _LogoWithAdminEntry extends StatelessWidget {
  const _LogoWithAdminEntry();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Flutter's standard long press: about half a second.
      onLongPress: () => context.go(AppRoutes.adminLogin),
      // Without this, a screen reader would announce a long-press action.
      excludeFromSemantics: true,
      child: const AppBarLogo(),
    );
  }
}
