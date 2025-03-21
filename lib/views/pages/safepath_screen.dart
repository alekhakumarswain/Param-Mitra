import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafePathScreen extends StatefulWidget {
  const SafePathScreen({super.key});

  @override
  State<SafePathScreen> createState() => _SafePathScreenState();
}

class _SafePathScreenState extends State<SafePathScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  final List<LatLng> _pathPoints = []; // Stores the user's path
  StreamSubscription<Position>?
      _positionStreamSubscription; // Subscription for location updates

  List<LatLng> _safeRoutePoints = [];
  List<LatLng> _unsafeRoutePoints = [];
  bool _isLoading = true;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, Object>> _autocompleteSuggestions = [];
  String _selectedDestination = '';
  double _estimatedDistance = 0.0; // In kilometers
  int _estimatedTime = 0; // In minutes

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _debounceTimer;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, LatLng> _nearbyLocations = {};

  final List<LatLng> _highRiskZones = [
    LatLng(20.2970, 85.8220),
    LatLng(20.2980, 85.8230),
  ];

  // Custom Alerts for High-Risk Zones
  void _checkHighRiskZones() {
    for (var zone in _highRiskZones) {
      if (_currentPosition != null &&
          _calculateDistance(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  zone) <
              0.5) {
        // 0.5 km radius
        _showCustomSnackBar('⚠️ You are entering a high-risk zone!',
            isError: true);
      }
    }
  }

  // Save User's Path History
  void _savePathHistory() async {
    User? user = _auth.currentUser;
    if (user != null && _pathPoints.isNotEmpty) {
      try {
        await _firestore.collection('pathHistory').doc(user.uid).set({
          'path': _pathPoints
              .map((point) => {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                  })
              .toList(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('Path history saved successfully');
      } catch (e) {
        debugPrint('Error saving path history: $e');
      }
    }
  }

  // Share Live Location
  void _shareLiveLocation() async {
    User? user = _auth.currentUser;
    if (user != null && _currentPosition != null) {
      try {
        await _firestore.collection('liveLocations').doc(user.uid).set({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _showCustomSnackBar('Live location shared successfully!');
      } catch (e) {
        _showCustomSnackBar('Error sharing live location: $e', isError: true);
      }
    }
  }

  // Fetch User Locations from Firestore
  Future<void> _fetchUserLocations() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          List<dynamic> locations = data['locations'] ?? [];
          for (var location in locations) {
            _nearbyLocations[location['name']] =
                LatLng(location['latitude'], location['longitude']);
          }
        }
      } catch (e) {
        debugPrint('Error fetching user locations: $e');
      }
    }
  }

  // Start Path Tracking
  void _startPathTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _pathPoints.add(LatLng(position.latitude, position.longitude));
        });
        _checkHighRiskZones();
        _savePathHistory();
      }
    });
  }

  // Calculate Distance Between Two Points
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000;
  }

  // Show Custom SnackBar
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchUserLocations();
    _startPathTracking();
    _startAnimations();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Initialize Animations
  void _startAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error fetching location. Using default location.')),
      );
    }
  }

  Future<void> _fetchRouteToDestination(LatLng destination) async {
    if (_currentPosition == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location unavailable.')),
      );
      return;
    }

    double? v1 = _currentPosition?.latitude;
    double? v2 = _currentPosition?.longitude;
    double v3 = destination.latitude;
    double v4 = destination.longitude;

    if (v1 == null || v2 == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location unavailable.')),
      );
      return;
    }

    try {
      var url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/$v2,$v1;$v4,$v3?steps=true&annotations=true&geometries=geojson&overview=full');
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['routes'] == null || data['routes'].isEmpty) {
          throw Exception('No routes found in response');
        }

        var coordinates =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>?;
        if (coordinates == null) {
          throw Exception('Invalid route data');
        }

        double distance =
            (data['routes'][0]['distance'] as num?)?.toDouble() ?? 0.0;
        double duration =
            (data['routes'][0]['duration'] as num?)?.toDouble() ?? 0.0;

        if (!mounted) return;
        setState(() {
          _safeRoutePoints = coordinates
              .map<LatLng>(
                  (coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();
          _unsafeRoutePoints = _simulateUnsafeZones(_safeRoutePoints);
          _estimatedDistance = distance / 1000;
          _estimatedTime = (duration / 60).round();
          _isLoading = false;
          _hasError = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load route. Status: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error fetching route data. Please check your internet.')),
      );
    }
  }

  List<LatLng> _simulateUnsafeZones(List<LatLng> routePoints) {
    List<LatLng> unsafePoints = [];
    for (var point in routePoints) {
      for (var riskZone in _highRiskZones) {
        if (_calculateDistance(point, riskZone) < 0.005) {
          unsafePoints.add(point);
        }
      }
    }
    return unsafePoints;
  }

  void _zoomIn() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _setDestination(String destinationName, LatLng destination) {
    if (!mounted) return;
    setState(() {
      _selectedDestination = destinationName;
      _isLoading = true;
      _fetchRouteToDestination(destination);
    });
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _safeRoutePoints = [];
      _unsafeRoutePoints = [];
      _estimatedDistance = 0.0;
      _estimatedTime = 0;
    });
    if (_selectedDestination.isNotEmpty) {
      if (_nearbyLocations.containsKey(_selectedDestination)) {
        _fetchRouteToDestination(_nearbyLocations[_selectedDestination]!);
      } else {
        _onSearch();
      }
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _autocompleteSuggestions = [];
      });
      return;
    }

    List<Map<String, Object>> suggestions = _nearbyLocations.keys
        .where((key) => key.toLowerCase().contains(query.toLowerCase()))
        .map((key) => <String, Object>{
              'name': key,
              'lat': _nearbyLocations[key]!.latitude,
              'lon': _nearbyLocations[key]!.longitude,
              'source': 'predefined',
            })
        .toList();

    if (query.length > 2) {
      try {
        var encodedQuery = Uri.encodeQueryComponent(query);
        var url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=10&countrycodes=IN');
        var response = await http.get(url, headers: {
          'User-Agent': 'SafePathApp/1.0 (contact: example@email.com)',
        });

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body) as List<dynamic>;
          suggestions.addAll(data.map((item) => <String, Object>{
                'name': item['display_name'] ?? 'Unknown',
                'lat': double.tryParse(item['lat'] ?? '0.0') ?? 0.0,
                'lon': double.tryParse(item['lon'] ?? '0.0') ?? 0.0,
                'source': 'api',
              }));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'API Error: ${response.statusCode}. Try again later.')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network Error: $e')),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _autocompleteSuggestions = suggestions;
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchLocationSuggestions(value);
    });
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination.')),
      );
      return;
    }

    if (_nearbyLocations.containsKey(query)) {
      if (!mounted) return;
      setState(() {
        _selectedDestination = query;
        _isLoading = true;
        _autocompleteSuggestions.clear();
        _searchController.clear();
      });
      _fetchRouteToDestination(_nearbyLocations[query]!);
      return;
    }

    var selectedSuggestion = _autocompleteSuggestions.firstWhere(
      (s) => s['name'].toString().toLowerCase() == query.toLowerCase(),
      orElse: () => <String, Object>{},
    );

    if (selectedSuggestion.isNotEmpty) {
      LatLng destinationLatLng = LatLng(selectedSuggestion['lat'] as double,
          selectedSuggestion['lon'] as double);
      if (!mounted) return;
      setState(() {
        _selectedDestination = selectedSuggestion['name'] as String;
        _isLoading = true;
        _autocompleteSuggestions.clear();
        _searchController.clear();
      });
      _fetchRouteToDestination(destinationLatLng);
    } else {
      _fetchLocationSuggestions(query).then((_) {
        if (_autocompleteSuggestions.isNotEmpty) {
          var firstResult = _autocompleteSuggestions[0];
          LatLng destinationLatLng = LatLng(
              firstResult['lat'] as double, firstResult['lon'] as double);
          if (!mounted) return;
          setState(() {
            _selectedDestination = firstResult['name'] as String;
            _isLoading = true;
            _autocompleteSuggestions.clear();
            _searchController.clear();
          });
          _fetchRouteToDestination(destinationLatLng);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No location found for this query.')),
          );
        }
      });
    }
  }

  Future<void> _triggerSOS() async {
    _animationController.forward().then((_) async {
      if (!mounted) return;
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          List<dynamic> emergencyContacts =
              doc['emergencyContacts'] as List<dynamic>? ?? [];
          if (emergencyContacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No emergency contacts found. Please add contacts in the Profile section.')),
            );
          } else {
            // Simulate notifying emergency contacts
            for (var contact in emergencyContacts) {
              String name = contact['name'] as String;
              String number = contact['number'] as String;
              // In a real app, you would send an SMS or make a call here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Notified $name ($number) with your location.')),
              );
            }
          }
        }
      }
      _animationController.reverse();
    });
  }

  void _triggerLongPressSOS() {
    _animationController.forward().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Live location sharing and audio recording activated!')),
      );
      _animationController.reverse();
    });
  }

  Future<void> _updateUserAddress(String locationName, LatLng location) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          // Check if the document data is not null
          if (doc.data() != null) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Initialize 'locations' if it doesn't exist
            List<dynamic> locations = data['locations'] as List<dynamic>? ?? [];

            // Check if the location already exists
            int index =
                locations.indexWhere((loc) => loc['name'] == locationName);

            if (index != -1) {
              // Update existing location
              locations[index] = {
                'name': locationName,
                'latitude': location.latitude,
                'longitude': location.longitude,
              };
            } else {
              // Add new location
              locations.add({
                'name': locationName,
                'latitude': location.latitude,
                'longitude': location.longitude,
              });
            }

            // Save to Firebase
            await _firestore.collection('users').doc(user.uid).update({
              'locations': locations,
            });

            // Update the local map
            if (mounted) {
              setState(() {
                _nearbyLocations[locationName] = location;
              });
            }

            _showCustomSnackBar('Location updated successfully!');
          } else {
            // Handle the case where document data is null
            _showCustomSnackBar('Document data is null.', isError: true);
          }
        } else {
          // Handle the case where the document does not exist
          _showCustomSnackBar('User document does not exist.', isError: true);
        }
      } catch (e) {
        // Handle any other errors
        _showCustomSnackBar('Failed to update location: $e', isError: true);
      }
    }
  }

  Future<void> _showAddressSelectionDialog(String locationName) async {
    LatLng? selectedLocation;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select $locationName Location'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : const LatLng(20.2961, 85.8245),
                    initialZoom: 15,
                    onTap: (tapPosition, point) {
                      setState(() {
                        selectedLocation =
                            point; // Update the selected location
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    if (selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedLocation != null) {
                      _updateUserAddress(locationName, selectedLocation!);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select a location')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🚶‍♀️ SafePath Navigation',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 6,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20, bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar and Autocomplete Suggestions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter your destination…',
                      hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _onSearch,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 20),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
              ),
              if (_autocompleteSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _autocompleteSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _autocompleteSuggestions[index];
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            suggestion['name'] as String,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          subtitle: Text(
                            suggestion['source'] == 'predefined'
                                ? 'Predefined Location'
                                : 'Found via Search',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          onTap: () {
                            setState(() {
                              _searchController.text =
                                  suggestion['name'] as String;
                              _autocompleteSuggestions.clear();
                            });
                            _setDestination(
                              suggestion['name'] as String,
                              LatLng(suggestion['lat'] as double,
                                  suggestion['lon'] as double),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildShortcutCard('🏠 Home', 'Go Home', Icons.home),
                      const SizedBox(width: 10),
                      _buildShortcutCard('💼 Work', 'Go to Work', Icons.work),
                      const SizedBox(width: 10),
                      _buildShortcutCard(
                          '🚔 Police', 'Nearest Police', Icons.local_police),
                      const SizedBox(width: 10),
                      _buildShortcutCard('🏥 Hospital', 'Nearest Hospital',
                          Icons.local_hospital),
                      const SizedBox(width: 10),
                      _buildShortcutCard(
                          '🛑 Shelter', 'Safe Zone', Icons.shield),
                      const SizedBox(width: 10),
                      _buildShortcutCard(
                          '📚 Library', 'Go to Library', Icons.local_library),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 450,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ))
                          : _hasError
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Unable to load map. Please try again.',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF6A0DAD),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: _retry,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              : FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _currentPosition != null
                                        ? LatLng(_currentPosition!.latitude,
                                            _currentPosition!.longitude)
                                        : const LatLng(20.2961, 85.8245),
                                    initialZoom: 15,
                                    maxZoom: 18,
                                    minZoom: 5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                      userAgentPackageName: 'com.example.app',
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _safeRoutePoints,
                                          color: Colors.green,
                                          strokeWidth: 6,
                                          borderStrokeWidth: 2,
                                          borderColor: Colors.white,
                                        ),
                                        Polyline(
                                          points: _pathPoints,
                                          color: Colors.blue,
                                          strokeWidth: 4,
                                          strokeCap: StrokeCap.round,
                                          borderColor: Colors.transparent,
                                        ),
                                      ],
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _unsafeRoutePoints,
                                          color: Colors.red,
                                          strokeWidth: 6,
                                          borderStrokeWidth: 2,
                                          borderColor: Colors.white,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        if (_currentPosition != null)
                                          Marker(
                                            point: LatLng(
                                                _currentPosition!.latitude,
                                                _currentPosition!.longitude),
                                            width: 40,
                                            height: 40,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.blue,
                                              size: 40,
                                            ),
                                          ),
                                        if (_selectedDestination.isNotEmpty)
                                          Marker(
                                            point: _safeRoutePoints.isNotEmpty
                                                ? _safeRoutePoints.last
                                                : (_nearbyLocations.containsKey(
                                                        _selectedDestination)
                                                    ? _nearbyLocations[
                                                        _selectedDestination]!
                                                    : LatLng(20.2961, 85.8245)),
                                            width: 40,
                                            height: 40,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.green,
                                              size: 40,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          '© OpenStreetMap contributors',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Column(
                          children: [
                            Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF6A0DAD),
                                      Color(0xFF003366)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: _zoomIn,
                                  icon: const Icon(Icons.add,
                                      color: Colors.white),
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF6A0DAD),
                                      Color(0xFF003366)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: _zoomOut,
                                  icon: const Icon(Icons.remove,
                                      color: Colors.white),
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_safeRoutePoints.isNotEmpty) ...[
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distance: ${_estimatedDistance.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'ETA: $_estimatedTime min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: _triggerSOS,
        onLongPress: _triggerLongPressSOS,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                shadowColor: Colors.black.withOpacity(0.3),
                child: Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: FloatingActionButton.extended(
                    onPressed: null,
                    backgroundColor: Colors.red[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    label: const Text(
                      '🆘 SOS Emergency 🆘',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    icon: const Icon(Icons.emergency,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildShortcutCard(String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () {
        String destination = title.split(' ')[1];
        if (_nearbyLocations.containsKey(destination)) {
          _setDestination(destination, _nearbyLocations[destination]!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please long press to add $destination address'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      onLongPress: () {
        String locationName = title.split(' ')[1];
        _showAddressSelectionDialog(locationName);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: Colors.white),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
