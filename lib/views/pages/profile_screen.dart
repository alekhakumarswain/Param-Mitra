import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State variables
  String _name = "Liza";
  String _email = "liza@example.com";
  String _mobile = "+91-9876543210";
  bool _liveLocationToggle = false;
  bool _biometricToggle = false;
  String _selectedLanguage = "English";
  List<Map<String, String>> _emergencyContacts = [
    {"name": "Parent", "number": "+91-1234567890"},
    {"name": "Friend", "number": "+91-0987654321"},
  ];

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section: Profile Picture + User Info
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Placeholder for profile picture upload
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Upload profile picture')),
                          );
                        },
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(Icons.person,
                              size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _email,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _mobile,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Placeholder for editing info
                          _editUserInfo(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6A0DAD),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Edit Info"),
                      ),
                    ],
                  ),
                ),

                // Emergency Contacts Section
                const SizedBox(height: 30),
                const Text(
                  "Emergency Contacts",
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
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: Colors.white.withOpacity(0.2),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.white),
                        title: Text(
                          _emergencyContacts[index]["name"]!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _emergencyContacts[index]["number"]!,
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () {
                                // Placeholder for calling
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Calling emergency contact')),
                                );
                              },
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.message, color: Colors.blue),
                              onPressed: () {
                                // Placeholder for sending SMS with location
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Sending SOS with location')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // Placeholder for adding new contact
                    _addEmergencyContact(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6A0DAD),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Add New Contact"),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text(
                    "Live Location Sharing (SOS)",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _liveLocationToggle,
                  onChanged: (value) {
                    setState(() {
                      _liveLocationToggle = value;
                    });
                  },
                  activeColor: Colors.white,
                  inactiveTrackColor: Colors.white54,
                ),

                // App Settings Section
                const SizedBox(height: 30),
                const Text(
                  "App Settings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white.withOpacity(0.2),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          "Shake Phone for SOS",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: true, // Default enabled
                        onChanged: (value) {
                          // Placeholder for SOS customization
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('SOS shake enabled')),
                          );
                        },
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white54,
                      ),
                      SwitchListTile(
                        title: const Text(
                          "3x Power Button for SOS",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: true, // Default enabled
                        onChanged: (value) {
                          // Placeholder for SOS customization
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('SOS power button enabled')),
                          );
                        },
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white54,
                      ),
                      SwitchListTile(
                        title: const Text(
                          "Voice Activation ('Help me, Param Mitra')",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: true, // Default enabled
                        onChanged: (value) {
                          // Placeholder for SOS customization
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice SOS enabled')),
                          );
                        },
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white.withOpacity(0.2),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          "Safety Alerts",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: true, // Default enabled
                        onChanged: (value) {
                          setState(() {
                            // Placeholder for notification settings
                          });
                        },
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white54,
                      ),
                      SwitchListTile(
                        title: const Text(
                          "Safe Zone Reminders",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: false, // Default disabled
                        onChanged: (value) {
                          setState(() {
                            // Placeholder for notification settings
                          });
                        },
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: const Text(
                    "Language",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF003366),
                    style: const TextStyle(color: Colors.white),
                    underline: Container(
                      height: 2,
                      color: Colors.white,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLanguage = newValue!;
                      });
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

                // Privacy & Security Section
                const SizedBox(height: 30),
                const Text(
                  "Privacy & Security",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text(
                    "Biometric Authentication",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _biometricToggle,
                  onChanged: (value) {
                    setState(() {
                      _biometricToggle = value;
                    });
                  },
                  activeColor: Colors.white,
                  inactiveTrackColor: Colors.white54,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: "Secret SOS PIN",
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  obscureText: true,
                  onSubmitted: (value) {
                    // Placeholder for setting secret SOS PIN
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SOS PIN set silently')),
                    );
                  },
                ),

                // Footer Section: Account Management
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Placeholder for logout
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Logout"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // Placeholder for delete account (with OTP confirmation)
                    _deleteAccount(context);
                  },
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

  void _editUserInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController =
            TextEditingController(text: _name);
        TextEditingController emailController =
            TextEditingController(text: _email);
        TextEditingController mobileController =
            TextEditingController(text: _mobile);
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: "Mobile"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _name = nameController.text;
                  _email = emailController.text;
                  _mobile = mobileController.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _addEmergencyContact(BuildContext context) {
    if (_emergencyContacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 contacts allowed')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();
        TextEditingController numberController = TextEditingController();
        return AlertDialog(
          title: const Text("Add Emergency Contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: "Number"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _emergencyContacts.add({
                    "name": nameController.text,
                    "number": numberController.text,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController otpController = TextEditingController();
        return AlertDialog(
          title: const Text("Delete Account"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter OTP to confirm account deletion"),
              TextField(
                controller: otpController,
                decoration: const InputDecoration(labelText: "OTP"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Placeholder for OTP verification
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted')),
                );
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }
}
