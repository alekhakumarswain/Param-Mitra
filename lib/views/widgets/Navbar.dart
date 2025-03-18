import 'package:flutter/material.dart';
import '../pages/home_screen.dart';
import '../pages/safepath_screen.dart';
import '../pages/community_screen.dart';
import '../pages/ai_safety_companion_screen.dart';
import '../pages/profile_screen.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  _NavbarState createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = 2; // Set Home as Default Screen

  // Map indices to routes
  final List<String> _routes = [
    '/safepath',
    '/community',
    '/home',
    '/ai-assistant',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        height: 70,
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
                Navigator.pushReplacementNamed(context, _routes[index]);
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
