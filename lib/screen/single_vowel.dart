import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';

// ✅ Google TTS Service (เหมือน SpeechExerciseScreen)
class GoogleTtsService {
  static const _apiKey = 'AIzaSyA2i8qRBgE5XZMK3X1O8t4_7ieXO6GPeoc';

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _webTts = FlutterTts();

  Future<void> speak(String text, {double rate = 0.75}) async {
    try {
      if (kIsWeb) {
        await _webTts.setLanguage("th-TH");
        await _webTts.setSpeechRate(rate);
        await _webTts.awaitSpeakCompletion(true);
        await _webTts.speak(text);
        return;
      }

      final response = await http.post(
        Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {"languageCode": "th-TH", "name": "th-TH-Neural2-C"},
          "audioConfig": {"audioEncoding": "MP3", "speakingRate": rate},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBytes = base64Decode(data['audioContent']);

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_output.mp3');
        await file.writeAsBytes(audioBytes);
        await _player.play(DeviceFileSource(file.path));
        await _player.onPlayerComplete.first;
      } else {
        debugPrint('❌ TTS Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ GoogleTTS error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await _webTts.stop();
  }

  void dispose() {
    _player.dispose();
    _webTts.stop();
  }
}

class SingleVowelScreen extends StatefulWidget {
  const SingleVowelScreen({super.key});

  @override
  State<SingleVowelScreen> createState() => _SingleVowelScreenState();
}

class _SingleVowelScreenState extends State<SingleVowelScreen> {
  final GoogleTtsService _tts = GoogleTtsService(); // ✅ ใช้ Google TTS
  final AudioRecorder _recorder =
      AudioRecorder(); // ✅ ใช้ AudioRecorder แทน speech_to_text
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> consonants = [];
  List<int> skippedIndices = [];
  List<Map<String, dynamic>> wrongAnswers = [];

  int currentIndex = 0;
  int correctCount = 0;
  int attempts = 0;

  bool isLoading = true;
  bool isRecording = false; // ✅ เปลี่ยนชื่อจาก isListening
  bool isProcessing = false; // ✅ เพิ่ม state processing
  bool showResult = false;
  bool isCorrect = false;
  bool _submitted = false;

  String recognizedText = "";

  bool isReviewingSkipped = false;
  bool isSkippedWord = false;

  String? loggedInUsername;

  // ✅ เพิ่ม recording config
  DateTime? _recordingStartTime;
  static const int _minRecordingMs = 1000;
  static const String API_URL = 'http://127.0.0.1:5000/stt';

  @override
  void initState() {
    super.initState();
    fetchConsonants();
    loadUsername();
  }

  @override
  void dispose() {
    _tts.dispose(); // ✅ dispose TTS
    _recorder.dispose(); // ✅ dispose recorder
    super.dispose();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");
    });
  }

  Future<void> fetchConsonants() async {
    try {
      final snapshot =
          await _firestore
              .collection('questions')
              .doc('g_1')
              .collection('singlevowel')
              .orderBy(FieldPath.documentId)
              .get();

      setState(() {
        consonants = snapshot.docs;
        isLoading = false;
      });

      if (consonants.isNotEmpty) {
        speakCurrentTts();
      }
    } catch (e) {
      debugPrint('fetchConsonants error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> saveQuizResult() async {
    try {
      if (loggedInUsername == null) return;

      final userSnap =
          await _firestore
              .collection("users")
              .where("username", isEqualTo: loggedInUsername)
              .limit(1)
              .get();

      if (userSnap.docs.isEmpty) return;

      final u = userSnap.docs.first.data();
      final fullName = "${u["first_name"]} ${u["last_name"]}";

      await _firestore.collection('quiz_results').add({
        "username": loggedInUsername,
        "full_name": fullName,
        "score": correctCount,
        "total": consonants.length,
        "timestamp": Timestamp.now(),
        "category": "สระเดี่ยว",
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint('saveQuizResult error: $e');
    }
  }

  // ✅ ใช้ Google TTS
  Future<void> speakCurrentTts() async {
    final ttsText = consonants[currentIndex]['tts_text'];
    await _tts.speak(ttsText.toString(), rate: 0.5);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mali()),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showResultSheet() {
    final total = consonants.length;
    final percent = total == 0 ? 0 : ((correctCount * 100) / total).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สรุปคะแนน',
                  style: GoogleFonts.mali(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        'ได้ $correctCount / $total',
                        style: GoogleFonts.mali(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text('$percent%', style: GoogleFonts.mali())),
                  ],
                ),
                const SizedBox(height: 12),
                if (wrongAnswers.isEmpty)
                  Text(
                    'เก่งมาก! ทำถูกทุกข้อ 🎉',
                    style: GoogleFonts.mali(fontSize: 16),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: wrongAnswers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final w = wrongAnswers[i];
                        return Text(
                          'ข้อ ${w['index']}: พูดว่า "${w['recognized']}" | ควรพูด "${w['correct']}"${w['note'] != null ? ' (${w['note']})' : ''}',
                          style: GoogleFonts.mali(fontSize: 14),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetQuiz();
                        },
                        child: Text('ทำใหม่', style: GoogleFonts.mali()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                        ),
                        child: Text(
                          'ปิด',
                          style: GoogleFonts.mali(color: Colors.white),
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
    );
  }

  void _resetQuiz() {
    setState(() {
      showResult = false;
      isCorrect = false;
      isReviewingSkipped = false;
      isSkippedWord = false;
      _submitted = false;
      currentIndex = 0;
      attempts = 0;
      correctCount = 0;
      recognizedText = "";
      wrongAnswers.clear();
      skippedIndices.clear();
    });
    speakCurrentTts();
  }

  bool get _isFinalState =>
      (!isReviewingSkipped &&
          currentIndex == consonants.length - 1 &&
          skippedIndices.isEmpty) ||
      (isReviewingSkipped && skippedIndices.isEmpty);

  void _next() async {
    if (!isCorrect) return;
    if (!showResult) return;
    _moveToNextQuestion();
  }

  void _skip() {
    if (!skippedIndices.contains(currentIndex)) {
      skippedIndices.add(currentIndex);
    }
    _moveToNextQuestion();
  }

  Future<void> _moveToNextQuestion() async {
    if (!isReviewingSkipped) {
      if (currentIndex < consonants.length - 1) {
        setState(() {
          currentIndex++;
          attempts = 0;
          recognizedText = "";
          isCorrect = false;
          showResult = false;
          isSkippedWord = false;
        });
        speakCurrentTts();
        return;
      }

      if (skippedIndices.isNotEmpty) {
        setState(() {
          isReviewingSkipped = true;
          currentIndex = skippedIndices.removeAt(0);
          attempts = 0;
          recognizedText = "";
          isCorrect = false;
          showResult = false;
          isSkippedWord = true;
        });
        speakCurrentTts();
        return;
      }

      await saveQuizResult();
      _showResultSheet();
      return;
    }

    if (skippedIndices.isNotEmpty) {
      setState(() {
        currentIndex = skippedIndices.removeAt(0);
        attempts = 0;
        recognizedText = "";
        isCorrect = false;
        showResult = false;
        isSkippedWord = true;
      });
      speakCurrentTts();
      return;
    }

    await saveQuizResult();
    _showResultSheet();
  }

  // ✅ ใช้ Recording API แบบเดียวกับ SpeechExerciseScreen
  Future<void> _startRecording() async {
    await _tts.stop(); // หยุด TTS ก่อน

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('กรุณาอนุญาตให้ใช้ไมโครโฟน', Colors.red);
      return;
    }

    try {
      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: '',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );
      }

      _recordingStartTime = DateTime.now();

      setState(() {
        isRecording = true;
        showResult = false;
        recognizedText = "";
      });
    } catch (e) {
      _showSnackBar('เริ่มบันทึกไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;

    // บังคับเวลาขั้นต่ำ
    if (_recordingStartTime != null) {
      final elapsed =
          DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      if (elapsed < _minRecordingMs) {
        final remaining = _minRecordingMs - elapsed;
        await Future.delayed(Duration(milliseconds: remaining));
      }
    }

    try {
      final path = await _recorder.stop();
      _recordingStartTime = null;

      if (path == null || path.isEmpty) {
        _showSnackBar('ไม่พบไฟล์เสียง', Colors.red);
        setState(() => isRecording = false);
        return;
      }

      if (!kIsWeb) {
        final file = File(path);
        final fileSize = await file.length();
        if (fileSize < 2000) {
          setState(() => isRecording = false);
          _showSnackBar('กรุณาพูดให้นานขึ้นอีกหน่อย', Colors.orange);
          return;
        }
      }

      setState(() {
        isRecording = false;
        isProcessing = true;
      });

      final recognized = await _sendToAPI(path);

      setState(() {
        recognizedText = recognized;
        isProcessing = false;
      });

      if (recognized.isNotEmpty) {
        _checkAnswer();
      } else {
        _showSnackBar('ไม่ได้ยินเสียง กรุณาลองใหม่อีกครั้ง', Colors.orange);
      }
    } catch (e) {
      _recordingStartTime = null;
      setState(() {
        isRecording = false;
        isProcessing = false;
      });
      _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    }
  }

  Future<String> _sendToAPI(String path) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(API_URL));

      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            response.bodyBytes,
            filename: 'audio.wav',
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', path));
      }

      final streamedResponse = await request.send();
      final resData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(resData);
        return json['text'] ?? "";
      } else {
        throw Exception('Server Error: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  int get _maxAttempts => isSkippedWord ? 1 : 3;

  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '');

  void _checkAnswer() {
    if (isCorrect) return;

    final expected = consonants[currentIndex]['tts_text'].toString().trim();
    final recNorm = _norm(recognizedText);
    final wasCorrect = _norm(expected) == recNorm;

    final maxAttempts = _maxAttempts;
    final nextAttempts = attempts + 1;

    setState(() {
      attempts = nextAttempts;
      showResult = true;
      isCorrect = wasCorrect;

      if (wasCorrect) {
        if (nextAttempts <= maxAttempts) correctCount++;
        wrongAnswers.removeWhere((m) => m['index'] == currentIndex + 1);
      } else {
        final idx = wrongAnswers.indexWhere(
          (m) => m['index'] == currentIndex + 1,
        );
        final row = {
          "index": currentIndex + 1,
          "correct": expected,
          "recognized": recognizedText,
          "attempt": nextAttempts,
          "note":
              nextAttempts >= maxAttempts ? "พยายาม $nextAttempts ครั้ง" : null,
        };
        if (idx == -1) {
          wrongAnswers.add(row);
        } else {
          wrongAnswers[idx] = row;
        }
      }
    });

    // ✅ พูดเฉลยเมื่อหมดสิทธิ์ - ใช้ Google TTS
    if (!wasCorrect && nextAttempts >= maxAttempts) {
      _tts.speak("คำที่ถูกต้องคือ $expected", rate: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (consonants.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('ฝึกอ่านสระเดี่ยว ป.1', style: GoogleFonts.mali()),
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(
          child: Text('ยังไม่มีข้อมูล', style: GoogleFonts.mali(fontSize: 18)),
        ),
      );
    }

    final data = consonants[currentIndex].data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ฝึกสระเดี่ยว ป.1', style: GoogleFonts.mali(fontSize: 18)),
            Text(
              'ข้อที่ ${currentIndex + 1} / ${consonants.length}',
              style: GoogleFonts.mali(fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.pink.shade100,
      ),
      backgroundColor: const Color(0xFFFFF8FC),
      body: LayoutBuilder(
        builder: (context, cons) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: cons.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🐈⋆୨୧˚ ให้นักเรียนอ่านสระเดี่ยวที่นักเรียนเห็นบนจอ',
                            style: GoogleFonts.mali(fontSize: 24),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: Text(
                              (data['letter'] ?? '').toString(),
                              style: GoogleFonts.mali(
                                fontSize: 100,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'คำ: ${data['word']}',
                                  style: GoogleFonts.mali(fontSize: 28),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'ออกเสียงว่า: ${data['example']}',
                                  style: GoogleFonts.mali(fontSize: 24),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          // ✅ ปุ่มฟังเสียง - ใช้ Google TTS
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.volume_up),
                              label: Text(
                                "ฟังเสียงอีกครั้ง",
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              onPressed: speakCurrentTts,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ✅ ปุ่มบันทึกเสียง - แบบเดียวกับ SpeechExerciseScreen
                          Center(
                            child: ElevatedButton.icon(
                              icon: Icon(isRecording ? Icons.stop : Icons.mic),
                              label: Text(
                                isRecording ? 'หยุด' : 'กดอ่าน',
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              onPressed:
                                  isRecording
                                      ? _stopRecording
                                      : _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isRecording
                                        ? Colors.green.shade100
                                        : Colors.blue.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ✅ แสดง processing
                          if (isProcessing)
                            Center(
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'กำลังประมวลผล...',
                                    style: GoogleFonts.mali(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          if (recognizedText.isNotEmpty && !isProcessing)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "คุณพูดว่า: $recognizedText",
                                    style: GoogleFonts.mali(fontSize: 18),
                                  ),
                                  const SizedBox(height: 10),
                                  if (showResult) ...[
                                    Icon(
                                      isCorrect
                                          ? Icons.check_circle
                                          : Icons.close,
                                      color:
                                          isCorrect ? Colors.green : Colors.red,
                                      size: 60,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      isCorrect
                                          ? "ถูกต้องแล้ว! กดถัดไปได้เลย"
                                          : (attempts >= _maxAttempts
                                              ? "ไม่เป็นไร ลองพูดใหม่อีกครั้งนะ"
                                              : "ลองใหม่อีกครั้ง ($attempts/$_maxAttempts)"),
                                      style: GoogleFonts.mali(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed:
                                    (currentIndex == consonants.length - 1 &&
                                            skippedIndices.isEmpty)
                                        ? null
                                        : _skip,
                                child: Text(
                                  '⏭️ ข้าม',
                                  style: GoogleFonts.mali(fontSize: 20),
                                ),
                              ),
                              ElevatedButton(
                                onPressed:
                                    _isFinalState
                                        ? (showResult && isCorrect
                                            ? (_submitted
                                                ? null
                                                : () async {
                                                  setState(
                                                    () => _submitted = true,
                                                  );
                                                  await saveQuizResult();
                                                  _showResultSheet();
                                                })
                                            : null)
                                        : (showResult && isCorrect
                                            ? _next
                                            : null),
                                child: Text(
                                  _isFinalState ? '✅ เสร็จสิ้น' : '➡️ ถัดไป',
                                  style: GoogleFonts.mali(fontSize: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showResult)
                Positioned(
                  bottom: 80,
                  right: 12,
                  child: Image.asset(
                    isCorrect
                        ? 'assets/images/happy.png'
                        : 'assets/images/wrong.png', // ✅ แก้ path
                    height: 200,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
