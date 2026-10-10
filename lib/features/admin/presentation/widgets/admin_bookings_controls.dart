import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_bookings_filter_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The controls above the admin bookings list: the search field with the
/// sort menu next to it, and below them the status chips with their counts.
/// On a narrow phone the chips scroll sideways.
class AdminBookingsControls extends ConsumerWidget {
  const AdminBookingsControls({super.key, required this.view});

  final AdminBookingsView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminBookingsFilterProvider);
    final notifier = ref.read(adminBookingsFilterProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SearchField()),
            const SizedBox(width: 4),
            PopupMenuButton<AdminBookingsSort>(
              icon: const Icon(Icons.sort),
              tooltip: adminSortTooltip(filter.sort),
              initialValue: filter.sort,
              onSelected: notifier.setSort,
              itemBuilder: (context) => [
                for (final sort in AdminBookingsSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == filter.sort,
                    child: Text(adminSortLabel(sort)),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatusFilterChip(
                label: adminChipLabel(adminFilterAll, view.total),
                selected: filter.status == null,
                onSelected: () => notifier.setStatus(null),
              ),
              for (final status in BookingStatus.values)
                _StatusFilterChip(
                  label: adminChipLabel(
                    adminStatusLabel(status),
                    view.counts[status] ?? 0,
                  ),
                  selected: filter.status == status,
                  onSelected: () => notifier.setStatus(status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        // Compact, so that the five chips fit side by side on a wide
        // window; on a narrow phone the row scrolls sideways.
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        // Tapping the selected chip again keeps it selected.
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

/// The white search field. It searches the customer's name and phone among
/// the loaded bookings.
///
/// What is typed can be a name or a phone number, so the keyboard is told
/// not to learn it (no autocorrect, no suggestions) and there are no
/// autofill hints. The text is kept in memory only and is never logged.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(adminBookingsFilterProvider).search,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(
      adminBookingsFilterProvider.select((filter) => filter.search),
    );
    final notifier = ref.read(adminBookingsFilterProvider.notifier);

    // When the text is changed from outside the field ("Clear filters", the
    // x button, a reset after Sign out), show the new text in the field.
    // While the admin types, both already hold the same text.
    ref.listen(adminBookingsFilterProvider.select((filter) => filter.search), (
      previous,
      next,
    ) {
      if (_controller.text != next) _controller.text = next;
    });

    return OnWhite(
      child: TextField(
        controller: _controller,
        onChanged: notifier.setSearch,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          isDense: true,
          hintText: adminSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: adminClearSearch,
                  onPressed: () => notifier.setSearch(''),
                ),
        ),
      ),
    );
  }
}
