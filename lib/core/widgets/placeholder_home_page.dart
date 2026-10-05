import 'package:flutter/material.dart';

/// Temporary home screen. Replaced by the public catalog in Phase 1.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tbilisi Car Rental')),
      body: const Center(child: Text('Project skeleton is running.')),
    );
  }
}
