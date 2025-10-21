import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.0.2.2:3000';

enum TtsState { playing, stopped }

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _translatedController = TextEditingController();

  TtsState _ttsState = TtsState.stopped;
  bool _isTranslating = false;

  final Map<String, String> _languages = {
    '한국어': 'ko',
    'English': 'en',
    '日本語': 'ja',
    '中文': 'zh',
    'Español': 'es',
    'Français': 'fr',
  };
  String _fromLanguage = 'ko';
  String _toLanguage = 'en';

  static const Color darkBg = Color(0xFF0A0E27);
  static const Color cardBg = Color(0xFF1A1F3A);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color silverAccent = Color(0xFFC0C0C0);
  static const Color darkCard = Color(0xFF151932);

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
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('번역할 텍스트를 입력하세요'),
          backgroundColor: cardBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isTranslating = true);
    _translatedController.text = '번역 중...';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/translations'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'originalText': _textController.text.trim(),
          'fromLang': _fromLanguage,
          'toLang': _toLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['translatedText'] != null) {
          setState(() {
            _translatedController.text = data['translatedText'];
          });
        } else {
          throw Exception(data['error'] ?? '알 수 없는 번역 오류');
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('서버 오류 (${response.statusCode}): ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _translatedController.text = '번역 실패';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('번역 오류: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            const SizedBox(height: 20),
            Expanded(
              child: _buildTextField(
                controller: _textController,
                label: '원본 텍스트',
                hint: '번역할 내용을 입력하세요...',
                icon: Icons.edit_note,
              ),
            ),
            const SizedBox(height: 20),
            _buildTranslateButton(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildTextField(
                controller: _translatedController,
                label: '번역 결과',
                hint: '번역 결과가 여기에 표시됩니다.',
                icon: Icons.auto_awesome,
                readOnly: true,
                suffixIcon: _buildSpeakerButton(),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'From',
                _fromLanguage,
                    (val) => setState(() => _fromLanguage = val!),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: goldAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: goldAccent,
                size: 20,
              ),
            ),
            Expanded(
              child: _buildDropdown(
                'To',
                _toLanguage,
                    (val) => setState(() => _toLanguage = val!),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: silverAccent.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: cardBg,
            icon: Icon(Icons.arrow_drop_down, color: goldAccent),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
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
    required IconData icon,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(icon, color: goldAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: goldAccent,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                suffixIcon: suffixIcon,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            goldAccent.withOpacity(0.8),
            goldAccent,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: goldAccent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          _ttsState == TtsState.playing ? Icons.stop_circle : Icons.volume_up,
          color: darkBg,
        ),
        onPressed: _translatedController.text.isNotEmpty &&
            _translatedController.text != '번역 중...' &&
            _translatedController.text != '번역 실패'
            ? (_ttsState == TtsState.playing ? _stop : _speak)
            : null,
      ),
    );
  }

  Widget _buildTranslateButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isTranslating
              ? [Colors.grey.shade700, Colors.grey.shade800]
              : [
            goldAccent,
            const Color(0xFFFFD700),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isTranslating
                ? Colors.transparent
                : goldAccent.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isTranslating ? null : _translate,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isTranslating)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: darkBg,
                    strokeWidth: 3,
                  ),
                )
              else
                Icon(Icons.translate, color: darkBg, size: 24),
              const SizedBox(width: 12),
              Text(
                _isTranslating ? '번역 중...' : '번역하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBg,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}