import 'package:flutter/material.dart';
import 'pages/translator_page.dart';
import 'pages/speech_to_text_page.dart';
import 'pages/text_to_speech_page.dart';
import 'pages/translation_history_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translation App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TranslatorPage(),
    SpeechToTextPage(),
    TextToSpeechPage(),
  ];

  void _navigateToHistory() {
    HistoryType type;
    switch (_currentIndex) {
      case 0:
        type = HistoryType.translation;
        break;
      case 1:
        type = HistoryType.stt;
        break;
      case 2:
        type = HistoryType.tts;
        break;
      default:
        type = HistoryType.translation;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TranslationHistoryPage(historyType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String tooltip;
    const Color cardBg = Color(0xFF1A1F3A);
    const Color goldAccent = Color(0xFFD4AF37);

    switch (_currentIndex) {
      case 0:
        tooltip = '번역 기록';
        break;
      case 1:
        tooltip = 'STT 기록';
        break;
      case 2:
        tooltip = 'TTS 기록';
        break;
      default:
        tooltip = '기록';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('번역 앱'),
        backgroundColor: cardBg,
        foregroundColor: goldAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: goldAccent),
            onPressed: _navigateToHistory,
            tooltip: tooltip,
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic),
            label: 'STT',
          ),
          NavigationDestination(
            icon: Icon(Icons.volume_up),
            label: 'TTS',
          ),
        ],
      ),
    );
  }
}