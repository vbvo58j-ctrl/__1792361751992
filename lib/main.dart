import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlosabApp());
}

class BlosabApp extends StatelessWidget {
  const BlosabApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF075E54);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'بلوساب',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        appBarTheme: const AppBarTheme(
          backgroundColor: green,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      home: const HomeScreen(),
    );
  }
}