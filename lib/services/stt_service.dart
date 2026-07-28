import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // ✅ เพิ่มบรรทัดนี้
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SttService {
  final String baseUrl;
  SttService({String? base}) : baseUrl = base ?? _defaultBase();

  static String _defaultBase() {
    // ✅ เช็ค Web ก่อน (เพราะ Web ไม่มี Platform)
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }
    
    // ✅ แล้วค่อยเช็ค Mobile/Desktop
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000'; // Android Emulator
    }
    
    return 'http://127.0.0.1:5000'; // Desktop/iOS
  }

  Future<Map<String, dynamic>> _sendMultipart(
    String path,
    Uri uri, {
    Map<String, String>? fields,
  }) async {
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'audio',
        path,
        contentType: MediaType('audio', 'wav'),
      ));
    if (fields != null) req.fields.addAll(fields);

    final streamed =
        await req.send().timeout(const Duration(seconds: 60)); // ✅ เพิ่มเป็น 60 วินาที
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}: ${res.body}', uri: uri);
    }

    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid JSON from server');
    }
  }

  Future<String> transcribe(String path) async {
    final json = await _sendMultipart(path, Uri.parse('$baseUrl/stt'));
    return (json['text'] as String?) ?? '';
  }

  Future<Map<String, dynamic>> score(String path, String expected) async {
    final json = await _sendMultipart(
      path,
      Uri.parse('$baseUrl/stt-score'),
      fields: {'expected_text': expected},
    );
    final score = (json['score'] as Map<String, dynamic>?) ?? const {};
    return {
      'text': (json['text'] as String?) ?? '',
      'char_accuracy': (score['char_accuracy'] as num?)?.toDouble() ?? 0.0,
      'levenshtein': score['levenshtein'],
      'target_len': score['target_len'],
    };
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http
        .get(Uri.parse('$baseUrl/healthz'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}: ${res.body}',
          uri: Uri.parse('$baseUrl/healthz'));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}