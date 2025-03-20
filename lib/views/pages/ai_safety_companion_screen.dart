import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final String _apiKey = String.fromEnvironment('Gemini_API_KEY',
    defaultValue: dotenv.env['Gemini_API_KEY'] ?? '');

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A0DAD), Color(0xFF003366)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ChatWidget(apiKey: _apiKey),
      ),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<({Image? image, String? text, bool fromUser})> _generatedContent =
      <({Image? image, String? text, bool fromUser})>[];
  bool _loading = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  bool isListening = false;
  bool isSpeaking = false;
  String? userName; // Will store the first name fetched from Firebase
  Map<String, dynamic>? _userData; // To store fetched user data
  bool _isLoading = true; // Loading state for user data

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.apiKey.isEmpty) {
      _addMessage("मुझे API की नहीं मिली! ऐप ठीक से काम नहीं करेगा...", false);
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat();
    _initializeSpeech();
    _initializeTts();
    _fetchUserData(); // Fetch user data from Firebase
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
            // Extract the first name from the full name
            String fullName = _userData?['name'] ?? 'यूज़र';
            userName = fullName.split(' ').first; // Use only the first name
            _isLoading = false;
          });
          _sendWelcomeMessage(); // Send welcome message after data is loaded
        } else {
          if (mounted) {
            _showCustomSnackBar(
                'यूज़र डेटा नहीं मिला। डिफ़ॉल्ट सेटिंग्स का उपयोग कर रहा हूँ।',
                isError: true);
          }
          setState(() {
            userName = 'यूज़र';
            _isLoading = false;
          });
          _sendWelcomeMessage();
        }
      } else {
        if (mounted) {
          _showCustomSnackBar(
              'यूज़र प्रमाणित नहीं है। कृपया फिर से लॉगिन करें।',
              isError: true);
          setState(() {
            _isLoading = false;
          });
          Navigator.pushReplacementNamed(context, '/signup-login');
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('यूज़र डेटा लाने में विफल: $e', isError: true);
        setState(() {
          userName = 'यूज़र';
          _isLoading = false;
        });
        _sendWelcomeMessage(); // Proceed with default even if error occurs
      }
    }
  }

  void _initializeSpeech() async {
    bool initialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'error' && mounted) {
          setState(() => isListening = false);
          _addMessage(
              "क्षमा करें, $userName! मुझे आपकी बात समझ नहीं आई, कृपया फिर से बोलें...",
              false);
          _speakText(
              "क्षमा करें, $userName! मुझे समझ नहीं आया, कृपया फिर से बोलें...");
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => isListening = false);
          _addMessage(
              "क्षमा करें, $userName! मुझे आपकी बात समझ नहीं आई, कृपया फिर से बोलें...",
              false);
          _speakText(
              "क्षमा करें, $userName! मुझे समझ नहीं आया, कृपया फिर से बोलें...");
        }
      },
    );

    if (!initialized && mounted) {
      _showCustomSnackBar('स्पीच सेटअप विफल।', isError: true);
    }
  }

  void _initializeTts() async {
    try {
      await flutterTts.setLanguage("hi-IN");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.2);
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('वॉइस सेटअप विफल: $e', isError: true);
      }
    }
  }

  void _sendWelcomeMessage() {
    if (!mounted) return;

    final welcomeText =
        "स्वागत है, $userName! मैं हूँ सुसरी, तेरा परम मित्र। बोल ना, क्या मदद चाहिए? मैं तेरी सेफ्टी के लिए हमेशा तैयार हूँ!";
    _addMessage(welcomeText, false);
    _speakText(
        "स्वागत है, $userName! मैं हूँ सुसरी, तेरा परम मित्र। बोल ना, क्या मदद चाहिए? मैं तेरी सेफ्टी के लिए हमेशा तैयार हूँ!");
  }

  void _scrollDown() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  void _addMessage(String? text, bool fromUser) {
    if (!mounted) return;
    setState(() {
      _generatedContent.add((image: null, text: text, fromUser: fromUser));
      _scrollDown();
    });
  }

  String? _redirectToFeature(String input) {
    final lowerInput = input.toLowerCase();
    if (lowerInput.contains("safepath") ||
        lowerInput.contains("safe route") ||
        lowerInput.contains("navigation")) {
      return "/safepath";
    } else if (lowerInput.contains("community")) {
      return "/community";
    } else if (lowerInput.contains("home")) {
      return "/home";
    } else if (lowerInput.contains("ai assistant") ||
        lowerInput.contains("ai-assistant")) {
      return "/ai-assistant";
    } else if (lowerInput.contains("profile")) {
      return "/profile";
    }
    return null;
  }

  Future<void> _speakText(String text, [int retryCount = 0]) async {
    if (!mounted) return;

    if (isSpeaking) {
      await flutterTts.stop();
      if (mounted) setState(() => isSpeaking = false);
    }

    try {
      if (mounted) setState(() => isSpeaking = true);
      await flutterTts.speak(text);
      flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => isSpeaking = false);
      });
    } catch (e) {
      if (mounted) setState(() => isSpeaking = false);
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 1));
        _speakText(text, retryCount + 1);
      } else if (mounted) {
        _showCustomSnackBar('वॉइस में त्रुटि: $e', isError: true);
      }
    }
  }

  void _startListening() {
    if (!_speech.isListening && _speech.isAvailable && mounted) {
      setState(() => isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
              isListening = false;
            });
            _sendChatMessage(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
      _speakText("सुन रही हूँ, $userName! बोल ना...");
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  Future<void> _updateUserData(String field, String value) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          field: value,
        });
        setState(() {
          _userData?[field] = value;
          if (field == 'name') {
            userName =
                value.split(' ').first; // Update first name if name changes
          }
        });
        if (mounted) {
          _showCustomSnackBar('डेटा अपडेट हो गया!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('डेटा अपडेट करने में विफल: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final InputDecoration textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'यहाँ मैसेज टाइप करें...',
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: widget.apiKey.isNotEmpty
                ? ListView.builder(
                    controller: _scrollController,
                    itemBuilder: (context, idx) {
                      final content = _generatedContent[idx];
                      return MessageWidget(
                        text: content.text,
                        image: content.image,
                        isFromUser: content.fromUser,
                      );
                    },
                    itemCount: _generatedContent.length,
                  )
                : ListView(
                    children: const [
                      Text(
                        'कोई API की नहीं मिली। कृपया API_KEY डिक्लेरेशन सेट करने के लिए '
                        "'--dart-define' का उपयोग करके API की प्रदान करें।",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    focusNode: _textFieldFocus,
                    decoration: textFieldDecoration,
                    controller: _textController,
                    onSubmitted: _sendChatMessage,
                  ),
                ),
                const SizedBox.square(dimension: 15),
                IconButton(
                  onPressed: _loading ? null : () => _startListening(),
                  icon: Icon(
                    isListening ? Icons.mic_off : Icons.mic,
                    color: _loading
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _sendChatMessage(_textController.text);
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.isEmpty || !mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      _addMessage(message, true);
      final redirectPath = _redirectToFeature(message);
      if (redirectPath != null) {
        final pageName = redirectPath == '/safepath'
            ? 'सेफपाथ'
            : redirectPath == '/community'
                ? 'कम्युनिटी'
                : redirectPath == '/home'
                    ? 'होम'
                    : redirectPath == '/ai-assistant'
                        ? 'एआई असिस्टेंट'
                        : 'प्रोफाइल';
        final responseText =
            "$userName, मैं तुझे $pageName पेज पर ले जाती हूँ! एक सेकंड रुको...";
        _addMessage(responseText, false);
        _speakText(
            "$userName, मैं तुझे $pageName पेज पर ले जाती हूँ! एक सेकंड रुको...");
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pushNamed(context, '/main');
      } else if (message.trim().toLowerCase() == "help help help") {
        final concernMessage =
            "$userName, लगता है कुछ सीरियस है! मैं तीसरी बार एक्सीडेंट अलर्ट भेज रही हूँ...";
        _addMessage(concernMessage, false);
        for (int i = 0; i < 3; i++) {
          await Future.delayed(Duration(seconds: i * 2));
        }
        _speakText("क्या हुआ, $userName? सब ठीक है ना?");
      } else if (message.toLowerCase().contains("emergency contact") ||
          message.toLowerCase().contains("mere emergency contact")) {
        // Handle emergency contact query
        if (_userData != null && _userData!.containsKey('emergencyContacts')) {
          List<dynamic> emergencyContacts =
              _userData!['emergencyContacts'] ?? [];
          if (emergencyContacts.isEmpty) {
            final responseText =
                "$userName, अभी तक आपने कोई इमरजेंसी कॉन्टैक्ट ऐड नहीं किया है। प्रोफाइल सेक्शन में जाकर अपने इमरजेंसी कॉन्टैक्ट्स ऐड करो, ताकि मैं आपकी मदद कर सकूं जब ज़रूरत हो! 😊";
            _addMessage(responseText, false);
            _speakText(
                "$userName, अभी तक आपने कोई इमरजेंसी कॉन्टैक्ट ऐड नहीं किया है। प्रोफाइल सेक्शन में जाकर अपने इमरजेंसी कॉन्टैक्ट्स ऐड करो, ताकि मैं आपकी मदद कर सकूं जब ज़रूरत हो!");
          } else {
            String contactList = emergencyContacts
                .asMap()
                .entries
                .map((entry) =>
                    "${entry.key + 1}. ${entry.value['name']} - ${entry.value['number']}")
                .join("\n");
            final responseText =
                "ये रहे आपके इमरजेंसी कॉन्टैक्ट्स, $userName:\n$contactList\nअगर आप इन्हें अपडेट करना चाहते हो, तो प्रोफाइल सेक्शन में जाकर चेंजेस कर सकते हो! 😊";
            _addMessage(responseText, false);
            _speakText(
                "ये रहे आपके इमरजेंसी कॉन्टैक्ट्स, $userName: $contactList। अगर आप इन्हें अपडेट करना चाहते हो, तो प्रोफाइल सेक्शन में जाकर चेंजेस कर सकते हो!");
          }
        } else {
          final responseText =
              "क्षमा करें, $userName! मुझे आपके इमरजेंसी कॉन्टैक्ट्स लाने में थोड़ी दिक्कत हो रही है। क्या आप प्रोफाइल सेक्शन में जाकर चेक कर सकते हो? 😅";
          _addMessage(responseText, false);
          _speakText(
              "क्षमा करें, $userName! मुझे आपके इमरजेंसी कॉन्टैक्ट्स लाने में थोड़ी दिक्कत हो रही है। क्या आप प्रोफाइल सेक्शन में जाकर चेक कर सकते हो?");
        }
      } else if (message.toLowerCase().contains("mere bare me") ||
          message.toLowerCase().contains("tum mere bare me kya janti ho")) {
        // Handle "What do you know about me?" query
        if (_userData != null) {
          final name = _userData!['name'] ?? 'नाम उपलब्ध नहीं';
          final email = _userData!['email'] ?? 'ईमेल उपलब्ध नहीं';
          final mobile = _userData!['mobile'] ?? 'मोबाइल नंबर उपलब्ध नहीं';
          final dob = _userData!['dob'] ?? 'जन्म तिथि उपलब्ध नहीं';
          final gender = _userData!['gender'] ?? 'जेंडर उपलब्ध नहीं';
          final responseText =
              "मैं आपके बारे में ये जानती हूँ, $userName:\n- नाम: $name\n- ईमेल: $email\n- मोबाइल नंबर: $mobile\n- जन्म तिथि: $dob\n- जेंडर: $gender\nअगर आप इसमें कुछ बदलाव करना चाहते हो, तो मुझे बता सकते हो, मैं आपकी डिटेल्स अपडेट कर दूँगी! 😊";
          _addMessage(responseText, false);
          _speakText(
              "मैं आपके बारे में ये जानती हूँ, $userName: नाम $name, ईमेल $email, मोबाइल नंबर $mobile, जन्म तिथि $dob, जेंडर $gender। अगर आप इसमें कुछ बदलाव करना चाहते हो, तो मुझे बता सकते हो, मैं आपकी डिटेल्स अपडेट कर दूँगी!");
        } else {
          final responseText =
              "क्षमा करें, $userName! मुझे आपकी डिटेल्स लाने में थोड़ी दिक्कत हो रही है। क्या आप प्रोफाइल सेक्शन में जाकर चेक कर सकते हो? 😅";
          _addMessage(responseText, false);
          _speakText(
              "क्षमा करें, $userName! मुझे आपकी डिटेल्स लाने में थोड़ी दिक्कत हो रही है। क्या आप प्रोफाइल सेक्शन में जाकर चेक कर सकते हो?");
        }
      } else if (message.toLowerCase().contains("update my name") ||
          message.toLowerCase().contains("mera naam change karo")) {
        // Handle request to update name
        final newName = message
            .replaceAll(
                RegExp('update my name|mera naam change karo',
                    caseSensitive: false),
                '')
            .trim();
        if (newName.isNotEmpty) {
          await _updateUserData('name', newName);
          final responseText =
              "हो गया, $userName! आपका नाम अब $newName है। और कुछ बदलना है? 😊";
          _addMessage(responseText, false);
          _speakText(
              "हो गया, $userName! आपका नाम अब $newName है। और कुछ बदलना है?");
        } else {
          final responseText =
              "$userName, कृपया मुझे बताओ कि आपका नया नाम क्या होना चाहिए। उदाहरण: 'मेरा नाम change करो नया_नाम' 😊";
          _addMessage(responseText, false);
          _speakText(
              "$userName, कृपया मुझे बताओ कि आपका नया नाम क्या होना चाहिए। उदाहरण: मेरा नाम change करो नया_नाम");
        }
      } else if (message.toLowerCase().contains("update my email") ||
          message.toLowerCase().contains("mera email change karo")) {
        // Handle request to update email
        final newEmail = message
            .replaceAll(
                RegExp('update my email|mera email change karo',
                    caseSensitive: false),
                '')
            .trim();
        if (newEmail.isNotEmpty) {
          await _updateUserData('email', newEmail);
          final responseText =
              "हो गया, $userName! आपका ईमेल अब $newEmail है। और कुछ बदलना है? 😊";
          _addMessage(responseText, false);
          _speakText(
              "हो गया, $userName! आपका ईमेल अब $newEmail है। और कुछ बदलना है?");
        } else {
          final responseText =
              "$userName, कृपया मुझे बताओ कि आपका नया ईमेल क्या होना चाहिए। उदाहरण: 'मेरा ईमेल change करो नया_ईमेल' 😊";
          _addMessage(responseText, false);
          _speakText(
              "$userName, कृपया मुझे बताओ कि आपका नया ईमेल क्या होना चाहिए। उदाहरण: मेरा ईमेल change करो नया_ईमेल");
        }
      } else if (message.toLowerCase().contains("update my mobile") ||
          message.toLowerCase().contains("mera mobile change karo")) {
        // Handle request to update mobile
        final newMobile = message
            .replaceAll(
                RegExp('update my mobile|mera mobile change karo',
                    caseSensitive: false),
                '')
            .trim();
        if (newMobile.isNotEmpty) {
          await _updateUserData('mobile', newMobile);
          final responseText =
              "हो गया, $userName! आपका मोबाइल नंबर अब $newMobile है। और कुछ बदलना है? 😊";
          _addMessage(responseText, false);
          _speakText(
              "हो गया, $userName! आपका मोबाइल नंबर अब $newMobile है। और कुछ बदलना है?");
        } else {
          final responseText =
              "$userName, कृपया मुझे बताओ कि आपका नया मोबाइल नंबर क्या होना चाहिए। उदाहरण: 'मेरा मोबाइल change करो नया_नंबर' 😊";
          _addMessage(responseText, false);
          _speakText(
              "$userName, कृपया मुझे बताओ कि आपका नया मोबाइल नंबर क्या होना चाहिए। उदाहरण: मेरा मोबाइल change करो नया_नंबर");
        }
      } else if (message.toLowerCase().contains("update my dob") ||
          message.toLowerCase().contains("meri dob change karo") ||
          message.toLowerCase().contains("dob ko")) {
        // Handle request to update date of birth
        final newDobMatch = RegExp(
                r'\d{1,2}\s*(?:january|february|march|april|may|june|july|august|september|october|november|december|\d{1,2})\s*\d{4}',
                caseSensitive: false)
            .firstMatch(message);
        if (newDobMatch != null) {
          final newDob = newDobMatch.group(0)!;
          await _updateUserData('dob', newDob);
          final responseText =
              "हो गया, $userName! आपकी जन्म तिथि अब $newDob है। और कुछ बदलना है? 😊";
          _addMessage(responseText, false);
          _speakText(
              "हो गया, $userName! आपकी जन्म तिथि अब $newDob है। और कुछ बदलना है?");
        } else {
          final responseText =
              "$userName, कृपया मुझे बताओ कि आपकी नई जन्म तिथि क्या होनी चाहिए। उदाहरण: 'मेरी dob change करो 20 April 2003' 😊";
          _addMessage(responseText, false);
          _speakText(
              "$userName, कृपया मुझे बताओ कि आपकी नई जन्म तिथि क्या होनी चाहिए। उदाहरण: मेरी dob change करो 20 April 2003");
        }
      } else if (message.toLowerCase().contains("app ke sections") ||
          message.toLowerCase().contains("sections ke bare me batao")) {
        // Handle query about app sections
        final responseText =
            "$userName, इस ऐप में 5 सेक्शन्स हैं: सेफपाथ, कम्युनिटी, होम, एआई असिस्टेंट, और प्रोफाइल। किसी खास सेक्शन में जाना चाहते हो? 😊";
        _addMessage(responseText, false);
        _speakText(
            "$userName, इस ऐप में 5 सेक्शन्स हैं: सेफपाथ, कम्युनिटी, होम, एआई असिस्टेंट, और प्रोफाइल। किसी खास सेक्शन में जाना चाहते हो?");
      } else {
        // Forward to Gemini for other queries
        const systemMessage = """
          एक सुरक्षात्मक और दोस्ताना साथी, "परम मित्र" की तरह व्यवहार करें, जो:
          1. एक गर्मजोशी भरे स्वागत संदेश के साथ शुरू करता है
          2. यूज़र की भाषा को स्वचालित रूप से पहचानता है (हिंदी/हिंग्लिश)
          3. उसी भाषा में उचित स्क्रिप्ट के साथ जवाब देता है
          4. एक सुरक्षात्मक लेकिन दोस्ताना लहजा बनाए रखता है
          5. सेफ्टी टिप्स, इमरजेंसी गाइडेंस, और नेविगेशन सपोर्ट प्रदान करता है
          6. सेफ्टी से संबंधित और कैज़ुअल बातचीत दोनों को संभालता है
          
          विशेष मामले:
          - जब पूछा जाए "तुम्हें कौन बनाया है" तो हिंदी में जवाब दें: "मुझे लॉजिकलूम टीम ने बनाया है 🧑💻"
          - जब क्रिएटर/डेवलपर के बारे में पूछा जाए, तो यूज़र की भाषा में जवाब दें
          - कैज़ुअल अभिवादन के लिए, यूज़र की भाषा में गर्मजोशी से जवाब दें
          7. मिश्रित भाषा इनपुट के प्रति सहिष्णु रहें
          
          निर्देश:
          - सेफ्टी, सुरक्षा, और मार्गदर्शन पर ध्यान दें।
          - सुरक्षित रास्ते ढूंढने, इमरजेंसी सर्विसेज से संपर्क करने, या सेल्फ-डिफेंस टिप्स देने जैसे कार्य सुझाएं।
          - यूज़र की डिटेल्स (जैसे नाम, ईमेल, मोबाइल) नहीं बताएं जब तक कि यूज़र स्पष्ट रूप से न पूछे।
        """;
        const languageInstruction =
            "इस मैसेज के लिए विशेष रूप से हिंदी में जवाब दें। किसी अन्य भाषा का मिश्रण न करें जब तक कि यूज़र स्पष्ट रूप से भाषा बदलने का अनुरोध न करे।";
        final content = Content.text(
            '$systemMessage\n\n$languageInstruction\nUser: $message');
        final response = await _chat.sendMessage(content);
        final text = response.text;
        _addMessage(text, false);

        if (text != null) {
          _speakText(text);
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('त्रुटि: $e', isError: true);
        _addMessage(
            "क्षमा करें, $userName! मुझे समझ नहीं आया, कृपया फिर से बोलें... 😅",
            false);
        _speakText(
            "क्षमा करें, $userName! मुझे समझ नहीं आया, कृपया फिर से बोलें...");
      }
    } finally {
      if (mounted) {
        _textController.clear();
        setState(() {
          _loading = false;
        });
        _textFieldFocus.requestFocus();
      }
    }
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    required this.isFromUser,
  });

  final Image? image;
  final String? text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: isFromUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null) MarkdownBody(data: text!),
                if (image != null) image!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
