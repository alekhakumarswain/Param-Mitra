import 'package:flutter/material.dart';
import 'dart:async';

class FakeCall extends StatefulWidget {
  @override
  _FakeCallState createState() => _FakeCallState();
}

class _FakeCallState extends State<FakeCall>
    with SingleTickerProviderStateMixin {
  bool _isRinging = true;
  bool _callActive = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _callTimer;
  int _seconds = 0;
  String _callerName = "John Doe";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _acceptCall() {
    setState(() {
      _isRinging = false;
      _callActive = true;
      _animationController.stop();
    });
    _startCallTimer();
  }

  void _endCall() {
    setState(() {
      _isRinging = false;
      _callActive = false;
    });
    _callTimer?.cancel();
    _animationController.stop();
    Navigator.pop(context); // Return to previous screen
  }

  @override
  void dispose() {
    _animationController.dispose();
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Caller Info Section
            Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  ScaleTransition(
                    scale:
                        _isRinging ? _animation : AlwaysStoppedAnimation(1.0),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        'https://via.placeholder.com/150',
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _callerName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _callActive ? _formatTime(_seconds) : 'Mobile',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Call Controls
            Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _isRinging
                    ? [
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onTap: _endCall,
                        ),
                        _buildCallButton(
                          icon: Icons.call,
                          color: Colors.green,
                          onTap: _acceptCall,
                        ),
                      ]
                    : [
                        _buildCallButton(
                          icon: Icons.mic_off,
                          color: Colors.grey,
                          onTap: () {},
                        ),
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onTap: _endCall,
                        ),
                        _buildCallButton(
                          icon: Icons.volume_up,
                          color: Colors.grey,
                          onTap: () {},
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

// To use this widget, call it from your main.dart or any other widget:
void main() {
  runApp(MaterialApp(
    home: FakeCall(),
  ));
}
