import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  late final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _listening = false;
  String _text = '';
  final Map<String, String> _locales = {
    '한국어': 'ko_KR',
    'English': 'en_US',
    '日本語': 'ja_JP',
  };
  String _currentLocaleId = 'ko_KR';
  List<stt.LocaleName> _localeNames = [];

  static const Color darkBg = Color(0xFF0A0E27);
  static const Color cardBg = Color(0xFF1A1F3A);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color silverAccent = Color(0xFFC0C0C0);
  static const Color darkCard = Color(0xFF151932);

  @override
  void initState() {
    super.initState();
    _initSTT();
  }

  Future<void> _initSTT() async {
    _available = await _speech.initialize(
      onStatus: (status) => setState(() => _listening = status == 'listening'),
      onError: (error) => setState(() => _text = '오류: ${error.errorMsg}'),
    );
    if (_available) {
      _localeNames = await _speech.locales();
      var currentLocale = _localeNames.firstWhere(
            (locale) => locale.localeId == _currentLocaleId,
        orElse: () => _localeNames.first,
      );
      _currentLocaleId = currentLocale.localeId;
    }
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('음성 인식을 사용할 수 없습니다.'),
          backgroundColor: cardBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _speech.listen(
      localeId: _currentLocaleId,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onResult: (r) => setState(() => _text = r.recognizedWords),
    );
    setState(() => _listening = true);
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  void _copyToClipboard() {
    if (_text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('텍스트가 복사되었습니다.'),
          backgroundColor: cardBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearText() {
    setState(() => _text = '');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkBg,
            const Color(0xFF1A1F3A),
            darkBg,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildLanguageSelector(),
            const SizedBox(height: 24),
            _buildMicButton(),
            const SizedBox(height: 24),
            Expanded(
              child: _buildResultCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goldAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: goldAccent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: goldAccent, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '음성 언어',
                      style: TextStyle(
                        color: silverAccent.withOpacity(0.7),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildLanguageDropdown(),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _listening ? goldAccent.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _listening ? goldAccent : silverAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_off,
                color: _listening ? goldAccent : silverAccent.withOpacity(0.5),
                size: 24,
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
        dropdownColor: cardBg,
        icon: Icon(Icons.arrow_drop_down, color: goldAccent, size: 20),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        items: _locales.entries.map((entry) {
          final bool isSupported = _localeNames.any(
                (locale) => locale.localeId == entry.value,
          );
          return DropdownMenuItem<String>(
            value: entry.value,
            enabled: isSupported,
            child: Text(
              entry.key,
              style: TextStyle(
                color: isSupported ? Colors.white : Colors.grey,
              ),
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            setState(() => _currentLocaleId = newValue);
          }
        },
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _listening ? _stopListening : _startListening,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: _listening
                ? [Colors.red.shade400, Colors.red.shade600]
                : [goldAccent, const Color(0xFFFFD700)],
          ),
          boxShadow: [
            BoxShadow(
              color: (_listening ? Colors.red : goldAccent).withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          _listening ? Icons.stop : Icons.mic,
          color: darkBg,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: silverAccent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: goldAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '인식 결과',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: goldAccent,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildIconButton(Icons.copy, '복사', _copyToClipboard),
                    const SizedBox(width: 8),
                    _buildIconButton(Icons.delete_outline, '지우기', _clearText),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: SelectableText(
                  _text.isEmpty ? '버튼을 누르고 말씀해 주세요…' : _text,
                  style: TextStyle(
                    fontSize: 18,
                    color: _text.isEmpty
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: goldAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: goldAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: goldAccent,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}