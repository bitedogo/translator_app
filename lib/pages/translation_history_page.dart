import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.0.2.2:3000';

class TranslationRecord {
  final int id;
  final String originalText;
  final String translatedText;
  final String fromLang;
  final String toLang;
  final String createdAt;

  TranslationRecord({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.fromLang,
    required this.toLang,
    required this.createdAt,
  });

  factory TranslationRecord.fromJson(Map<String, dynamic> json) {
    return TranslationRecord(
      id: json['ID'] as int,
      originalText: json['ORIGINAL_TEXT'] as String,
      translatedText: json['TRANSLATED_TEXT'] as String,
      fromLang: json['FROM_LANG'] as String,
      toLang: json['TO_LANG'] as String,
      createdAt: json['CREATED_AT'] as String,
    );
  }
}

class TranslationHistoryPage extends StatefulWidget {
  const TranslationHistoryPage({super.key});

  @override
  State<TranslationHistoryPage> createState() => _TranslationHistoryPageState();
}

class _TranslationHistoryPageState extends State<TranslationHistoryPage> {
  List<TranslationRecord> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const Color darkBg = Color(0xFF0A0E27);
  static const Color cardBg = Color(0xFF1A1F3A);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color silverAccent = Color(0xFFC0C0C0);
  static const Color darkCard = Color(0xFF151932);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/translations/recent?limit=5'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _history = (data['data'] as List)
                .map((item) => TranslationRecord.fromJson(item))
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '기록을 불러오는데 실패했습니다: $e';
      });
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _getLangName(String code) {
    const langMap = {
      'ko': '한국어',
      'en': 'English',
      'ja': '日本語',
      'zh': '中文',
      'es': 'Español',
      'fr': 'Français',
    };
    return langMap[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('번역 기록'),
        backgroundColor: cardBg,
        foregroundColor: goldAccent,
        elevation: 0,
        iconTheme: const IconThemeData(color: goldAccent),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: goldAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: goldAccent.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchHistory,
              tooltip: '새로고침',
              color: goldAccent,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              darkBg,
              const Color(0xFF1A1F3A),
              darkBg,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: goldAccent),
        )
            : _errorMessage != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: silverAccent.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: silverAccent.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldAccent,
                    foregroundColor: darkBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            : _history.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: silverAccent.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '번역 기록이 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  color: silverAccent.withOpacity(0.5),
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchHistory,
          color: goldAccent,
          backgroundColor: cardBg,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final record = _history[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: silverAccent.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  goldAccent.withOpacity(0.3),
                                  goldAccent.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: goldAccent.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_getLangName(record.fromLang)} → ${_getLangName(record.toLang)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: goldAccent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDateTime(record.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: silverAccent.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        record.originalText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: goldAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: goldAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record.translatedText,
                              style: const TextStyle(
                                fontSize: 16,
                                color: goldAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}