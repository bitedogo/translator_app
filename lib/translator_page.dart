import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

enum TtsState { playing, stopped }

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _translatedController = TextEditingController();

  TtsState _ttsState = TtsState.stopped;
  bool _isTranslating = false;

  final Map<String, String> _languages = {
    '한국어': 'ko',
    'English': 'en',
    '日本語': 'ja',
  };
  String _fromLanguage = 'ko';
  String _toLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  @override
  void dispose() {
    _textController.dispose();
    _translatedController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    _flutterTts.setStartHandler(() {
      setState(() => _ttsState = TtsState.playing);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _ttsState = TtsState.stopped);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _ttsState = TtsState.stopped);
    });
  }

  Future<void> _translate() async {
    if (_textController.text.isEmpty) return;
    setState(() => _isTranslating = true);

    try {
      final translation = await _translator.translate(
        _textController.text,
        from: _fromLanguage,
        to: _toLanguage,
      );
      setState(() => _translatedController.text = translation.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('번역 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _speak() async {
    if (_translatedController.text.isNotEmpty) {
      await _flutterTts.setLanguage(_toLanguage);
      await _flutterTts.speak(_translatedController.text);
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
        title: const Text('언어 번역기'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _textController,
              label: '원본 텍스트',
              hint: '번역할 내용을 입력하세요...',
            ),
            const SizedBox(height: 16),
            _buildTranslateButton(theme),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _translatedController,
              label: '번역 결과',
              hint: '번역 결과가 여기에 표시됩니다.',
              readOnly: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _ttsState == TtsState.playing
                      ? Icons.stop_circle
                      : Icons.volume_up,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _ttsState == TtsState.playing ? _stop : _speak,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDropdown(
              'From:',
              _fromLanguage,
                  (val) => setState(() => _fromLanguage = val!),
            ),
            const Icon(Icons.arrow_forward, color: Colors.grey),
            _buildDropdown(
              'To:',
              _toLanguage,
                  (val) => setState(() => _toLanguage = val!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label,
      String value,
      ValueChanged<String?> onChanged,
      ) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            items: _languages.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.value,
                child: Text(entry.key),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: suffixIcon,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isTranslating ? null : _translate,
        icon: _isTranslating
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        )
            : const Icon(Icons.translate),
        label: Text(
          _isTranslating ? '번역 중...' : '번역하기',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}