import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.0.2.2:3000';

class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

  bool _isListening = false;
  bool _isInitialized = false;
  String _statusMessage = '초기화 중...';
  double _confidence = 0.0;

  final Map<String, String> _locales = {
    '한국어': 'ko_KR',
    'English': 'en_US',
    '日本語': 'ja_JP'
  };

  String _currentLocale = 'ko_KR';

  static const Color darkBg = Color(0xFF0A0E27);
  static const Color cardBg = Color(0xFF1A1F3A);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color silverAccent = Color(0xFFC0C0C0);
  static const Color darkCard = Color(0xFF151932);

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
              _statusMessage = '준비 완료';
            });
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _statusMessage = '오류 발생';
          });
          _showSnackBar('음성 인식 오류: ${error.errorMsg}', isError: true);
        },
      );

      if (available) {
        setState(() {
          _isInitialized = true;
          _statusMessage = '준비 완료';
        });
      } else {
        setState(() {
          _statusMessage = '음성 인식 사용 불가';
        });
        _showSnackBar('음성 인식을 사용할 수 없습니다', isError: true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '초기화 실패';
      });
      _showSnackBar('STT 초기화 실패: $e', isError: true);
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      _showSnackBar('음성 인식이 초기화되지 않았습니다', isError: true);
      return;
    }

    if (_isListening) return;

    setState(() {
      _isListening = true;
      _statusMessage = '듣는 중...';
      _textController.clear();
      _confidence = 0.0;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            _confidence = result.confidence;
          });

          if (result.finalResult) {
            _stopListening();
            if (_textController.text.isNotEmpty) {
              _saveToDatabase();
            }
          }
        },
        localeId: _currentLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _statusMessage = '듣기 실패';
      });
      _showSnackBar('음성 인식 시작 실패: $e', isError: true);
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    setState(() {
      _isListening = false;
      _statusMessage = '중지됨';
    });
  }

  Future<void> _saveToDatabase() async {
    if (_textController.text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/stt'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'audioUrl': 'stt_input_${DateTime.now().millisecondsSinceEpoch}',
          'recognizedText': _textController.text,
          'language': _currentLocale,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          debugPrint('STT record saved with ID: ${data['id']}');
        }
      }
    } catch (e) {
      debugPrint('Failed to save STT record: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade900 : cardBg,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [darkBg, const Color(0xFF1A1F3A), darkBg],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildLanguageSelector(),
              const SizedBox(height: 16),
              _buildStatusIndicator(),
              const SizedBox(height: 24),
              Expanded(child: _buildTextDisplayCard()),
              const SizedBox(height: 24),
              _buildMicButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isInitialized
              ? goldAccent.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? Colors.red
                  : (_isInitialized ? Colors.green : Colors.grey),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? Colors.red : Colors.green)
                      .withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              color: silverAccent.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_confidence > 0) ...[
            const SizedBox(width: 12),
            Text(
              '${(_confidence * 100).toInt()}%',
              style: TextStyle(
                color: goldAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language, color: goldAccent, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '인식 언어',
                  style: TextStyle(
                    color: silverAccent.withOpacity(0.7),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentLocale,
                    dropdownColor: cardBg,
                    icon: Icon(Icons.arrow_drop_down, color: goldAccent, size: 20),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _locales.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.value,
                        enabled: !_isListening,
                        child: Text(entry.key),
                      );
                    }).toList(),
                    onChanged: _isListening
                        ? null
                        : (newValue) {
                      if (newValue != null) {
                        setState(() => _currentLocale = newValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextDisplayCard() {
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
              children: [
                Icon(Icons.text_fields, color: goldAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '인식된 텍스트',
                  style: TextStyle(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Text(
                  _textController.text.isEmpty
                      ? '마이크 버튼을 눌러 음성을 입력하세요...'
                      : _textController.text,
                  style: TextStyle(
                    color: _textController.text.isEmpty
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white,
                    fontSize: 16,
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

  Widget _buildMicButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isListening
              ? [Colors.red.shade400, Colors.red.shade600]
              : [goldAccent, const Color(0xFFFFD700)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isListening ? Colors.red : goldAccent).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isListening ? _stopListening : _startListening,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isListening ? Icons.mic_off : Icons.mic,
                color: darkBg,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isListening ? '중지' : '음성 인식 시작',
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
