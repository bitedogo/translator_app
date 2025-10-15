import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class TextToSpeechPage extends StatefulWidget {
  const TextToSpeechPage({super.key});

  @override
  State<TextToSpeechPage> createState() => _TextToSpeechPageState();
}

class _TextToSpeechPageState extends State<TextToSpeechPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();

  TtsState _ttsState = TtsState.stopped;

  final Map<String, String> _locales = {
    '한국어': 'ko_KR',
    'English': 'en_US',
    '日本語': 'ja_JP'
  };

  String _currentLocaleId = 'ko_KR';

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage(_currentLocaleId);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() => _ttsState = TtsState.playing);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _ttsState = TtsState.stopped);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _ttsState = TtsState.stopped);
    });

    setState(() {});
  }

  Future<void> _speak() async {
    if (_textController.text.isNotEmpty) {
      await _flutterTts.speak(_textController.text);
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech (TTS)'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '음성 언어: ',
                      style: TextStyle(color: Colors.black54),
                    ),
                    _buildLanguageDropdown(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '여기에 읽을 내용을 입력하세요...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _ttsState == TtsState.playing
                      ? Colors.red.shade400
                      : theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _ttsState == TtsState.playing ? _stop : _speak,
                icon: Icon(
                  _ttsState == TtsState.playing ? Icons.stop : Icons.volume_up,
                ),
                label: Text(
                  _ttsState == TtsState.playing ? '멈춤' : '읽어주기',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _currentLocaleId,
        items: _locales.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.value,
            child: Text(entry.key),
          );
        }).toList(),
        onChanged: (newValue) async {
          if (newValue != null) {
            setState(() => _currentLocaleId = newValue);
            await _flutterTts.setLanguage(_currentLocaleId);
          }
        },
      ),
    );
  }
}