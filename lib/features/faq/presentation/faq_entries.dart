import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// One question of the FAQ page and its answer.
typedef FaqEntry = ({String question, String answer});

/// The questions of the FAQ page in their order, in the current language.
List<FaqEntry> faqEntries(AppLocalizations l10n) => [
  (question: l10n.faq1Question, answer: l10n.faq1Answer),
  (question: l10n.faq2Question, answer: l10n.faq2Answer),
  (question: l10n.faq3Question, answer: l10n.faq3Answer),
  (question: l10n.faq4Question, answer: l10n.faq4Answer),
  (question: l10n.faq5Question, answer: l10n.faq5Answer),
  (question: l10n.faq6Question, answer: l10n.faq6Answer),
  (question: l10n.faq7Question, answer: l10n.faq7Answer),
  (question: l10n.faq8Question, answer: l10n.faq8Answer),
  (question: l10n.faq9Question, answer: l10n.faq9Answer),
  (question: l10n.faq10Question, answer: l10n.faq10Answer),
];
