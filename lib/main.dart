import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/pawstay_theme.dart';
import 'Screen/auth/splash_screen.dart';
import 'widgets/no_network_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv
        .load(fileName: ".env")
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
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
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: PawStayTheme.primary,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF171412),
          ),
          themeMode: currentMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final scaledChild = MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.15,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
            // Wrap with ConnectivityWrapper so the offline screen shows
            // automatically whenever the device loses internet access.
            return ConnectivityWrapper(child: scaledChild);
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
