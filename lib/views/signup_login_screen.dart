import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SignupLoginScreen extends StatefulWidget {
  const SignupLoginScreen({super.key});

  @override
  State<SignupLoginScreen> createState() => _SignupLoginScreenState();
}

class _SignupLoginScreenState extends State<SignupLoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoginMode = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String _gender = "Male";
  bool _isLoading = false;

  void _showStyledToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.transparent,
      textColor: Colors.white,
      fontSize: 16.0,
      webBgColor: "linear-gradient(to right, #FF6A88, #FF99AC)",
      webPosition: "center",
      webShowClose: true,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _nameController.clear();
    _numberController.clear();
    _emailController.clear();
    _passwordController.clear();
    _dobController.clear();
    setState(() {
      _gender = "Male";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade800, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLoginMode
                          ? 'Login to Param Mitra'
                          : 'Join Param Mitra',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (!_isLoginMode) ...[
                      _buildTextField(
                        label: 'Your Name',
                        controller: _nameController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Phone Number',
                        controller: _numberController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        prefixText: '+91 ',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Date of Birth (DD/MM/YYYY)',
                        controller: _dobController,
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownColor: Colors.blue.shade900,
                        style: const TextStyle(color: Colors.white),
                        items: ['Male', 'Female', 'Other']
                            .map((gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _gender = value!;
                          });
                        },
                      ),
                    ],
                    if (_isLoginMode) ...[
                      _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _isLoginMode ? _login : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              _isLoginMode ? 'Login' : 'Register',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: _signInWithGoogle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.grey.shade200],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.g_mobiledata,
                                    size: 30,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isLoginMode
                                        ? 'Login with Google'
                                        : 'Sign up with Google',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _clearFields();
                        });
                      },
                      child: Text(
                        _isLoginMode
                            ? 'Need an account? Sign Up'
                            : 'Already have an account? Login',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int? maxLength,
    String? prefixText,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple.shade400),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  void _register() async {
    if (_nameController.text.isEmpty ||
        _numberController.text.length != 10 ||
        _emailController.text.isEmpty ||
        _passwordController.text.length < 6 ||
        _dobController.text.isEmpty) {
      _showStyledToast('Please fill all fields correctly');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        Map<String, dynamic> userData = {
          'name': _nameController.text,
          'mobile': '+91${_numberController.text}',
          'email': _emailController.text,
          'dob': _dobController.text,
          'gender': _gender,
          'emergencyContacts': [],
          'liveLocationToggle': false,
          'biometricToggle': false,
          'selectedLanguage': 'English',
          'emailVerified': false,
          'profilePhotoUrl': null,
        };
        await _firestore.collection('users').doc(user.uid).set(userData);

        await _sendEmailVerificationLink(user);
        _showStyledToast('Verification email sent! Please check your inbox.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak. Use at least 6 characters.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
      }
      _showStyledToast(errorMessage);
    } catch (e) {
      _showStyledToast('An unexpected error occurred: $e');
      debugPrint('Registration error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showStyledToast('Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        if (!user.emailVerified) {
          _showStyledToast('Please verify your email first');
          await _sendEmailVerificationLink(user);
          setState(() {
            _isLoading = false;
          });
          return;
        }

        bool hasLocation = await _checkAndRequestLocation();
        if (hasLocation) {
          Position position = await Geolocator.getCurrentPosition();
          await _database.child('locations/${user.uid}').set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          });
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/main');
          }
        } else {
          _showStyledToast('Please enable location services');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _showStyledToast(errorMessage);
    } catch (e) {
      _showStyledToast('An unexpected error occurred: $e');
      debugPrint('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          _showGoogleDetailsDialog(user);
        } else {
          bool hasLocation = await _checkAndRequestLocation();
          if (hasLocation) {
            Position position = await Geolocator.getCurrentPosition();
            await _database.child('locations/${user.uid}').set({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': DateTime.now().toIso8601String(),
            });
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/main');
            }
          } else {
            _showStyledToast('Please enable location services');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with a different credential.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid Google credentials.';
          break;
        default:
          errorMessage = 'Google Sign-In failed: ${e.message}';
      }
      _showStyledToast(errorMessage);
    } catch (e) {
      _showStyledToast('An unexpected error occurred: $e');
      debugPrint('Google Sign-In error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showGoogleDetailsDialog(User user) {
    TextEditingController numberController = TextEditingController();
    TextEditingController dobController = TextEditingController();
    String gender = "Male";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade800, Colors.blue.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: numberController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixText: '+91 ',
                          prefixStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.purple.shade400),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: dobController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth (DD/MM/YYYY)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.purple.shade400),
                          ),
                        ),
                        keyboardType: TextInputType.datetime,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.purple.shade400),
                          ),
                        ),
                        dropdownColor: Colors.blue.shade900,
                        style: const TextStyle(color: Colors.white),
                        items: ['Male', 'Female', 'Other']
                            .map((gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            gender = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              if (numberController.text.length == 10 &&
                                  dobController.text.isNotEmpty) {
                                try {
                                  Map<String, dynamic> userData = {
                                    'name': user.displayName ?? '',
                                    'mobile': '+91${numberController.text}',
                                    'email': user.email ?? '',
                                    'dob': dobController.text,
                                    'gender': gender,
                                    'emergencyContacts': [],
                                    'liveLocationToggle': false,
                                    'biometricToggle': false,
                                    'selectedLanguage': 'English',
                                    'emailVerified': true,
                                    'profilePhotoUrl': null,
                                  };
                                  await _firestore
                                      .collection('users')
                                      .doc(user.uid)
                                      .set(userData);

                                  bool hasLocation =
                                      await _checkAndRequestLocation();
                                  if (hasLocation) {
                                    Position position =
                                        await Geolocator.getCurrentPosition();
                                    await _database
                                        .child('locations/${user.uid}')
                                        .set({
                                      'latitude': position.latitude,
                                      'longitude': position.longitude,
                                      'timestamp':
                                          DateTime.now().toIso8601String(),
                                    });
                                    if (mounted) {
                                      Navigator.pop(context);
                                      Navigator.pushReplacementNamed(
                                          context, '/main');
                                    }
                                  } else {
                                    _showStyledToast(
                                        'Please enable location services');
                                  }
                                } catch (e) {
                                  _showStyledToast(
                                      'Failed to save profile: $e');
                                  debugPrint('Profile save error: $e');
                                }
                              } else {
                                _showStyledToast(
                                    'Enter a valid 10-digit number and DOB');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade600,
                                    Colors.blue.shade600,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendEmailVerificationLink(User user) async {
    try {
      await user.sendEmailVerification();
    } catch (e) {
      _showStyledToast('Failed to send verification email: $e');
      debugPrint('Email verification error: $e');
    }
  }

  Future<bool> _checkAndRequestLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;
      return true;
    } catch (e) {
      _showStyledToast('Location permission error: $e');
      debugPrint('Location permission error: $e');
      return false;
    }
  }
}
