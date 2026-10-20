import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/section_title.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_info_card.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_page_view.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_photo_backdrop.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The benefits: the title on the purple page and three white cards with a
/// purple title, swiped sideways.
class HomeBenefitsSection extends StatelessWidget {
  const HomeBenefitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CardsOnPurple(
      name: 'benefits',
      title: l10n.homeBenefitsTitle,
      cards: [
        (l10n.homeBenefit1Title, l10n.homeBenefit1Text),
        (l10n.homeBenefit2Title, l10n.homeBenefit2Text),
        (l10n.homeBenefit3Title, l10n.homeBenefit3Text),
      ],
    );
  }
}

/// The conditions, built as the benefits.
class HomeConditionsSection extends StatelessWidget {
  const HomeConditionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CardsOnPurple(
      name: 'conditions',
      title: l10n.homeTermsTitle,
      cards: [
        (l10n.homeTerms1Title, l10n.homeTerms1Text),
        (l10n.homeTerms2Title, l10n.homeTerms2Text),
        (l10n.homeTerms3Title, l10n.homeTerms3Text),
      ],
    );
  }
}

class _CardsOnPurple extends StatelessWidget {
  const _CardsOnPurple({
    required this.name,
    required this.title,
    required this.cards,
  });

  final String name;
  final String title;
  final List<(String, String)> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        HomePageView(
          name: name,
          pages: [
            for (final (title, text) in cards)
              HomeInfoCard(title: title, text: text),
          ],
        ),
      ],
    );
  }
}

/// The traffic rules: one photo that never changes, the title at its top on
/// a dark band, and three white cards with a dark title swiped over it.
class HomeTrafficSection extends StatelessWidget {
  const HomeTrafficSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cards = [
      (l10n.homeTraffic1Title, l10n.homeTraffic1Text),
      (l10n.homeTraffic2Title, l10n.homeTraffic2Text),
      (l10n.homeTraffic3Title, l10n.homeTraffic3Text),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: HomePhotoBackdrop(
        image: homeTrafficImage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeScrimBand(
              fadeAbove: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.homeTrafficTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            HomePageView(
              name: 'traffic',
              pagePadding: const EdgeInsets.symmetric(horizontal: 32),
              pages: [
                for (final (title, text) in cards)
                  HomeInfoCard(title: title, text: text, purpleTitle: false),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
