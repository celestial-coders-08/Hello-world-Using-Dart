import 'package:flutter/material.dart';
import 'theme/pawstay_theme.dart';
import 'Screen/auth/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PawStayTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PawStay',
          theme: PawStayTheme.lightTheme,
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
