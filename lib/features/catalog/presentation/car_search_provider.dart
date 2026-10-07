import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The text in the catalog search field, exactly as typed.
///
/// Not auto-dispose, like the filter: the text is kept while the app runs,
/// also when the language changes. It is not saved across restarts.
class CarSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;

  void clear() => state = '';
}

final carSearchProvider = NotifierProvider<CarSearchNotifier, String>(
  CarSearchNotifier.new,
);
