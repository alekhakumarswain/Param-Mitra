import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // Sample data for MVP and advanced features
  // ignore: prefer_final_fields
  List<Map<String, String>> _nearbyUsers = [
    {"name": "Volunteer John", "role": "Volunteer", "type": "Helper"},
    {"name": "Officer Sharma", "role": "Police Officer", "type": "Police"},
    {"name": "Priya", "role": "Verified User", "type": "Women"},
  ];
  // ignore: prefer_final_fields
  List<Map<String, dynamic>> _safetyAlerts = [
    {
      "message": "⚠️ Reported: Stalking incident at XYZ Road.",
      "upvotes": 5,
      "downvotes": 1,
      "comments": ["Stay safe, thanks for reporting!"]
    },
    {
      "message": "🚨 Robbery reported near ABC Metro Station.",
      "upvotes": 3,
      "downvotes": 0,
      "comments": ["I saw this too, very dangerous area."]
    },
    {
      "message": "✔️ Safe Zone nearby: Police presence at Mall Road.",
      "upvotes": 7,
      "downvotes": 0,
      "comments": <String>[]
    },
  ];
  // ignore: prefer_final_fields
  List<Map<String, String>> _safeZones = [
    {"name": "Police Station", "distance": "1.2 km", "rating": "4.5"},
    {"name": "City Hospital", "distance": "2.5 km", "rating": "4.8"},
    {"name": "24/7 Cafe", "distance": "0.8 km", "rating": "4.2"},
  ];
  // ignore: prefer_final_fields
  List<Map<String, String>> _discussionPosts = [
    {
      "title": "Safety Tips for Night Travel",
      "content": "Always share your location..."
    },
    {
      "title": "Recent Incident in ABC Area",
      "content": "I faced harassment yesterday..."
    },
  ];
  // ignore: prefer_final_fields
  List<Map<String, dynamic>> _helpRequests = [
    {
      "message": "I'm feeling unsafe at XYZ Road. Can someone help?",
      "user": "Liza",
      "locationShared": true
    },
  ];

  // State variables
  String _selectedFilter = "All";
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _discussionController = TextEditingController();
  final TextEditingController _helpRequestController = TextEditingController();
  bool _shareLocation = false;
  // ignore: prefer_final_fields
  double _safetyScore = 75.0; // Sample safety score (0-100)

  @override
  Widget build(BuildContext context) {
    // Filter nearby users based on selected filter
    List<Map<String, String>> filteredUsers = _selectedFilter == "All"
        ? _nearbyUsers
        : _nearbyUsers
            .where((user) => user["type"] == _selectedFilter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: const Color(0xFF6A0DAD),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI-Powered Personal Safety Score
              const Text(
                "Your Safety Score",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _safetyScore / 100,
                          backgroundColor: Colors.white54,
                          color: _safetyScore > 70 ? Colors.green : Colors.red,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${_safetyScore.toInt()} / 100",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // Nearby Verified Users
              const SizedBox(height: 30),
              const Text(
                "Nearby Trusted Users",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Filter by:",
                    style: TextStyle(color: Colors.white70),
                  ),
                  DropdownButton<String>(
                    value: _selectedFilter,
                    dropdownColor: const Color(0xFF003366),
                    style: const TextStyle(color: Colors.white),
                    underline: Container(
                      height: 2,
                      color: Colors.white,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFilter = newValue!;
                      });
                    },
                    items: <String>['All', 'Police', 'Helper', 'Women']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.white),
                      title: Text(
                        filteredUsers[index]["name"]!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        filteredUsers[index]["role"]!,
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Calling ${filteredUsers[index]["name"]}')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.blue),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Messaging ${filteredUsers[index]["name"]}')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Safety Alerts & Crime Reports
              const SizedBox(height: 30),
              const Text(
                "Safety Alerts",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _safetyAlerts.length,
                itemBuilder: (context, index) {
                  final comments =
                      (_safetyAlerts[index]["comments"] as List<dynamic>)
                          .map((comment) => comment.toString())
                          .toList(); // Convert List<dynamic> to List<String>
                  return Card(
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(
                        _safetyAlerts[index]["message"],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.thumb_up,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            _safetyAlerts[index]["upvotes"].toString(),
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.thumb_down,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            _safetyAlerts[index]["downvotes"].toString(),
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      trailing:
                          const Icon(Icons.comment, color: Colors.white70),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up,
                                        color: Colors.green),
                                    onPressed: () {
                                      setState(() {
                                        _safetyAlerts[index]["upvotes"] =
                                            _safetyAlerts[index]["upvotes"] + 1;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_down,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _safetyAlerts[index]["downvotes"] =
                                            _safetyAlerts[index]["downvotes"] +
                                                1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white54),
                              const Text(
                                "Comments",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              ...comments.map<Widget>((comment) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    comment,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                );
                              }),
                              TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: "Add a comment...",
                                  hintStyle: TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      (_safetyAlerts[index]["comments"]
                                              as List<dynamic>)
                                          .add(value);
                                      _commentController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Report Unsafe Locations
              const SizedBox(height: 30),
              const Text(
                "Report Unsafe Locations",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: null,
                dropdownColor: const Color(0xFF003366),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Select category...",
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: <String>[
                  "No Streetlights",
                  "Frequent Harassment",
                  "Stalking & Suspicious Activity",
                  "Crime Incident"
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  // Placeholder for category selection
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reportController,
                decoration: InputDecoration(
                  hintText: "Describe the unsafe location...",
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _showLocationPickerDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6A0DAD),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Choose Location & Submit"),
              ),

              // Safe Zones Nearby
              const SizedBox(height: 30),
              const Text(
                "Safe Zones Nearby",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _safeZones.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading:
                          const Icon(Icons.location_on, color: Colors.green),
                      title: Text(
                        _safeZones[index]["name"]!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${_safeZones[index]["distance"]!} | Rating: ${_safeZones[index]["rating"]!}",
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.star_border, color: Colors.white),
                        onPressed: () {
                          _showReviewDialog(
                              context, _safeZones[index]["name"]!);
                        },
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Navigating to ${_safeZones[index]["name"]}')),
                        );
                      },
                    ),
                  );
                },
              ),

              // Community Discussion Forum
              const SizedBox(height: 30),
              const Text(
                "Community Discussion Forum",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _discussionPosts.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        _discussionPosts[index]["title"]!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _discussionPosts[index]["content"]!,
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Viewing: ${_discussionPosts[index]["title"]}')),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _discussionController,
                decoration: InputDecoration(
                  hintText: "Start a new discussion...",
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_discussionController.text.isNotEmpty) {
                    setState(() {
                      _discussionPosts.add({
                        "title": "New Discussion",
                        "content": _discussionController.text,
                      });
                      _discussionController.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Discussion posted successfully')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6A0DAD),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Post Discussion"),
              ),

              // Emergency Help Requests
              const SizedBox(height: 30),
              const Text(
                "Emergency Help Requests",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _helpRequests.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        _helpRequests[index]["message"]!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "By: ${_helpRequests[index]["user"]!} | Location: ${_helpRequests[index]["locationShared"]! ? "Shared" : "Not Shared"}",
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.help, color: Colors.red),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Responding to ${_helpRequests[index]["user"]}')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _helpRequestController,
                decoration: InputDecoration(
                  hintText: "Request help (e.g., I'm feeling unsafe at...)...",
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text(
                  "Share Live Location",
                  style: TextStyle(color: Colors.white),
                ),
                value: _shareLocation,
                onChanged: (value) {
                  setState(() {
                    _shareLocation = value;
                  });
                },
                activeColor: Colors.white,
                inactiveTrackColor: Colors.white54,
              ),
              ElevatedButton(
                onPressed: () {
                  if (_helpRequestController.text.isNotEmpty) {
                    setState(() {
                      _helpRequests.add({
                        "message": _helpRequestController.text,
                        "user": "Liza",
                        "locationShared": _shareLocation,
                      });
                      _helpRequestController.clear();
                      _shareLocation = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Help request posted successfully')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6A0DAD),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Request Help"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to show location picker dialog
  void _showLocationPickerDialog(BuildContext context) {
    final TextEditingController locationController = TextEditingController();
    String? selectedLocation;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Location"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search bar for location input
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  hintText: "Search location...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      // Placeholder for location search API (e.g., Google Maps API or OpenStreetMap)
                      // For now, we'll use a simple predefined list of locations
                      setState(() {
                        selectedLocation = locationController.text.isNotEmpty
                            ? locationController.text
                            : null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Dropdown for predefined locations
              DropdownButtonFormField<String>(
                value: selectedLocation,
                hint: const Text("Select a predefined location"),
                items: <String>["XYZ Road", "ABC Metro Station", "Mall Road"]
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedLocation = newValue;
                    locationController.text = newValue ?? '';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (_reportController.text.isNotEmpty &&
                    selectedLocation != null) {
                  setState(() {
                    _safetyAlerts.add({
                      "message":
                          "⚠️ Reported: ${_reportController.text} at $selectedLocation",
                      "upvotes": 0,
                      "downvotes": 0,
                      "comments": <String>[],
                    });
                    _reportController.clear();
                    locationController.clear();
                    selectedLocation = null;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Location reported successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please select a location and add a description')),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  // Method to show review dialog for safe zones
  void _showReviewDialog(BuildContext context, String zoneName) {
    final TextEditingController reviewController = TextEditingController();
    double rating = 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Review $zoneName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  hintText: "Write your review...",
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Rating: "),
                  DropdownButton<double>(
                    value: rating == 0 ? null : rating,
                    hint: const Text("Select rating"),
                    items: [1.0, 2.0, 3.0, 4.0, 5.0]
                        .map<DropdownMenuItem<double>>((double value) {
                      return DropdownMenuItem<double>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (double? newValue) {
                      setState(() {
                        rating = newValue ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (reviewController.text.isNotEmpty && rating > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Review submitted for $zoneName')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please add a review and rating')),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }
}
