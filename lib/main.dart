import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const BlosabApp());
}

class BlosabApp extends StatelessWidget {
  const BlosabApp({super.key});
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF075E54);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'بلوساب',
        themeMode: ThemeController.instance.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green),
          appBarTheme: const AppBarTheme(backgroundColor: green, foregroundColor: Colors.white),
          scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF123D38), foregroundColor: Colors.white),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}