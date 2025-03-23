import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late GenerativeModel _model;
  late ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<({String? text, bool fromUser})> _generatedContent = [];
  bool _loading = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _userName;
  String? _userId; // To store and log the user ID
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables to store fetched configurations
  Map<String, dynamic>? _geminiConfig;
  Map<String, dynamic>? _mitraConfig;
  String? _systemMessage;
  String _currentLanguage = 'hindi'; // Default communication language
  String? _defaultLanguage;

  // Animation controller for UI effects
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  bool _isAnimationControllerDisposed = false; // Custom flag to track disposal

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _fetchAppConfig().then((_) {
      _initializeSpeech();
      _initializeTts();
      _fetchUserData();
    });
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeIn,
    );
    _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _isAnimationControllerDisposed = true; // Set the flag when disposed
    _scrollController.dispose();
    _textController.dispose();
    _textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchAppConfig() async {
    try {
      // Fetch GeminiAPI config
      DocumentSnapshot geminiDoc =
          await _firestore.collection('appConfig').doc('GeminiAPI').get();
      if (geminiDoc.exists) {
        _geminiConfig = geminiDoc.data() as Map<String, dynamic>;
        String apiKey = _geminiConfig?['apiKeys']['Gemini_API_KEY'] ?? '';
        if (apiKey.isEmpty) {
          _addMessage("API key सर्वर कॉन्फ़िगरेशन में नहीं है।", false);
          return;
        }
        _model = GenerativeModel(
            model: _geminiConfig?['model'] ?? 'gemini-1.5-flash-latest',
            apiKey: apiKey);
        _chat = _model.startChat();
      } else {
        _addMessage("GeminiAPI कॉन्फ़िगरेशन नहीं मिला।", false);
        return;
      }

      // Fetch mitraConfig
      DocumentSnapshot mitraDoc =
          await _firestore.collection('appConfig').doc('mitraConfig').get();
      if (mitraDoc.exists) {
        _mitraConfig = mitraDoc.data() as Map<String, dynamic>;
      } else {
        _addMessage("mitraConfig कॉन्फ़िगरेशन नहीं मिला।", false);
      }
    } catch (e) {
      _addMessage("ऐप कॉन्फ़िगरेशन लाने में विफल: $e", false);
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid; // Store the user ID
        debugPrint(
            "Logged in user ID: $_userId"); // Log the user ID for debugging

        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>;
            String fullName = _userData?['name'] ??
                'User'; // Fetch name directly from 'name' field
            _userName = fullName.split(' ').first;
            _defaultLanguage = 'hinglish'; // Default detection language
            _isLoading = false;
          });
          _sendWelcomeMessage();
        } else {
          _showCustomSnackBar(
              'यूज़र डेटा नहीं मिला। डिफ़ॉल्ट सेटिंग्स का उपयोग कर रहा हूँ।',
              true);
          setState(() {
            _userName = 'User';
            _defaultLanguage = 'hinglish';
            _isLoading = false;
          });
          _sendWelcomeMessage();
        }
      } else {
        _showCustomSnackBar(
            'यूज़र प्रमाणित नहीं है। कृपया फिर से लॉगिन करें।', true);
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacementNamed(context, '/signup-login');
      }
    } catch (e) {
      _showCustomSnackBar('यूज़र डेटा लाने में विफल: $e', true);
      setState(() {
        _userName = 'User';
        _defaultLanguage = 'hinglish';
        _isLoading = false;
      });
      _sendWelcomeMessage();
    }
  }

  void _initializeSpeech() async {
    bool initialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'error') {
          setState(() => _isListening = false);
          String errorMessage = _mitraConfig?['responseTemplates']
                      ?['errorMessage']
                  ?.replaceAll('[name]', _userName ?? 'User') ??
              "क्षमा करें, $_userName। मुझे समझ नहीं आया, कृपया फिर से बोलें।";
          _addMessage(errorMessage, false);
          _speakText(errorMessage);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        String errorMessage = _mitraConfig?['responseTemplates']
                    ?['errorMessage']
                ?.replaceAll('[name]', _userName ?? 'User') ??
            "क्षमा करें, $_userName। मुझे समझ नहीं आया, कृपया फिर से बोलें।";
        _addMessage(errorMessage, false);
        _speakText(errorMessage);
      },
    );

    if (!initialized) {
      _showCustomSnackBar('स्पीच सेटअप विफल।', true);
    }
  }

  void _initializeTts() async {
    try {
      await _flutterTts.setLanguage(_geminiConfig?['setLanguage'] ?? 'hi-IN');
      await _flutterTts.setSpeechRate(
          double.parse(_geminiConfig?['setSpeechRate']?.toString() ?? '0.5'));
      await _flutterTts.setPitch(
          double.parse(_geminiConfig?['setPitch']?.toString() ?? '1.2'));
    } catch (e) {
      _showCustomSnackBar('वॉइस सेटअप विफल: $e', true);
    }
  }

  void _sendWelcomeMessage() {
    String welcomeText = _mitraConfig?['welcomeMessages']?['hi']
            ?.replaceAll('[name]', _userName ?? 'User') ??
        "स्वागत है, $_userName! मैं सुसरी हूँ, आपकी सुरक्षा सहायक। आज मैं आपकी कैसे मदद कर सकती हूँ?";
    _addMessage(welcomeText, false);
    _speakText(welcomeText);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 430),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  void _addMessage(String? text, bool fromUser) {
    setState(() {
      _generatedContent.add((text: text, fromUser: fromUser));
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
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    }

    try {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
      _flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
      });
    } catch (e) {
      setState(() => _isSpeaking = false);
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 1));
        _speakText(text, retryCount + 1);
      } else {
        _showCustomSnackBar('वॉइस त्रुटि: $e', true);
      }
    }
  }

  void _startListening() {
    if (!_speech.isListening && _speech.isAvailable) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            _isListening = false;
          });
          _sendChatMessage(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  void _showCustomSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final InputDecoration textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'यहाँ अपना संदेश टाइप करें',
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    );

    // Debug animation state safely
    debugPrint(
        "AnimationController disposed flag: $_isAnimationControllerDisposed");
    debugPrint("AnimationController status: ${_animationController?.status}");
    debugPrint("FadeAnimation value: ${_fadeAnimation?.value}");

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade800,
        elevation: 8,
        shadowColor: Colors.black45,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade800, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade900, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _animationController != null &&
                _fadeAnimation != null &&
                !_isAnimationControllerDisposed
            ? FadeTransition(
                opacity: _fadeAnimation!,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, idx) {
                          final content = _generatedContent[idx];
                          return MessageWidget(
                            text: content.text,
                            isFromUser: content.fromUser,
                          );
                        },
                        itemCount: _generatedContent.length,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              focusNode: _textFieldFocus,
                              decoration: textFieldDecoration,
                              controller: _textController,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: _sendChatMessage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _loading ? null : _startListening,
                            icon: Icon(
                              _isListening ? Icons.mic_off : Icons.mic,
                              color: _loading ? Colors.grey : Colors.white,
                            ),
                          ),
                          if (!_loading)
                            IconButton(
                              onPressed: () =>
                                  _sendChatMessage(_textController.text),
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                              ),
                            )
                          else
                            const CircularProgressIndicator(),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const Center(
                child:
                    CircularProgressIndicator()), // Fallback if animation fails
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      _addMessage(message, true);

      // Detect the language of the input message
      String detectedLanguage = _detectLanguage(message);
      if (detectedLanguage.isEmpty) {
        detectedLanguage = _defaultLanguage ?? 'hinglish';
      }

      // Handle language change requests
      if (message.toLowerCase().contains("change language to hindi")) {
        _currentLanguage = 'hindi';
        String responseText =
            "ठीक है! अब मैं हिंदी में बात करूँगी। आपकी कैसे मदद करूँ?";
        _addMessage(responseText, false);
        _speakText(responseText);
        await _flutterTts.setLanguage('hi-IN');
      } else if (message.toLowerCase().contains("change language to odia")) {
        _currentLanguage = 'odia';
        String responseText =
            "ଠିକ ଅଛି! ଏବେ ମୁଁ ଓଡ଼ିଆରେ କଥା ହେବି। ତୁମକୁ କିପରି ସାହାଯ୍ୟ କରିବି?";
        _addMessage(responseText, false);
        _speakText(responseText);
        await _flutterTts.setLanguage('or-IN');
      } else if (message
          .toLowerCase()
          .contains("change language to hinglish")) {
        _currentLanguage = 'hinglish';
        String responseText =
            "Theek hai! Ab main Hinglish mein baat karungi. Kaise help karoon?";
        _addMessage(responseText, false);
        _speakText(responseText);
        await _flutterTts.setLanguage('hi-IN');
      } else if (message.toLowerCase().contains("mo name kn") ||
          message.toLowerCase().contains("mera naam kya hai")) {
        if (_userName == 'User') {
          String responseText = _currentLanguage == 'hindi'
              ? "मुझे माफ करना, मैं तुम्हारा नाम नहीं जानता हूँ। तुम मुझे अपना नाम बताना चाहोगे? मैं तुम्हें बेहतर तरीके से जान पाऊँगा और तुम्हारी मदद अच्छे से कर पाऊँगा!"
              : _currentLanguage == 'odia'
                  ? "ମୁଁ କ୍ଷମା ମାଗୁଛି, ମୁଁ ତୁମ ନାମ ଜାଣି ନାହିଁ। ତୁମେ ମୋତେ ତୁମ ନାମ କହିବାକୁ ଚାହିଁବ କି? ମୁଁ ତୁମକୁ ଭଲ ଭାବେ ଜାଣି ପାରିବ ଆଉ ତୁମକୁ ଭଲ ସାହାଯ୍ୟ କରି ପାରିବ!"
                  : "Mujhe maaf karna, main tumhara name nahi jaanta hoon. Tum mujhe apna name batana chahoge? Main tumhe better jaan paunga aur tumhari help acche se kar paunga!";
          _addMessage(responseText, false);
          _speakText(responseText);
        } else {
          String responseText = _currentLanguage == 'hindi'
              ? "तुम्हारा नाम $_userName है।"
              : _currentLanguage == 'odia'
                  ? "ତୁମ ନାମ $_userName ଅଟେ।"
                  : "Tumhara name $_userName hai.";
          _addMessage(responseText, false);
          _speakText(responseText);
        }
      } else if (message.toLowerCase().contains("emergency number")) {
        String responseText = _currentLanguage == 'hindi'
            ? "भारत में आपातकालीन नंबर 112 है। यह नंबर पुलिस, एम्बुलेंस सेवा और एक्सीडेंट सम्बंधी किसी भी तरह की आपातकालीन स्थिति में, शीघ्र राहत और स्पष्ट रूप से बात करना बहुत जरूरी है। आप अपनी लोकेशन भी बताना न भूलें।"
            : _currentLanguage == 'odia'
                ? "ଭାରତରେ ଇମରଜେନ୍ସି ନମ୍ବର 112 ଅଟେ। ଏହି ନମ୍ବର ପୁଲିସ, ଆମ୍ବୁଲାନ୍ସ ସେବା ଏବଂ ଦୁର୍ଘଟଣା ସମ୍ବନ୍ଧୀୟ ଯେକୌଣସି ଇମରଜେନ୍ସି ସ୍ଥିତିରେ, ଶୀଘ୍ର ରାହତ ଏବଂ ସ୍ପଷ୍ଟ ରୂପେ କଥା କହିବା ବହୁତ ଜରୁରୀ। ଆପଣ ଆପଣଙ୍କ ଲୋକେସନ ମଧ୍ୟ କହିବାକୁ ଭୁଲିବେ ନାହିଁ।"
                : "Bharat mein emergency number 112 hai. Yeh number police, ambulance service aur accident sambandhi kisi bhi tarah ki emergency situation mein, jaldi relief aur clear baat karna bahut zaroori hai. Aap apni location bhi batana na bhoolen.";
        _addMessage(responseText, false);
        _speakText(responseText);
      } else if (message
              .toLowerCase()
              .contains("mera emergency contact kya hai") ||
          message.toLowerCase().contains("mere bare me aur kya jante ho")) {
        if (_userData != null && _userData!.containsKey('emergencyContacts')) {
          List<dynamic> emergencyContacts =
              _userData!['emergencyContacts'] ?? [];
          if (emergencyContacts.isEmpty) {
            String responseText = _currentLanguage == 'hindi'
                ? "$_userName, आपने अभी तक कोई इमरजेंसी कॉन्टैक्ट्स नहीं जोड़े हैं। कृपया प्रोफाइल सेक्शन में जोड़ें।"
                : _currentLanguage == 'odia'
                    ? "$_userName, ତୁମେ ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଇମରଜେନ୍ସି କଣ୍ଟାକ୍ଟ ଯୋଡ଼ି ନାହିଁ। ଦୟାକରି ପ୍ରୋଫାଇଲ ସେକ୍ସନରେ ଯୋଡ଼।"
                    : "$_userName, aapne abhi tak koi emergency contacts nahi jode hain. Profile section mein jodo.";
            _addMessage(responseText, false);
            _speakText(responseText);
          } else {
            String contactList = emergencyContacts
                .asMap()
                .entries
                .map((entry) =>
                    "${entry.key + 1}. ${entry.value['name']} - ${entry.value['number']}")
                .join("\n");
            String responseText = _currentLanguage == 'hindi'
                ? "ये रहे आपके इमरजेंसी कॉन्टैक्ट्स, $_userName:\n$contactList\nआप इन्हें प्रोफाइल सेक्शन में अपडेट कर सकते हैं।"
                : _currentLanguage == 'odia'
                    ? "ଏହି ତୁମର ଇମରଜେନ୍ସି କଣ୍ଟାକ୍ଟସ୍, $_userName:\n$contactList\nତୁମେ ଏହାକୁ ପ୍ରୋଫାଇଲ ସେକ୍ସନରେ ଅପଡେଟ କରିପାରିବ।"
                    : "Ye rahe aapke emergency contacts, $_userName:\n$contactList\nAap inhe profile section mein update kar sakte hain.";
            _addMessage(responseText, false);
            _speakText(responseText);
          }
        } else {
          String responseText = _currentLanguage == 'hindi'
              ? "क्षमा करें, $_userName। मुझे आपके इमरजेंसी कॉन्टैक्ट्स नहीं मिले। कृपया प्रोफाइल सेक्शन चेक करें।"
              : _currentLanguage == 'odia'
                  ? "କ୍ଷମା କର, $_userName। ମୁଁ ତୁମର ଇମରଜେନ୍ସି କଣ୍ଟାକ୍ଟସ୍ ପାଇଲି ନାହିଁ। ଦୟାକରି ପ୍ରୋଫାଇଲ ସେକ୍ସନ ଚେକ କର।"
                  : "Sorry, $_userName. Mujhe aapke emergency contacts nahi mile. Profile section check karo.";
          _addMessage(responseText, false);
          _speakText(responseText);
        }

        // Handle "mere bare me aur kya jante ho"
        if (message.toLowerCase().contains("mere bare me aur kya jante ho")) {
          String additionalInfo = _currentLanguage == 'hindi'
              ? "मुझे माफ करना, लेकिन मैं तुम्हारे बारे में और कुछ नहीं जानता। मुझे केवल वही जानकारी दी जाती है, जो तुमने दी है। जैसे तुम्हारे इमरजेंसी कॉन्टैक्ट्स! तुम्हारी प्राइवेसी मेरे लिए बहुत महत्वपूर्ण है। अगर तुम चाहो तो मुझे और जानकारी दे सकते हो, लेकिन यह पूरी तरह से तुम्हारे ऊपर है!"
              : _currentLanguage == 'odia'
                  ? "ମୁଁ କ୍ଷମା ମାଗୁଛି, କିନ୍ତୁ ମୁଁ ତୁମ ବିଷୟରେ ଆଉ କିଛି ଜାଣି ନାହିଁ। ମୋତେ କେବଳ ସେହି ସୂଚନା ଦିଆଯାଇଛି, ଯାହା ତୁମେ ଦେଇଛ। ଯେମିତି ତୁମର ଇମରଜେନ୍ସି କଣ୍ଟାକ୍ଟସ୍! ତୁମର ଗୋପନୀୟତା ମୋ ପାଇଁ ବହୁତ ଗୁରୁତ୍ୱପୂର୍ଣ୍ଣ। ଯଦି ତୁମେ ଚାହୁଁ ତେବେ ମୋତେ ଆଉ ସୂଚନା ଦେଇ ପାରିବ, କିନ୍ତୁ ଏହା ପୁରା ତୁମ ଉପରେ ନିର୍ଭର କରେ!"
                  : "Mujhe maaf karna, lekin main tumhare baare mein aur kuch nahi jaanta. Mujhe sirf wahi information di jaati hai, jo tumne di hai. Jaise tumhare emergency contacts! Tumhari privacy mere liye bahut important hai. Agar tum chaho to mujhe aur information de sakte ho, lekin yeh poori tarah se tumhare upar hai!";
          _addMessage(additionalInfo, false);
          _speakText(additionalInfo);
        }
      } else {
        // Fetch the system message in the current language
        Map<String, dynamic> systemMessages =
            _geminiConfig?['systemMessages'] ?? {};
        _systemMessage = systemMessages[_currentLanguage] ??
            systemMessages['hindi'] ??
            """
            एक सुरक्षात्मक और दोस्ताना साथी, "परम मित्र" की तरह व्यवहार करें, जो:
            1. एक गर्मजोशी भरे स्वागत संदेश के साथ शुरू करता है
            2. यूज़र की भाषा को स्वचालित रूप से पहचानता है (हिंदी/हिंग्लिश)
            3. उसी भाषा में उचित स्क्रिप्ट के साथ जवाब देता है
            4. एक सुरक्षात्मक लेकिन दोस्ताना लहजा बनाए रखता है
            5. सेफ्टी टिप्स, इमरजेंसी गाइडेंस, और नेविगेशन सपोर्ट प्रदान करता है
            6. सेफ्टी से संबंधित और कैज़ुअल बातचीत दोनों को संभालता है
            """;

        // Set TTS language dynamically
        await _flutterTts
            .setLanguage(_currentLanguage == 'odia' ? 'or-IN' : 'hi-IN');

        final redirectPath = _redirectToFeature(message);
        if (redirectPath != null) {
          final pageName = redirectPath.split('/').last;
          String responseText = _mitraConfig?['responseTemplates']
                      ?['redirectMessage']
                  ?.replaceAll('[name]', _userName ?? 'User')
                  ?.replaceAll('[page]', pageName) ??
              "$_userName, मैं तुम्हें $pageName पेज पर ले जाती हूँ। एक सेकंड रुको...";
          _addMessage(responseText, false);
          _speakText(responseText);
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushNamed(context, redirectPath);
        } else if (message.trim().toLowerCase() == "help help help") {
          String concernMessage = _mitraConfig?['responseTemplates']
                      ?['emergencyAlert']
                  ?.replaceAll('[name]', _userName ?? 'User') ??
              "$_userName, ये गंभीर लगता है। मैं एक इमरजेंसी अलर्ट भेज रही हूँ।";
          _addMessage(concernMessage, false);
          for (int i = 0; i < 3; i++) {
            await Future.delayed(Duration(seconds: i * 2));
            Navigator.pushNamed(context, '/accident-alert');
          }
          String followUpMessage = _currentLanguage == 'hindi'
              ? "क्या हुआ, $_userName? सब ठीक है ना?"
              : _currentLanguage == 'odia'
                  ? "କଣ ହେଲା, $_userName? ସବୁ ଠିକ ଅଛି ନା?"
                  : "Kya hua, $_userName? Sab theek hai na?";
          _speakText(followUpMessage);
        } else {
          // Build chat history for context
          String chatHistory = _generatedContent
              .map((msg) => "${msg.fromUser ? 'User' : 'Suusri'}: ${msg.text}")
              .join("\n");

          String languageInstruction =
              "Respond EXCLUSIVELY in $_currentLanguage for this message unless the user explicitly requests a language switch.";
          final content = Content.text(
              '$_systemMessage\n\nChat History:\n$chatHistory\n\n$languageInstruction\nUser: $message');
          final response = await _chat.sendMessage(content);
          final text = response.text;
          _addMessage(text, false);
          if (text != null) _speakText(text);
        }
      }
    } catch (e) {
      _showCustomSnackBar('त्रुटि: $e', true);
      String errorMessage = _mitraConfig?['responseTemplates']?['errorMessage']
              ?.replaceAll('[name]', _userName ?? 'User') ??
          "क्षमा करें, $_userName। मुझे समझ नहीं आया, कृपया फिर से कोशिश करें।";
      _addMessage(errorMessage, false);
      _speakText(errorMessage);
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  String _detectLanguage(String message) {
    // Check for explicit language change requests
    if (message.toLowerCase().contains("change language to")) {
      return '';
    }
    // Check for Hindi characters (Devanagari script)
    if (RegExp(r'[\u0900-\u097F]').hasMatch(message)) {
      return 'hindi';
    }
    // Check for Odia characters
    if (RegExp(r'[\u0B00-\u0B7F]').hasMatch(message)) {
      return 'odia';
    }
    // Default to Hinglish
    return 'hinglish';
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    Key? key,
    this.text,
    required this.isFromUser,
  }) : super(key: key);

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
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFromUser
                    ? [Colors.blue.shade700, Colors.blue.shade500]
                    : [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 12),
            child: text != null
                ? MarkdownBody(
                    data: text!,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
