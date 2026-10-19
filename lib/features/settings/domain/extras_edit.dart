/// The edit of the extras prices (step 6.6): the typed texts, whether they
/// would change what is stored, and what the screen says after a save.
/// Pure Dart; nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// The four typed prices, one text per extra.
typedef ExtrasDraft = Map<Extra, String>;

/// The form filled from the stored [prices]: "5", "4.5". A stored price
/// with more than two decimals or above the limit is shown as it is, so
/// that its problem is reported instead of the price changing silently.
ExtrasDraft extrasDraftOf(ExtrasPrices prices) => Map.unmodifiable({
  for (final extra in Extra.values)
    extra: extraPriceText(prices.priceOf(extra)),
});

/// The problem of each typed price that has one; empty when all four can be
/// saved.
Map<Extra, ExtraPriceProblem> extrasDraftProblems(ExtrasDraft draft) => {
  for (final extra in Extra.values)
    extra: ?extraPriceProblem(draft[extra] ?? ''),
};

/// Whether [draft] would change the stored [base]. When all four prices
/// are valid the VALUES are compared, so "5.00" or "5,0" for a stored 5 is
/// no change. Otherwise the texts are compared with the form as it opened.
bool extrasDraftChanged(ExtrasPrices base, ExtrasDraft draft) {
  if (extrasDraftProblems(draft).isEmpty) {
    return extrasPricesFromInput(draft) != base;
  }
  final opened = extrasDraftOf(base);
  return Extra.values.any(
    (extra) => (draft[extra] ?? '').trim() != opened[extra],
  );
}

/// Why loading the prices for the form failed.
enum ExtrasLoadFailure {
  /// No answer of the server in time; the read stays open.
  noConnection,

  /// Anything else.
  other,
}

/// What the screen says after an attempt to save.
enum ExtrasSaveNotice {
  /// The server confirmed it (or it was already stored exactly so).
  saved,

  /// No answer in time: the prices may or may not be saved.
  noAnswer,

  noConnection,
  refused,
  changedElsewhere,
  unknown,
}

/// The notice for a save that certainly did not happen.
ExtrasSaveNotice noticeForSettingsWriteFailure(SettingsWriteFailure failure) {
  switch (failure) {
    case SettingsWriteFailure.noConnection:
      return ExtrasSaveNotice.noConnection;
    case SettingsWriteFailure.refused:
      return ExtrasSaveNotice.refused;
    case SettingsWriteFailure.changedElsewhere:
      return ExtrasSaveNotice.changedElsewhere;
    case SettingsWriteFailure.unknown:
      return ExtrasSaveNotice.unknown;
  }
}
