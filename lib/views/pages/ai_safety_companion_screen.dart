import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

const String _apiKey = String.fromEnvironment('Gemini_API_KEY');

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
        child: const ChatWidget(apiKey: _apiKey),
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
  final String userName = "Liza";

  final Map<String, dynamic> mitraConfig = {
    "identity": {
      "name": "Suusri",
      "creator": "LogicLoom Team",
      "gender": "female",
      "language": "Odia",
      "age": 20,
      "location": "India",
      "traits": ["protective", "empathetic", "brave", "playful", "reliable"],
      "capabilities": [
        "Safety tips 🛡️",
        "Emergency guidance 🚨",
        "Navigation assistance 🗺️",
        "Nearby safe zones 🏠",
        "Emergency contact management 📱",
        "Accident alert 🚨",
        "Self-defense advice 💪",
        "Situational awareness tips 👀",
      ],
    },
    "systemMessage": """
      Act as a protective and friendly companion, a "Param Mitra", named Suusri that:
      1. Starts with a warm welcome message in English
      2. Detects user's language automatically (English/Hindi/Odia/Hinglish)
      3. Responds in the same language with appropriate script
      4. Maintains a protective yet friendly tone
      5. Provides safety tips, emergency guidance, and navigation support
      6. Handles both safety-related and casual conversations
      
      Special Cases:
      - When asked "tumhe kon banaya hai" respond in Hindi: "मुझे LogicLoom टीम ने बनाया है 🧑💻"
      - When asked about creator/developer, respond in user's language
      - For casual greetings, respond warmly in user's language
      7. Be tolerant of mixed language inputs
      
      Instructions:
      - Focus on safety, protection, and guidance.
      - Suggest actions like finding safe routes, contacting emergency services, or providing self-defense tips.
      - If the user mentions specific app features (e.g., "safepath", "community", "home", "ai-assistant", "profile"), redirect them to the relevant section of the app by using Navigator.pushNamed.
      - If the user requests a page that doesn't exist in the app (e.g., "police station"), respond with: "Sorry, Liza! Main sirf app ke 5 sections mein redirect kar sakti hoon: SafePath, Community, Home, AI Assistant, aur Profile. Lekin main Gemini se help le sakti hoon!" and then generate a response using Gemini.
      
      Examples:
      User (Hinglish): "Mujhe safepath chahiye"
      Response: "Liza, main tujhe SafePath page pe le jati hoon! Ek second ruko..."
      
      User (Hinglish): "Mujhe police station chahiye"
      Response: "Sorry, Liza! Main sirf app ke 5 sections mein redirect kar sakti hoon: SafePath, Community, Home, AI Assistant, aur Profile. Lekin main Gemini se help le sakti hoon!"
    """,
  };

  @override
  void initState() {
    super.initState();
    if (widget.apiKey.isEmpty) {
      _addMessage(
          "Liza, mujhe API key nahi mila! App thik se kaam nahi karega...",
          false);
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat();
    _initializeSpeech();
    _initializeTts();
    _sendWelcomeMessage();
  }

  void _initializeSpeech() async {
    bool initialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'error') {
          setState(() => isListening = false);
          _addMessage(
              "Oops, Liza! Speech samajh nahi aaya, fir se bolo na...", false);
          _speakText("अरे, Liza! मैं समझी नहीं, फिर एक बार बोलो ना...");
        }
      },
      onError: (error) {
        setState(() => isListening = false);
        _addMessage(
            "Oops, Liza! Speech samajh nahi aaya, fir se bolo na...", false);
        _speakText("अरे, Liza! मैं समझी नहीं, फिर एक बार बोलो ना...");
      },
    );

    if (!initialized) {
      _addMessage("Liza, speech setup mein thodi si dikkat hai...", false);
    }
  }

  void _initializeTts() async {
    try {
      await flutterTts.setLanguage("hi-IN");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.2);
    } catch (e) {
      _addMessage(
          "Oops, Liza! Voice setup mein thodi si dikkat ho gayi...", false);
    }
  }

  void _sendWelcomeMessage() {
    const welcomeText =
        "Welcome, Liza! Main hoon Suusri, tera Param Mitra. Bol na, kya help chahiye? Main teri safety ke liye hamesha ready hoon! ...";
    _addMessage(welcomeText, false);
    _speakText(
        "स्वागत है, $userName! मैं हूँ सूसरी, तेरा परम मित्र। बोल ना, क्या मदद चाहिए? मैं तेरी सेफ्टी के लिए हमेशा तैयार हूँ! ...");
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  void _addMessage(String? text, bool fromUser) {
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
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
    }

    try {
      setState(() => isSpeaking = true);
      await flutterTts.speak(text);
      flutterTts.setCompletionHandler(() {
        setState(() => isSpeaking = false);
      });
    } catch (e) {
      setState(() => isSpeaking = false);
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 1));
        _speakText(text, retryCount + 1);
      } else {
        _addMessage("Liza, voice mein thodi si dikkat hai, sorry!", false);
      }
    }
  }

  void _startListening() {
    if (!_speech.isListening && _speech.isAvailable) {
      setState(() => isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            isListening = false;
          });
          _sendChatMessage(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
      _speakText("सुन रही हूँ, Liza! बोल ना...");
    }
  }

  @override
  Widget build(BuildContext context) {
    final InputDecoration textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Type a message...',
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
                        'No API key found. Please provide an API Key using '
                        "'--dart-define' to set the 'API_KEY' declaration.",
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
    if (message.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      _addMessage(message, true);
      final redirectPath = _redirectToFeature(message);
      if (redirectPath != null) {
        final pageName = redirectPath == '/safepath'
            ? 'SafePath'
            : redirectPath == '/community'
                ? 'Community'
                : redirectPath == '/home'
                    ? 'Home'
                    : redirectPath == '/ai-assistant'
                        ? 'AI Assistant'
                        : 'Profile';
        final responseText =
            "Liza, main tujhe $pageName page pe le jati hoon! Ek second ruko...";
        _addMessage(responseText, false);
        _speakText(
            "लिज़ा, मैं तुझे $pageName पेज पर ले जाती हूँ! एक सेकंड रुको...");
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushNamed(context, '/main'); // Navigate back to MainScreen
      } else if (message.trim().toLowerCase() == "help help help") {
        final concernMessage =
            "Liza, lagta hai kuch serious hai! Main teesri baar accident alert bhej rahi hoon...";
        _addMessage(concernMessage, false);
        for (int i = 0; i < 3; i++) {
          await Future.delayed(Duration(seconds: i * 2));
        }
        _speakText("क्या हुआ, $userName? सब ठीक है ना?");
      } else {
        final unsupportedMessage =
            "Sorry, Liza! Main sirf app ke 5 sections mein redirect kar sakti hoon: SafePath, Community, Home, AI Assistant, aur Profile. Lekin main Gemini se help le sakti hoon!";
        _addMessage(unsupportedMessage, false);
        _speakText(
            "सॉरी, लिज़ा! मैं सिर्फ़ ऐप के 5 सेक्शन्स में रीडायरेक्ट कर सकती हूँ: सेफपाथ, कम्युनिटी, होम, एआई असिस्टेंट, और प्रोफाइल। लेकिन मैं जेमिनी से मदद ले सकती हूँ!");

        const languageInstruction =
            "Respond EXCLUSIVELY in Hinglish for this message. Do not mix languages unless the user explicitly requests a language switch.";
        final content = Content.text(
            '${mitraConfig['systemMessage']}\n\n$languageInstruction\nUser: $message');
        final response = await _chat.sendMessage(content);
        final text = response.text;
        _addMessage(text, false);

        if (text != null) {
          final hindiText = text
              .replaceAll("Liza", "लिज़ा")
              .replaceAll("tu", "तू")
              .replaceAll("hai", "है")
              .replaceAll("main", "मैं")
              .replaceAll("tujhe", "तुझे")
              .replaceAll("pe", "पर")
              .replaceAll("le jati hoon", "ले जाती हूँ")
              .replaceAll("ek second ruko", "एक सेकंड रुको")
              .replaceAll("Oops", "अरे")
              .replaceAll("Mu samajhi nahi", "मैं समझी नहीं")
              .replaceAll("fir ek bar bolo na", "फिर एक बार बोलो ना");
          _speakText(hindiText);
        }
      }
    } catch (e) {
      _showError(e.toString());
      _addMessage(
          "Oops, $userName! Mu samajhi nahi, fir ek bar bolo na... 😅", false);
      _speakText("अरे, $userName! मैं समझी नहीं, फिर एक बार बोलो ना... 😅");
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
