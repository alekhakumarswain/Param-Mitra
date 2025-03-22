import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/fakeCall.dart';
import '../pages/safepath_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final List<Map<String, dynamic>> _callOptions = [
  {
    'title': 'Emergency Contact',
    'icon': Icons.emergency,
    'color': Colors.red,
  },
  {
    'title': 'Bapa',
    'icon': Icons.family_restroom,
    'color': Colors.blue,
  },
  {
    'title': 'Police',
    'icon': Icons.local_police,
    'color': Colors.blueGrey,
  },
  {
    'title': 'Women Safety',
    'icon': Icons.security,
    'color': Colors.purple,
  },
  {
    'title': 'Bhai',
    'icon': Icons.people_alt,
    'color': Colors.green,
  },
];

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _userData;
  bool _isLiveLocationEnabled = false;
  String _currentLocation = 'Fetching location...';
  String _safetyStatus = 'Safe';
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchUserData();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _deleteSOSAlert(String alertKey) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _rtdb.child('SoSAlert/${user.uid}/$alertKey').remove();
        _showSnackBar('SOS alert deleted successfully');
      }
    } catch (e) {
      _showSnackBar('Failed to delete SOS alert: $e', isError: true);
    }
  }

  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'User';
    return fullName.split(' ').first;
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>;
            _isLiveLocationEnabled = _userData?['liveLocationToggle'] ?? false;
          });
        } else {
          _showSnackBar('User data not found.', isError: true);
        }
      } else {
        _showSnackBar('User not authenticated. Please log in.', isError: true);
        if (mounted) Navigator.pushReplacementNamed(context, '/signup-login');
      }
    } catch (e) {
      _showSnackBar('Failed to fetch user data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied', isError: true);
        setState(() => _currentLocation = 'Location unavailable');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission permanently denied', isError: true);
      setState(() => _currentLocation = 'Location unavailable');
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String cityName = placemarks.isNotEmpty
          ? (placemarks.first.locality ??
              placemarks.first.subAdministrativeArea ??
              'Unknown')
          : 'Unknown';
      if (mounted) setState(() => _currentLocation = cityName);
      if (_isLiveLocationEnabled) _updateLocationInFirestore(position);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to get location: $e', isError: true);
        setState(() => _currentLocation = 'Location unavailable');
      }
    }
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('locations')
            .doc(DateTime.now().toIso8601String())
            .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _showSnackBar('Failed to update location: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _toggleLiveLocation(bool value) async {
    setState(() => _isLiveLocationEnabled = value);
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'liveLocationToggle': value});
        if (value) _getCurrentLocation();
      }
    } catch (e) {
      _showSnackBar('Failed to update live location setting: $e',
          isError: true);
      setState(() => _isLiveLocationEnabled = !value);
    }
  }

  void _triggerSOS() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', isError: true);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> sosData = {
        'Name': userData['name'] ?? 'Unknown',
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude
        },
        'User Number': userData['mobile'] ?? 'Not provided',
        'User emergency contact number': _getEmergencyContact(userData),
        'Device motion details': 'Not implemented',
        'Time of SoS': DateTime.now().toIso8601String(),
        'Date of SoS': DateTime.now().toLocal().toString().split(' ')[0],
        'User Identification': userData,
        'Geofencing Data': 'Not implemented'
      };
      await _rtdb.child('SoSAlert/${user.uid}').push().set(sosData);
      _showSnackBar('SOS alert sent successfully!');
    } catch (e) {
      _showSnackBar('Failed to send SOS: $e', isError: true);
    }
  }

  String _getEmergencyContact(Map<String, dynamic> userData) {
    if (userData['emergencyContacts'] is List &&
        (userData['emergencyContacts'] as List).isNotEmpty) {
      return (userData['emergencyContacts'] as List).first['number'] ??
          'Not provided';
    }
    return 'Not provided';
  }

  void _startFakeCall() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => FakeCall(callerName: 'Emergency Contact')));
  }

  void _navigateToSafePath() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => SafePathScreen()));
  }

  void _showCallSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6A0DAD),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Call Type',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ..._callOptions.map((option) => ListTile(
                      leading: Icon(option['icon'], color: option['color']),
                      title: Text(
                        option['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FakeCall(
                              callerName: option['title'],
                            ),
                          ),
                        );
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${_getFirstName(_userData?['name'])}',
                            style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('Current Location: $_currentLocation',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _safetyStatus == 'Safe' ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_safetyStatus,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTapDown: (_) {
                            if (!mounted) return;
                            setState(() => _isPressed = true);
                            _animationController.forward();
                          },
                          onTapUp: (_) {
                            if (!mounted) return;
                            setState(() => _isPressed = false);
                            _animationController.reverse();
                            _triggerSOS();
                          },
                          onTapCancel: () {
                            if (!mounted) return;
                            setState(() => _isPressed = false);
                            _animationController.reverse();
                          },
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [Colors.red, Color(0xFFD00000)],
                                      center: Alignment.center,
                                      radius: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: _isPressed ? 10 : 5,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: _isPressed ? 180 : 0,
                                        height: _isPressed ? 180 : 0,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(
                                              _isPressed ? 0.2 : 0),
                                        ),
                                      ),
                                      const Text(
                                        'SOS',
                                        style: TextStyle(
                                          fontSize: 32,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black26,
                                                offset: Offset(2, 2),
                                                blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                      if (_isPressed)
                                        ...List.generate(8, (index) {
                                          return Positioned(
                                            top: 75 +
                                                (index % 2 == 0 ? -20 : 20),
                                            left: 75 + (index < 4 ? -20 : 20),
                                            child: AnimatedOpacity(
                                              opacity: _isPressed ? 1.0 : 0.0,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Live Location Sharing',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                            const SizedBox(width: 10),
                            Switch(
                              value: _isLiveLocationEnabled,
                              onChanged: _toggleLiveLocation,
                              activeColor: Colors.white,
                              inactiveTrackColor: Colors.white54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _navigateToSafePath,
                          icon: const Icon(Icons.map),
                          label: const Text('SafePath Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6A0DAD),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _showCallSelectionDialog,
                          icon: const Icon(Icons.phone, size: 28),
                          label: const Text(
                            'Call',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 70, 220, 53),
                            foregroundColor:
                                const Color.fromARGB(255, 16, 15, 15),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(45),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Your SOS Alerts',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        StreamBuilder<DatabaseEvent>(
                          stream: _rtdb
                              .child('SoSAlert/${_auth.currentUser?.uid}')
                              .onValue,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const CircularProgressIndicator();
                            final alerts = Map<String, dynamic>.from((snapshot
                                    .data!
                                    .snapshot
                                    .value as Map<dynamic, dynamic>?) ??
                                {});

                            if (alerts.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'No SOS alerts created yet.',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.white70),
                                ),
                              );
                            }

                            return Column(
                              children: alerts.entries.map((entry) {
                                final alertData = Map<String, dynamic>.from(
                                    entry.value as Map<dynamic, dynamic>);
                                final userInfo = Map<String, dynamic>.from(
                                    alertData['User Identification']
                                        as Map<dynamic, dynamic>);

                                return Container(
                                  width: double.infinity,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.red[300],
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'EMERGENCY ALERT • ${alertData['Date of SoS']}',
                                                    style: TextStyle(
                                                      color: Colors.red[300],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                userInfo['name'] ??
                                                    'Unknown User',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Time: ${DateFormat('HH:mm').format(DateTime.parse(alertData['Time of SoS']))}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Location: ${alertData['location']?['latitude']?.toStringAsFixed(4)}, '
                                                '${alertData['location']?['longitude']?.toStringAsFixed(4)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              _deleteSOSAlert(entry.key),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
