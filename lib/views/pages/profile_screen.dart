import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _userData;
  File? _imageFile;
  bool _isLiveLocationEnabled = false;
  bool _isShakePhoneEnabled = false;
  bool _isPowerButtonEnabled = false;
  bool _isVoiceActivationEnabled = false;
  bool _isSafetyAlertsEnabled = false;
  bool _isSafeZoneRemindersEnabled = false;
  bool _isLowBatterySosEnabled = false;
  bool _isTimerCheckInEnabled = false;
  bool _isBiometricEnabled = false;
  String _selectedLanguage = "English";
  String _secretSosPin = "";
  List<Map<String, String>> _emergencyContacts = [];
  bool _isLoading = true;
  bool _isUploading = false;

  Stream<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showCustomSnackBar('Location permission denied', isError: true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showCustomSnackBar('Location permission permanently denied',
          isError: true);
      return;
    }
    if (_isLiveLocationEnabled) {
      _startLocationUpdates();
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      _positionStream?.listen((Position position) async {
        await _updateLocationInFirestore(position);
      });
    } catch (e) {
      _showCustomSnackBar('Failed to start location updates: $e',
          isError: true);
    }
  }

  Future<void> _stopLocationUpdates() async {
    _positionStream = null;
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && _userData != null) {
        String userId = user.uid;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('locations')
            .doc(DateTime.now().toIso8601String())
            .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _showCustomSnackBar('Failed to update location: $e', isError: true);
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot? doc;
        int retries = 3;
        while (retries > 0) {
          doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
          retries--;
        }

        if (doc != null && doc.exists) {
          final DocumentSnapshot nonNullableDoc = doc;
          setState(() {
            _userData = nonNullableDoc.data() as Map<String, dynamic>;
            _isLiveLocationEnabled = _userData?['liveLocationToggle'] ?? false;
            _isShakePhoneEnabled = _userData?['shakePhoneSOS'] ?? false;
            _isPowerButtonEnabled = _userData?['powerButtonSOS'] ?? false;
            _isVoiceActivationEnabled =
                _userData?['voiceActivationSOS'] ?? false;
            _isSafetyAlertsEnabled = _userData?['safetyAlerts'] ?? false;
            _isSafeZoneRemindersEnabled =
                _userData?['safeZoneReminders'] ?? false;
            _isLowBatterySosEnabled = _userData?['lowBatterySos'] ?? false;
            _isTimerCheckInEnabled = _userData?['timerCheckIn'] ?? false;
            _isBiometricEnabled = _userData?['biometricAuth'] ?? false;
            _selectedLanguage = _userData?['language'] ?? "English";
            _secretSosPin = _userData?['secretSosPin'] ?? "";
            _emergencyContacts =
                (_userData?['emergencyContacts'] as List<dynamic>?)
                        ?.map((contact) => {
                              'name': contact['name']?.toString() ?? '',
                              'number': contact['number']?.toString() ?? '',
                            })
                        .toList() ??
                    [];
          });
          if (_isLiveLocationEnabled) {
            _startLocationUpdates();
          }
        } else {
          _showCustomSnackBar('User data not found. Please try again.',
              isError: true);
        }
      } else {
        _showCustomSnackBar('User not authenticated. Please log in again.',
            isError: true);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signup-login');
        }
      }
    } catch (e) {
      _showCustomSnackBar('Failed to fetch user data: $e', isError: true);
      debugPrint('Fetch user data error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isUploading = true;
      });

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Convert image to base64
      final bytes = await File(image.path).readAsBytes();
      String base64Image = base64Encode(bytes);
      String dataUrl = 'data:image/jpeg;base64,$base64Image';

      User? user = _auth.currentUser;
      if (user != null) {
        // Update Firestore with the Data URL
        await _firestore.collection('users').doc(user.uid).update({
          'profilePhotoUrl': dataUrl,
        });

        setState(() {
          _userData?['profilePhotoUrl'] = dataUrl;
        });

        _showCustomSnackBar('Profile picture updated successfully!');
      }
    } catch (e) {
      _showCustomSnackBar('Failed to upload image: $e', isError: true);
      debugPrint('Image upload error: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.purple),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.purple),
        ),
      ),
    );
  }

  Future<bool> _editUserInfo(BuildContext context) async {
    TextEditingController nameController =
        TextEditingController(text: _userData?['name']);
    TextEditingController emailController =
        TextEditingController(text: _userData?['email']);
    TextEditingController mobileController =
        TextEditingController(text: _userData?['mobile']);
    TextEditingController dobController =
        TextEditingController(text: _userData?['dob']);
    TextEditingController genderController =
        TextEditingController(text: _userData?['gender']);

    bool shouldUpdate = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            "Edit Profile",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, "Name"),
                const SizedBox(height: 10),
                _buildTextField(emailController, "Email"),
                const SizedBox(height: 10),
                _buildTextField(mobileController, "Mobile"),
                const SizedBox(height: 10),
                _buildTextField(dobController, "DOB"),
                const SizedBox(height: 10),
                _buildTextField(genderController, "Gender"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                shouldUpdate = true;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldUpdate) {
      try {
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'name': nameController.text,
            'email': emailController.text,
            'mobile': mobileController.text,
            'dob': dobController.text,
            'gender': genderController.text,
          });
          setState(() {
            _userData?['name'] = nameController.text;
            _userData?['email'] = emailController.text;
            _userData?['mobile'] = mobileController.text;
            _userData?['dob'] = dobController.text;
            _userData?['gender'] = genderController.text;
          });
          _showCustomSnackBar('Profile updated successfully!');
        }
      } catch (e) {
        _showCustomSnackBar('Failed to update profile: $e', isError: true);
      }
    }
    return shouldUpdate;
  }

  Future<bool> _addEmergencyContact(BuildContext context) async {
    if (_emergencyContacts.length >= 5) {
      _showCustomSnackBar('Maximum 5 contacts allowed', isError: true);
      return false;
    }
    TextEditingController nameController = TextEditingController();
    TextEditingController numberController = TextEditingController();

    bool shouldAdd = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            "Add Emergency Contact",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameController, "Name"),
              const SizedBox(height: 10),
              _buildTextField(numberController, "Number"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                shouldAdd = true;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Add",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldAdd) {
      try {
        setState(() {
          _emergencyContacts.add({
            "name": nameController.text,
            "number": numberController.text,
          });
        });
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'emergencyContacts': _emergencyContacts,
          });
          _showCustomSnackBar('Emergency contact added successfully!');
        }
      } catch (e) {
        _showCustomSnackBar('Failed to add contact: $e', isError: true);
        return false;
      }
    }
    return shouldAdd;
  }

  Future<bool> _editEmergencyContact(BuildContext context, int index) async {
    TextEditingController nameController =
        TextEditingController(text: _emergencyContacts[index]["name"]);
    TextEditingController numberController =
        TextEditingController(text: _emergencyContacts[index]["number"]);

    bool shouldUpdate = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            "Edit Emergency Contact",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameController, "Name"),
              const SizedBox(height: 10),
              _buildTextField(numberController, "Number"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                shouldUpdate = true;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldUpdate) {
      try {
        setState(() {
          _emergencyContacts[index] = {
            "name": nameController.text,
            "number": numberController.text,
          };
        });
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'emergencyContacts': _emergencyContacts,
          });
          _showCustomSnackBar('Emergency contact updated successfully!');
        }
      } catch (e) {
        _showCustomSnackBar('Failed to update contact: $e', isError: true);
        return false;
      }
    }
    return shouldUpdate;
  }

  void _deleteEmergencyContact(int index) async {
    try {
      setState(() {
        _emergencyContacts.removeAt(index);
      });
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'emergencyContacts': _emergencyContacts,
        });
        _showCustomSnackBar('Emergency contact deleted successfully!');
      }
    } catch (e) {
      _showCustomSnackBar('Failed to delete contact: $e', isError: true);
    }
  }

  Future<bool> _deleteAccount(BuildContext context) async {
    TextEditingController otpController = TextEditingController();
    bool shouldDelete = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            "Delete Account",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter OTP to confirm account deletion"),
              const SizedBox(height: 10),
              _buildTextField(otpController, "OTP"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                shouldDelete = true;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete) {
      try {
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).delete();
          await user.delete();
          _showCustomSnackBar('Account deleted successfully!');
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/signup-login', (route) => false);
          }
        }
      } catch (e) {
        _showCustomSnackBar('Failed to delete account: $e', isError: true);
        return false;
      }
    }
    return shouldDelete;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color.fromRGBO(255, 255, 255, 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  const Color.fromRGBO(255, 255, 255, 0.2),
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : _userData?['profilePhotoUrl'] is String &&
                                          (_userData!['profilePhotoUrl']
                                                  as String)
                                              .startsWith('data:image')
                                      ? MemoryImage(
                                          base64Decode(
                                              (_userData!['profilePhotoUrl']
                                                      as String)
                                                  .split(',')
                                                  .last),
                                        ) as ImageProvider<Object>
                                      : null,
                              child: _imageFile == null &&
                                      _userData?['profilePhotoUrl'] == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            GestureDetector(
                              onTap: _isUploading ? null : _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromRGBO(0, 0, 0, 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _isUploading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData?['name'] ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userData?['email'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userData?['mobile'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DOB: ${_userData?['dob'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gender: ${_userData?['gender'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _editUserInfo(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
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
                                  color: const Color.fromRGBO(0, 0, 0, 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Edit Info',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: const Color.fromRGBO(255, 255, 255, 0.2),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.white),
                        title: Text(
                          _emergencyContacts[index]["name"]!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _emergencyContacts[index]["number"]!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _editEmergencyContact(context, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEmergencyContact(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _addEmergencyContact(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
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
                          color: const Color.fromRGBO(0, 0, 0, 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Add New Contact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const Text(
                    'Live Location Sharing (SOS)',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  trailing: Switch(
                    value: _isLiveLocationEnabled,
                    onChanged: (value) async {
                      setState(() {
                        _isLiveLocationEnabled = value;
                      });
                      try {
                        User? user = _auth.currentUser;
                        if (user != null) {
                          await _firestore
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'liveLocationToggle': value,
                          });
                          if (value) {
                            await _startLocationUpdates();
                          } else {
                            await _stopLocationUpdates();
                          }
                        }
                      } catch (e) {
                        _showCustomSnackBar('Failed to update setting: $e',
                            isError: true);
                        setState(() {
                          _isLiveLocationEnabled = !value;
                        });
                      }
                    },
                    activeColor: Colors.purple.shade600,
                    activeTrackColor: Colors.purple.shade300,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade400,
                  ),
                  tileColor: const Color.fromRGBO(255, 255, 255, 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: const Color.fromRGBO(255, 255, 255, 0.1),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Shake Phone for SOS',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isShakePhoneEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isShakePhoneEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'shakePhoneSOS': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isShakePhoneEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          '3x Power Button for SOS',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isPowerButtonEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isPowerButtonEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'powerButtonSOS': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isPowerButtonEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          "Voice Activation ('Help me, Param Mitra')",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isVoiceActivationEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isVoiceActivationEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'voiceActivationSOS': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isVoiceActivationEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          'Low Battery SOS Alert',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isLowBatterySosEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isLowBatterySosEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'lowBatterySos': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isLowBatterySosEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          'Timer-Based Check-In',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isTimerCheckInEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isTimerCheckInEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'timerCheckIn': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isTimerCheckInEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: const Color.fromRGBO(255, 255, 255, 0.1),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Safety Alerts',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isSafetyAlertsEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isSafetyAlertsEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'safetyAlerts': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isSafetyAlertsEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          'Safe Zone Reminders',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isSafeZoneRemindersEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isSafeZoneRemindersEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'safeZoneReminders': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isSafeZoneRemindersEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const Text(
                    'Language',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  subtitle: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: Colors.purple.shade800,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(
                      height: 2,
                      color: Colors.white,
                    ),
                    onChanged: (String? newValue) async {
                      setState(() {
                        _selectedLanguage = newValue!;
                      });
                      try {
                        User? user = _auth.currentUser;
                        if (user != null) {
                          await _firestore
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'language': _selectedLanguage,
                          });
                        }
                      } catch (e) {
                        _showCustomSnackBar('Failed to update language: $e',
                            isError: true);
                      }
                    },
                    items: <String>['English', 'Hindi', 'Bengali']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Privacy & Security',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: const Color.fromRGBO(255, 255, 255, 0.1),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Biometric Authentication',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: Switch(
                          value: _isBiometricEnabled,
                          onChanged: (value) async {
                            setState(() {
                              _isBiometricEnabled = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'biometricAuth': value,
                                });
                              }
                            } catch (e) {
                              _showCustomSnackBar(
                                  'Failed to update setting: $e',
                                  isError: true);
                              setState(() {
                                _isBiometricEnabled = !value;
                              });
                            }
                          },
                          activeColor: Colors.purple.shade600,
                          activeTrackColor: Colors.purple.shade300,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "Secret SOS PIN",
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          obscureText: true,
                          onChanged: (value) async {
                            setState(() {
                              _secretSosPin = value;
                            });
                            try {
                              User? user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'secretSosPin': value,
                                });
                                _showCustomSnackBar(
                                    'SOS PIN set successfully!');
                              }
                            } catch (e) {
                              _showCustomSnackBar('Failed to set SOS PIN: $e',
                                  isError: true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Account Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _auth.signOut();
                      _showCustomSnackBar('Logged out successfully!');
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/signup-login', (route) => false);
                      }
                    } catch (e) {
                      _showCustomSnackBar('Failed to logout: $e',
                          isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Logout"),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _deleteAccount(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Delete Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
