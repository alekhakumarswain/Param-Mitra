import 'package:flutter/material.dart';
import 'views/splash_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/signup_login_screen.dart';
import 'views/widgets/Mainscreen.dart';

void main() {
  runApp(const ParamMitraApp());
}

class ParamMitraApp extends StatelessWidget {
  const ParamMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6A0DAD), // Royal Purple
        scaffoldBackgroundColor: const Color(0xFF003366), // Deep Blue
        fontFamily: 'Roboto', // Sans-serif font
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signup-login': (context) => const SignupLoginScreen(),
        '/main': (context) => const MainScreen(), // Entry point with bottom nav
      },
    );
  }
}
