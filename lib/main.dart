import 'package:flutter/material.dart';

import 'screens/key_selection_screen.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.instance.init();
  runApp(const ProgressionSessionApp());
}

class ProgressionSessionApp extends StatelessWidget {
  const ProgressionSessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progression Session',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      // ── Dark theme ──
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C4DFF), // deep purple accent
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      // ── Light fallback ──
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        useMaterial3: true,
      ),
      home: const KeySelectionScreen(),
    );
  }
}
