import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/firebase_options.dart';

Future<void> main() async {
  // Needed because we call Firebase before runApp().
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: TbilisiCarRentalApp()));
}

class TbilisiCarRentalApp extends ConsumerWidget {
  const TbilisiCarRentalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Tbilisi Car Rental',
      routerConfig: router,
    );
  }
}
