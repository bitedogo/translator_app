import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.0.2.2:3000';

class TranslationRecord {
  final int id;
  final String originalText;
  final String translatedText;

  TranslationRecord({
    required this.id,
    required this.originalText,
    required this.translatedText,
  });

  factory TranslationRecord.fromJson(Map<String, dynamic> json) {
    return TranslationRecord(
      id: json['ID'] as int,
      originalText: json['ORIGINAL_TEXT'] as String,
      translatedText: json['TRANSLATED_TEXT'] as String,
    );
  }
}

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

  List<TranslationRecord> _recentHistory = [];

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

  @override
  void initState() {
    super.initState();
    _initTTS();
    _fetchRecentHistory();
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

  Future<void> _fetchRecentHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/translations/recent?limit=5'),
      );

      debugPrint('History response status: ${response.statusCode}');
      debugPrint('History response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          final records = (data['data'] as List)
              .map((item) => TranslationRecord.fromJson(item))
              .toList();

          debugPrint('Parsed ${records.length} records');

          setState(() {
            _recentHistory = records;
          });
        }
      }
    } catch (e) {
      debugPrint('History fetch error: $e');
    }
  }

  Future<void> _translate() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('번역할 텍스트를 입력하세요')),
      );
      return;
    }

    setState(() => _isTranslating = true);
    _translatedController.text = '번역 중...';

    try {
      debugPrint('Sending translation request...');
      debugPrint('Text: ${_textController.text}');
      debugPrint('From: $_fromLanguage, To: $_toLanguage');

      final response = await http.post(
        Uri.parse('$baseUrl/api/translations'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'originalText': _textController.text.trim(),
          'fromLang': _fromLanguage,
          'toLang': _toLanguage,
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['translatedText'] != null) {
          setState(() {
            _translatedController.text = data['translatedText'];
          });
          await _fetchRecentHistory();
        } else {
          throw Exception(data['error'] ?? '알 수 없는 번역 오류');
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('서버 오류 (${response.statusCode}): ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('Translation error: $e');
      _translatedController.text = '번역 실패';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('번역 오류: $e')),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('번역기'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            Flexible(
              flex: 3,
              child: _buildTextField(
                controller: _textController,
                label: '원본 텍스트',
                hint: '번역할 내용을 입력하세요...',
              ),
            ),
            const SizedBox(height: 16),
            _buildTranslateButton(theme),
            const SizedBox(height: 16),
            Flexible(
              flex: 3,
              child: _buildTextField(
                controller: _translatedController,
                label: '번역 결과',
                hint: '번역 결과가 여기에 표시됩니다.',
                readOnly: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _ttsState == TtsState.playing ? Icons.stop_circle : Icons.volume_up,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _translatedController.text.isNotEmpty
                      ? (_ttsState == TtsState.playing ? _stop : _speak)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildRecentHistoryList(theme),
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
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'From:',
                _fromLanguage,
                    (val) => setState(() => _fromLanguage = val!),
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
            Expanded(
              child: _buildDropdown(
                'To:',
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(width: 4),
        Flexible(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              items: _languages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
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
    return Card(
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

  Widget _buildRecentHistoryList(ThemeData theme) {
    return Flexible(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '최근 번역 기록 (5개)',
              style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _recentHistory.isEmpty
                ? Center(
              child: Text(
                '기록이 없습니다. 번역을 시작하세요!',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
                : ListView.builder(
              itemCount: _recentHistory.length,
              itemBuilder: (context, index) {
                final record = _recentHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  child: ListTile(
                    title: Text(
                      record.originalText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      record.translatedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(Icons.history, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        _textController.text = record.originalText;
                        _translatedController.text = record.translatedText;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}