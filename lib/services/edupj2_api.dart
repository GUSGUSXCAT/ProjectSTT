// lib/services/edupj2_api.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// โครงสร้างผลลัพธ์แบบง่าย ๆ
class Edupj2SttResult {
  final bool success;
  final String text;
  final double? accuracy;
  final double? cer;
  final String? expected;
  final String? error;

  Edupj2SttResult({
    required this.success,
    required this.text,
    this.accuracy,
    this.cer,
    this.expected,
    this.error,
  });

  factory Edupj2SttResult.fromJson(Map<String, dynamic> json) {
    return Edupj2SttResult(
      success: json['success'] == true,
      text: json['text'] ?? '',
      expected: json['expected'],
      accuracy: json['score'] != null
          ? (json['score']['accuracy'] as num?)?.toDouble()
          : null,
      cer: json['score'] != null
          ? (json['score']['cer'] as num?)?.toDouble()
          : null,
      error: json['error'],
    );
  }
}

class Edupj2Api {
  final String baseUrl;

  Edupj2Api({required this.baseUrl});

  /// เช็ก /health
  Future<Map<String, dynamic>> checkHealth() async {
    final url = Uri.parse('$baseUrl/health');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('health error: ${res.statusCode} ${res.body}');
    }
  }

  /// ส่งไฟล์ไป /transcribe แล้วได้แค่ text กลับมา
  Future<String> transcribeFile(String filePath) async {
    final url = Uri.parse('$baseUrl/transcribe');

    final request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        filePath,
        contentType: MediaType('audio', 'wav'),
      ),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['text'] ?? '';
    } else {
      throw Exception('transcribe error: $body');
    }
  }

  /// ส่งไฟล์ + expected_text ไป /transcribe-score
  Future<Map<String, dynamic>> transcribeAndScoreFile(
    String filePath,
    String expectedText,
  ) async {
    final url = Uri.parse('$baseUrl/transcribe-score');

    final request = http.MultipartRequest('POST', url)
      ..fields['expected_text'] = expectedText
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio',
          filePath,
          contentType: MediaType('audio', 'wav'),
        ),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('transcribe-score error: $body');
    }
  }

  double getAccuracyPercent(Map<String, dynamic> resultJson) {
    try {
      final score = resultJson['score'];
      if (score == null) return 0.0;
      final acc = (score['accuracy'] as num?)?.toDouble() ?? 0.0;
      return acc * 100;
    } catch (_) {
      return 0.0;
    }
  }
}
