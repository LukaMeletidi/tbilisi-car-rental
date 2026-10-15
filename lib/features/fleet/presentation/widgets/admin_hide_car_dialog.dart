import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// Asks "Hide this car?" and returns true when the admin chose Hide. Used
/// by the Hide button of the list and by Save of the edit form when the
/// form hides the car.
Future<bool> confirmHideCar(BuildContext context) async {
  final hide = await showDialog<bool>(
    context: context,
    builder: (context) => const _HideCarDialog(),
  );
  return hide ?? false;
}

/// White, with dark text.
class _HideCarDialog extends StatelessWidget {
  const _HideCarDialog();

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(adminHideCarTitle),
        content: const Text(adminHiddenCarNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(adminCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(adminCarHide),
          ),
        ],
      ),
    );
  }
}
