import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_search_provider.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The white search field above the list. Searches by brand and model.
class CatalogSearchField extends ConsumerStatefulWidget {
  const CatalogSearchField({super.key});

  @override
  ConsumerState<CatalogSearchField> createState() =>
      _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends ConsumerState<CatalogSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(carSearchProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(carSearchProvider);
    final notifier = ref.read(carSearchProvider.notifier);

    // When the text is changed from outside the field (the clear button or
    // "Reset filters"), show the new text in the field.
    ref.listen(carSearchProvider, (previous, next) {
      if (_controller.text != next) _controller.text = next;
    });

    return OnWhite(
      child: TextField(
        controller: _controller,
        onChanged: notifier.setQuery,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.clearSearch,
                  onPressed: notifier.clear,
                ),
        ),
      ),
    );
  }
}
