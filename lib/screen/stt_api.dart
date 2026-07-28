import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SttApi {
  final String baseUrl; 
  const SttApi({this.baseUrl = 'http://127.0.0.1:5000'});

  Future<String> transcribePath(String path, {String mime = 'audio/wav'}) async {
    final uri = Uri.parse('$baseUrl/stt');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('audio', path, contentType: MediaType.parse(mime)));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('STT error ${res.statusCode}: $body');
    }
    final jsonBody = jsonDecode(body) as Map<String, dynamic>;
    return (jsonBody['text'] as String? ?? '').trim();
  }

  Future<String> transcribeBytes(Uint8List bytes, {String filename = 'audio.wav', String mime = 'audio/wav'}) async {
    final uri = Uri.parse('$baseUrl/stt');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(http.MultipartFile.fromBytes('audio', bytes, filename: filename, contentType: MediaType.parse(mime)));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('STT error ${res.statusCode}: $body');
    }
    final jsonBody = jsonDecode(body) as Map<String, dynamic>;
    return (jsonBody['text'] as String? ?? '').trim();
  }

  Future<Map<String, dynamic>> transcribeAndScorePath(String path, String expected, {String mime = 'audio/wav'}) async {
    final uri = Uri.parse('$baseUrl/stt-score');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('audio', path, contentType: MediaType.parse(mime)));
    req.fields['expected_text'] = expected;
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('STT-SCORE error ${res.statusCode}: $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transcribeAndScoreBytes(Uint8List bytes, String expected, {String filename = 'audio.wav', String mime = 'audio/wav'}) async {
    final uri = Uri.parse('$baseUrl/stt-score');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(http.MultipartFile.fromBytes('audio', bytes, filename: filename, contentType: MediaType.parse(mime)));
    req.fields['expected_text'] = expected;
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('STT-SCORE error ${res.statusCode}: $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
