import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.0.2.2:3000';

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
  bool _isInitialized = false;
  String _statusMessage = '초기화 중...';

  final Map<String, String> _locales = {
    '한국어': 'ko-KR',
    'English': 'en-US',
    '日本語': 'ja-JP'
  };

  String _currentLocaleId = 'ko-KR';

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
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    try {
      await _flutterTts.setLanguage(_currentLocaleId);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );

      _flutterTts.setStartHandler(() {
        setState(() {
          _ttsState = TtsState.playing;
          _statusMessage = '재생 중...';
        });
      });

      _flutterTts.setCompletionHandler(() {
        setState(() {
          _ttsState = TtsState.stopped;
          _statusMessage = '준비 완료';
        });
        if (_textController.text.isNotEmpty) {
          _saveToDatabase();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        setState(() {
          _ttsState = TtsState.stopped;
          _statusMessage = '오류 발생';
        });
        _showSnackBar('음성 재생 오류: $msg', isError: true);
      });

      setState(() {
        _isInitialized = true;
        _statusMessage = '준비 완료';
      });
    } catch (e) {
      setState(() => _statusMessage = '초기화 실패');
      _showSnackBar('TTS 초기화 실패: $e', isError: true);
    }
  }

  Future<void> _speak() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('읽을 텍스트를 입력해주세요.', isError: true);
      return;
    }

    if (!_isInitialized) {
      _showSnackBar('TTS가 아직 초기화되지 않았습니다.', isError: true);
      return;
    }

    try {
      setState(() => _statusMessage = '재생 시작...');
      final result = await _flutterTts.speak(_textController.text);

      if (result == 0) {
        _showSnackBar('음성 재생에 실패했습니다.', isError: true);
        setState(() {
          _ttsState = TtsState.stopped;
          _statusMessage = '재생 실패';
        });
      }
    } catch (e) {
      _showSnackBar('음성 재생 오류: $e', isError: true);
      setState(() {
        _ttsState = TtsState.stopped;
        _statusMessage = '재생 실패';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _flutterTts.stop();
      setState(() {
        _ttsState = TtsState.stopped;
        _statusMessage = '중지됨';
      });
    } catch (_) {}
  }

  Future<void> _saveToDatabase() async {
    if (_textController.text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tts'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'inputText': _textController.text,
          'audioUrl': 'tts_output_${DateTime.now().millisecondsSinceEpoch}',
          'voiceSetting': _currentLocaleId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {}
      }
    } catch (_) {}
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkBg, Color(0xFF1A1F3A), darkBg],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            _buildStatusIndicator(),
            const SizedBox(height: 24),
            Expanded(child: _buildTextInputCard()),
            const SizedBox(height: 24),
            _buildSpeakButton(),
          ],
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
              color: _isInitialized ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (_isInitialized ? Colors.green : Colors.red)
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
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldAccent.withOpacity(0.3)),
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
            const Icon(Icons.record_voice_over, color: goldAccent, size: 24),
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
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _currentLocaleId,
        dropdownColor: cardBg,
        icon: const Icon(Icons.arrow_drop_down, color: goldAccent, size: 20),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        items: _locales.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.value,
            enabled: _ttsState != TtsState.playing,
            child: Text(entry.key),
          );
        }).toList(),
        onChanged: _ttsState == TtsState.playing
            ? null
            : (newValue) async {
          if (newValue != null) {
            setState(() => _currentLocaleId = newValue);
            await _flutterTts.setLanguage(_currentLocaleId);
          }
        },
      ),
    );
  }

  Widget _buildTextInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: silverAccent.withOpacity(0.2)),
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
            child: const Row(
              children: [
                Icon(Icons.edit_note, color: goldAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  '읽을 텍스트',
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
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: '여기에 읽을 내용을 입력하세요...',
                  hintStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _ttsState == TtsState.playing
              ? [Colors.redAccent, Colors.red]
              : [goldAccent, Color(0xFFFFD700)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
            (_ttsState == TtsState.playing ? Colors.red : goldAccent)
                .withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _ttsState == TtsState.playing ? _stop : _speak,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _ttsState == TtsState.playing ? Icons.stop : Icons.volume_up,
                color: darkBg,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _ttsState == TtsState.playing ? '멈춤' : '읽어주기',
                style: const TextStyle(
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
