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
        const SnackBar(content: Text('음성 인식을 사용할 수 없습니다.')),
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
        const SnackBar(content: Text('텍스트가 복사되었습니다.')),
      );
    }
  }

  void _clearText() {
    setState(() => _text = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech to Text (STT)'),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '언어: ',
                          style: TextStyle(color: Colors.black54),
                        ),
                        _buildLanguageDropdown(),
                      ],
                    ),
                    Icon(
                      _listening ? Icons.mic : Icons.mic_off,
                      color: _listening
                          ? theme.colorScheme.primary
                          : Colors.grey,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _listening
                      ? Colors.red.shade400
                      : theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _listening ? _stopListening : _startListening,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(
                  _listening ? '듣는 중...' : '음성 인식 시작',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '인식 결과',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                                tooltip: '복사하기',
                                onPressed: _copyToClipboard,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                                tooltip: '지우기',
                                onPressed: _clearText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: SelectableText(
                            _text.isEmpty ? '버튼을 누르고 말씀해 주세요…' : _text,
                            style: TextStyle(
                              fontSize: 18,
                              color: _text.isEmpty
                                  ? Colors.grey.shade500
                                  : Colors.black87,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ),
                    ),
                  ],
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
          final bool isSupported = _localeNames.any(
                (locale) => locale.localeId == entry.value,
          );
          return DropdownMenuItem<String>(
            value: entry.value,
            enabled: isSupported,
            child: Text(
              entry.key,
              style: TextStyle(
                color: isSupported ? Colors.black87 : Colors.grey,
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
}