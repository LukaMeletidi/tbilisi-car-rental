/// A card in the multi-column grid is never narrower than this.
const catalogMinCardWidth = 400.0;

/// The grid never has more columns than this.
const catalogMaxColumns = 3;

/// In the single-column layout a card is never wider than this.
const catalogSingleColumnMaxWidth = 560.0;

/// How many columns of cards fit into [availableWidth].
int catalogColumnCount(double availableWidth) {
  final columns = (availableWidth / catalogMinCardWidth).floor();
  if (columns < 1) return 1;
  if (columns > catalogMaxColumns) return catalogMaxColumns;
  return columns;
}
