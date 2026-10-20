import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_page_view.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_photo_backdrop.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_section_title.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The rental process: the title, then one photo that never changes with
/// the four steps swiped over it, white on the darkened photo.
class HomeProcessSection extends StatelessWidget {
  const HomeProcessSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (l10n.homeProcess1Title, l10n.homeProcess1Text),
      (l10n.homeProcess2Title, l10n.homeProcess2Text),
      (l10n.homeProcess3Title, l10n.homeProcess3Text),
      (l10n.homeProcess4Title, l10n.homeProcess4Text),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(l10n.homeProcessTitle),
        HomePhotoBackdrop(
          image: homeProcessImage,
          scrim: true,
          minHeight: 180,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: HomePageView(
              name: 'process',
              pages: [
                for (final (index, (title, text)) in steps.indexed)
                  _Step(number: index + 1, title: title, text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One step: the number in a purple circle, the title and the text.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: appBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(text, style: textTheme.bodyLarge?.copyWith(color: Colors.white)),
      ],
    );
  }
}
