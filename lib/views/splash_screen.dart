import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // Start initialization and set a maximum timeout of 5 seconds
    _initializeWithTimeout();
  }

  Future<void> _initializeWithTimeout() async {
    // Create a future that completes after 5 seconds
    final timeoutFuture = Future.delayed(const Duration(seconds: 5));

    // Run initialization tasks
    final initFuture = _initializeApp();

    // Wait for either initialization to complete or the timeout to occur
    await Future.any([initFuture, timeoutFuture]);

    // If initialization is complete, navigate immediately
    if (_isInitialized) {
      _navigateToNextScreen();
    } else {
      // If timeout occurred but initialization isn't complete, wait for it to finish
      await initFuture;
      _navigateToNextScreen();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Load the .env file
      await dotenv.load(fileName: ".env").catchError((e) {
        debugPrint('Failed to load .env file: $e');
        dotenv.env['Gemini_API_KEY'] =
            'AIzaSyDJ7nuaU3xBtB2H6VPGDes8vtICGbrRTCo';
      });

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize dynamic links
      await _initializeDynamicLinks();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Initialization failed: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeDynamicLinks() async {
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
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      _handleDynamicLink(dynamicLinkData);
    }).onError((error) {
      debugPrint('Dynamic Link Failed: $error');
    });
  }

  void _handleDynamicLink(PendingDynamicLinkData dynamicLinkData) async {
    final Uri deepLink = dynamicLinkData.link;
    if (deepLink.path == '/email_verify') {
      final String? email = deepLink.queryParameters['email'];
      if (email != null &&
          FirebaseAuth.instance.isSignInWithEmailLink(deepLink.toString())) {
        try {
          final userCredential =
              await FirebaseAuth.instance.signInWithEmailLink(
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

  void _navigateToNextScreen() {
    if (mounted) {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/signup-login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A0DAD), // Royal Purple
              Color(0xFF003366), // Deep Blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/image/logo.png',
                      height: 230,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Param Mitra (परम मित्र)",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your Supreme Protector, Anytime, Anywhere.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isInitialized)
                const Positioned(
                  bottom: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
