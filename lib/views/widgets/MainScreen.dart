import 'package:flutter/material.dart';
import '../pages/safepath_screen.dart';
import '../pages/community_screen.dart';
import '../pages/home_screen.dart';
import '../pages/ai_safety_companion_screen.dart';
import '../pages/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // Set Home as Default Screen

  // List of screens to display
  final List<Widget> _screens = [
    const SafePathScreen(),
    const CommunityScreen(),
    const HomeScreen(),
    const ChatScreen(title: 'Suusri - Your Param Mitra'),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 115,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF6A0DAD),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
            ),
            iconSize: 30,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.directions),
                label: "SafePath",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: "Community",
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A0DAD),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.home_filled,
                      color: Colors.white, size: 35),
                ),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat),
                label: "AI Assistant",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
