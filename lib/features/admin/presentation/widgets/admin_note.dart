import 'package:flutter/material.dart';

/// A short line with an icon, on the purple page. Used for the notes of
/// the admin area, such as "Offline: showing saved data".
class AdminNote extends StatelessWidget {
  const AdminNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
