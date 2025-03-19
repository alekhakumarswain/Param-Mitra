import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/splash_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/signup_login_screen.dart';
import 'views/widgets/Mainscreen.dart';
import 'services/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Handle dynamic links at app startup
  try {
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      _handleDynamicLink(initialLink);
    }
  } catch (e) {
    debugPrint('Failed to get initial dynamic link: $e');
  }

  // Listen for dynamic links while the app is running
  try {
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      _handleDynamicLink(dynamicLinkData);
    }).onError((error) {
      debugPrint('Dynamic Link Failed: $error');
    });
  } catch (e) {
    debugPrint('Failed to listen for dynamic links: $e');
  }

  runApp(const ParamMitraApp());
}

void _handleDynamicLink(PendingDynamicLinkData dynamicLinkData) async {
  final Uri deepLink = dynamicLinkData.link;
  if (deepLink.path == '/email_verify') {
    final String? email = deepLink.queryParameters['email'];
    if (email != null &&
        FirebaseAuth.instance.isSignInWithEmailLink(deepLink.toString())) {
      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailLink(
          email: email,
          emailLink: deepLink.toString(),
        );
        if (userCredential.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({'emailVerified': true});
        }
      } catch (e) {
        debugPrint('Email verification failed: $e');
      }
    }
  }
}

class ParamMitraApp extends StatelessWidget {
  const ParamMitraApp({super.key});

  Future<String> _getInitialRoute() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    User? user = FirebaseAuth.instance.currentUser;

    if (!hasSeenOnboarding) {
      await prefs.setBool('hasSeenOnboarding', true);
      return '/onboarding';
    } else if (user != null) {
      return '/main';
    } else {
      return '/signup-login';
    }
  }

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
      home: FutureBuilder<String>(
        future: _getInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error determining initial route'));
          }
          return const SplashScreen(); // SplashScreen will handle navigation
        },
      ),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signup-login': (context) => const SignupLoginScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
