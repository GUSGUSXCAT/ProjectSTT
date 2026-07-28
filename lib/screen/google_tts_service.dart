import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart'; // ✅ มีอยู่แล้ว
import 'package:path_provider/path_provider.dart';

class GoogleTtsService {
  static const _apiKey = 'AIzaSyA2i8qRBgE5XZMK3X1O8t4_7ieXO6GPeoc'; // ใส่ key จริง

  final AudioPlayer _player = AudioPlayer();

  Future<void> speak(String text, {double rate = 0.75}) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {
            "languageCode": "th-TH",
            "name": "th-TH-Neural2-C",
          },
          "audioConfig": {
            "audioEncoding": "MP3",
            "speakingRate": rate,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBytes = base64Decode(data['audioContent']);

        if (kIsWeb) {
          // Web: เล่นจาก bytes โดยตรง
          await _player.play(BytesSource(audioBytes));
        } else {
          // Mobile: บันทึกไฟล์ชั่วคราวแล้วเล่น
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/tts_output.mp3');
          await file.writeAsBytes(audioBytes);
          await _player.play(DeviceFileSource(file.path));
        }
      } else {
        debugPrint('❌ TTS Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ GoogleTTS error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}