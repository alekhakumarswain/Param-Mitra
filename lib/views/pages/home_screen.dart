import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import the geocoding package

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLiveLocationEnabled = false;
  String _currentLocation = 'Fetching location...';
  String _safetyStatus = 'Safe'; // Placeholder for safety status
  bool _isLoading = true;

  // Method to get the first name from the full name
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return 'User';
    }
    return fullName.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _requestLocationPermission();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

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
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signup-login');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to fetch user data: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        desiredAccuracy: LocationAccuracy.high,
      );

      // Perform reverse geocoding to get the city name
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Extract the city name (locality) from the placemark
      String cityName = 'Unknown';
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        cityName =
            placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown';
      }

      if (mounted) {
        setState(() {
          _currentLocation = cityName; // Update the location to the city name
        });
      }

      if (_isLiveLocationEnabled) {
        _updateLocationInFirestore(position);
      }
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
    setState(() {
      _isLiveLocationEnabled = value;
    });
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'liveLocationToggle': value,
        });
        if (value) {
          _getCurrentLocation();
        }
      }
    } catch (e) {
      _showSnackBar('Failed to update live location setting: $e',
          isError: true);
      setState(() {
        _isLiveLocationEnabled = !value;
      });
    }
  }

  void _triggerSOS() {
    _showSnackBar('SOS triggered!');
  }

  void _startFakeCall() {
    _showSnackBar('Fake call initiated!');
  }

  void _navigateToSafePath() {
    _showSnackBar('Navigating to SafePath!');
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
              // Top Section: User Info and Status
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${_getFirstName(_userData?['name'])}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current Location: $_currentLocation',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70),
                        ),
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
                      child: Text(
                        _safetyStatus,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // SOS Button
                        GestureDetector(
                          onLongPress: _triggerSOS,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Live Location Sharing Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Live Location Sharing',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
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

                        // SafePath Navigation Button
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

                        // Fake Call Trigger Button
                        ElevatedButton.icon(
                          onPressed: _startFakeCall,
                          icon: const Icon(Icons.phone),
                          label: const Text('Fake Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6A0DAD),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Latest Safety Alerts
                        const Text(
                          'Latest Safety Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('safety_alerts')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final alerts = snapshot.data!.docs;
                            if (alerts.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'No recent alerts in your area.',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.white),
                                ),
                              );
                            }
                            return Column(
                              children: alerts.map((alert) {
                                final data =
                                    alert.data() as Map<String, dynamic>;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    data['message'] ?? 'Unknown alert',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white),
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
