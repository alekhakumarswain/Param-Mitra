import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupLoginScreen extends StatefulWidget {
  const SignupLoginScreen({super.key});

  @override
  State<SignupLoginScreen> createState() => _SignupLoginScreenState();
}

class _SignupLoginScreenState extends State<SignupLoginScreen> {
  // State variables for login
  String _loginEmailOrPhone = "";
  String _loginPassword = "";
  bool _isLogin = true;

  // State variables for signup (mark _phoneOtp as final since unused)
  final String _phoneOtp = ""; // Unused, marked as final
  String _signupName = "";
  String _signupNumber = "";
  String _signupEmail = "";
  String _signupPassword = "";
  bool _isOtpSent = false;
  bool _isPhoneVerified = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to Param Mitra',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isLogin ? _buildLoginForm() : _buildSignupForm(),
                  if (_isOtpSent && !_isLogin)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'Please check your email for verification link',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _isOtpSent = false;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Need an account? Sign Up'
                          : 'Already have an account? Login',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6A0DAD),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _loginEmailOrPhone = value),
          decoration: InputDecoration(
            labelText: 'Email or Phone Number',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'e.g., example@domain.com or +91-1234567890',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) => setState(() => _loginPassword = value),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          obscureText: true,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loginEmailOrPhone.isEmpty || _loginPassword.isEmpty
              ? null
              : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6A0DAD),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text(
            'Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _signupName = value),
          decoration: InputDecoration(
            labelText: 'Name',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) => setState(() => _signupNumber = value),
          decoration: InputDecoration(
            labelText: 'Phone Number',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'e.g., +91-1234567890',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: _isPhoneVerified
                ? const Icon(Icons.check, color: Colors.green)
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) => setState(() => _signupEmail = value),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) => setState(() => _signupPassword = value),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white
                .withAlpha(51), // Replace withOpacity with withAlpha
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          obscureText: true,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _signupName.isEmpty ||
                  _signupNumber.isEmpty ||
                  _signupEmail.isEmpty ||
                  _signupPassword.isEmpty
              ? null
              : (_isOtpSent ? null : _sendOtp),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6A0DAD),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text(
            'Send OTP',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _login() async {
    if (!mounted) return;
    try {
      UserCredential userCredential;
      if (_loginEmailOrPhone.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _loginEmailOrPhone,
          password: _loginPassword,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone login requires OTP setup')),
        );
        return;
      }
      if (userCredential.user != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  void _sendOtp() async {
    if (!mounted) return;
    setState(() => _isOtpSent = true);

    try {
      await _auth.sendSignInLinkToEmail(
        email: _signupEmail,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://parammitra.page.link/email_verify',
          handleCodeInApp: true,
          androidPackageName: 'com.example.param_mitra',
          androidInstallApp: true,
          linkDomain:
              'parammitra.page.link', // Replace deprecated dynamicLinkDomain
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verification link sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email link failed: $e')),
      );
      setState(() => _isOtpSent = false);
    }

    // Skip Phone OTP due to billing not enabled or limit reached
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Phone OTP skipped due to billing not enabled or limit reached')),
    );
    _showOtpDialog();
  }

  void _showOtpDialog() {
    TextEditingController phoneOtpController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verify Phone OTP (Optional)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneOtpController,
                decoration:
                    const InputDecoration(labelText: 'Phone OTP (if received)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted) return;
                setState(() => _isPhoneVerified = true);
                await _signup();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Skip and Sign Up'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signup() async {
    if (!mounted) return;
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _signupEmail,
        password: _signupPassword,
      );
      await userCredential.user?.sendEmailVerification();
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _signupName,
        'email': _signupEmail,
        'mobile': _signupNumber,
        'emailVerified': false,
      });
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }

  void _signInWithGoogle() async {
    if (!mounted) return;
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential =
          await _auth.signInWithProvider(googleProvider);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          _showGoogleDetailsDialog(user);
        } else {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  void _showGoogleDetailsDialog(User user) {
    TextEditingController nameController =
        TextEditingController(text: user.displayName ?? '');
    TextEditingController mobileController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Complete Your Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted) return;
                await _firestore.collection('users').doc(user.uid).set({
                  'name': nameController.text,
                  'email': user.email,
                  'mobile': mobileController.text,
                  'emergencyContacts': [
                    {'name': 'Parent', 'number': '+91-1234567890'},
                    {'name': 'Friend', 'number': '+91-0987654321'},
                  ],
                  'liveLocationToggle': false,
                  'biometricToggle': false,
                  'selectedLanguage': 'English',
                });
                if (!mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/main');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
