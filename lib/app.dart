import 'package:flutter/material.dart';
import 'features/rescue/rescue_screen.dart';
import 'shared/theme/app_theme.dart';

class HorusApp extends StatelessWidget {
  const HorusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horus',
      theme: AppTheme.rescueTheme,
      home: const RescueScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
