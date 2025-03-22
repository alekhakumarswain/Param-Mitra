import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

// Rename class to follow Dart naming conventions (lowercase with underscores)
// File should be renamed to 'fake_call.dart'
class FakeCall extends StatefulWidget {
  final String callerName;
  final String? callerImageUrl;

  const FakeCall({
    required this.callerName,
    this.callerImageUrl,
    super.key,
  });

  @override
  State<FakeCall> createState() => _FakeCallState();
}

class _FakeCallState extends State<FakeCall> with TickerProviderStateMixin {
  bool _isRinging = true;
  bool _callActive = false;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _callTimer;
  int _seconds = 0;
  bool _isMuted = false;
  // Create an instance of FlutterRingtonePlayer
  final _ringtonePlayer = FlutterRingtonePlayer();

  // Fixed colors with proper alpha values
  static final _blueTransparent =
      const Color(0xFF2196F3).withAlpha(51); // 0.2 opacity
  static final _blueSemiTransparent =
      const Color(0xFF2196F3).withAlpha(76); // 0.3 opacity
  static final _blueMoreTransparent =
      const Color(0xFF2196F3).withAlpha(127); // 0.5 opacity

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _playRingtone();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  void _playRingtone() {
    _ringtonePlayer.playRingtone(
      // Use instance instead of static access
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  void _acceptCall() {
    setState(() {
      _isRinging = false;
      _callActive = true;
    });
    _ringtonePlayer.stop(); // Use instance instead of static access
    _pulseController.stop();
    _fadeController.stop();
    _startCallTimer();
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);

  void _endCall() {
    _ringtonePlayer.stop(); // Use instance instead of static access
    _callTimer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _pulseController.dispose();
    _fadeController.dispose();
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(seconds: 2),
                top: _isRinging ? -50 : 0,
                child: Container(
                  height: 200,
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [_blueTransparent, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _blueSemiTransparent,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: _blueSemiTransparent,
                              child: Icon(
                                Icons.person,
                                color:
                                    Colors.white.withAlpha(204), // 0.8 opacity
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            widget.callerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: _blueMoreTransparent,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _callActive ? _formatTime(_seconds) : 'Incoming Call',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 80),
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
                                icon: _isMuted ? Icons.mic_off : Icons.mic,
                                color: Colors.blueGrey,
                                onTap: _toggleMute,
                              ),
                              _buildCallButton(
                                icon: Icons.call_end,
                                color: Colors.red,
                                onTap: _endCall,
                              ),
                              _buildCallButton(
                                icon: Icons.volume_up,
                                color: Colors.blueGrey,
                                onTap: () {},
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(102), // 0.4 opacity
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
