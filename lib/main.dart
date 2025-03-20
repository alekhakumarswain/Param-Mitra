import 'package:flutter/material.dart';
import 'views/splash_screen.dart';
import 'views/signup_login_screen.dart';
import 'views/widgets/MainScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParamMitraApp());
}

class ParamMitraApp extends StatelessWidget {
  const ParamMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6A0DAD),
        scaffoldBackgroundColor: const Color(0xFF003366),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/signup-login': (context) => const SignupLoginScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
