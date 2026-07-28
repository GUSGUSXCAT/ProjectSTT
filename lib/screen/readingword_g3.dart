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

// ✅ Google TTS Service
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

class ReadingWordG3Screen extends StatefulWidget {
  final String set;

  const ReadingWordG3Screen({super.key, required this.set});

  @override
  State<ReadingWordG3Screen> createState() => _ReadingWordG3ScreenState();
}

class _ReadingWordG3ScreenState extends State<ReadingWordG3Screen> {
  final GoogleTtsService _tts = GoogleTtsService();  // ✅ ใช้ Google TTS
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> words = [];
  List<int> skippedIndices = [];
  List<Map<String, dynamic>> wrongAnswers = [];

  int currentIndex = 0;
  int correctCount = 0;
  int attempts = 0;

  bool isLoading = true;
  bool isListening = false;
  bool showResult = false;
  bool isCorrect = false;

  String instruction = '';
  String recognizedText = "";
  bool _submitted = false;

  bool isReviewingSkipped = false;
  bool isSkippedWord = false;

  String? _audioPath;
  String? loggedInUsername;

  @override
  void initState() {
    super.initState();
    fetchWords();
    loadUsername();
  }

  @override
  void dispose() {
    _tts.dispose();  // ✅ dispose TTS
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");
    });
  }

  Future<void> fetchWords() async {
    try {
      final snap = await _firestore
          .collection('questions')
          .doc('g_3')
          .collection('reading_word')
          .where('set', isEqualTo: widget.set)
          .orderBy(FieldPath.documentId)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          isLoading = false;
          words = [];
        });
        return;
      }

      final data = snap.docs.first.data();
      instruction = (data['instruction'] ?? '').toString();

      setState(() {
        words = snap.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchWords error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> saveQuizResult() async {
    try {
      if (loggedInUsername == null) return;

      final userSnap = await _firestore
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
        "total": words.length,
        "timestamp": Timestamp.now(),
        "category": "แบบฝึกหัดอ่านคำ (ชุดที่ ${widget.set})",
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint('saveQuizResult error: $e');
    }
  }

  void _startListening() async {
    await _tts.stop();  // ✅ หยุด TTS ก่อนบันทึกเสียง

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("กรุณาอนุญาตไมโครโฟน", style: GoogleFonts.mali())),
      );
      return;
    }

    try {
      if (kIsWeb) {
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: '');
      } else {
        final directory = await getTemporaryDirectory();
        _audioPath = '${directory.path}/temp_audio.wav';
        await _audioRecorder.start(const RecordConfig(), path: _audioPath!);
      }

      setState(() {
        isListening = true;
        showResult = false;
        recognizedText = "กำลังฟัง...";
      });
    } catch (e) {
      debugPrint('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e", style: GoogleFonts.mali()), backgroundColor: Colors.red),
      );
    }
  }

  void _checkSpeech() async {
    final path = await _audioRecorder.stop();
    setState(() => isListening = false);

    if (path == null || path.isEmpty) {
      setState(() => recognizedText = "ไม่พบไฟล์เสียง");
      return;
    }

    if (isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ตอบถูกแล้ว ไม่ต้องกดซ้ำ", style: GoogleFonts.mali())),
      );
      return;
    }

    final doc = words[currentIndex].data() as Map<String, dynamic>;
    final expectedList = _expectedListFromDoc(doc);

    try {
      setState(() => recognizedText = "กำลังประมวลผล...");

      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/stt'));

      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        request.files.add(http.MultipartFile.fromBytes('audio', response.bodyBytes, filename: 'audio.wav'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', path));
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        var resData = await response.stream.bytesToString();
        var json = jsonDecode(resData);

        String serverText = json['text'] ?? "";
        final recNorm = _norm(serverText);
        bool wasCorrect = expectedList.any((c) => _norm(c) == recNorm);

        final maxAttempts = _maxAttempts;
        final nextAttempts = attempts + 1;

        setState(() {
          recognizedText = serverText;
          attempts = nextAttempts;
          showResult = true;
          isCorrect = wasCorrect;

          if (wasCorrect) {
            if (attempts <= maxAttempts) correctCount++;
            wrongAnswers.removeWhere((m) => m['index'] == currentIndex + 1);
          } else {
            final idx = wrongAnswers.indexWhere((m) => m['index'] == currentIndex + 1);
            final row = {
              "index": currentIndex + 1,
              "correct": expectedList.first,
              "recognized": recognizedText,
            };
            if (idx == -1) {
              wrongAnswers.add(row);
            } else {
              wrongAnswers[idx] = row;
            }
            if (attempts >= maxAttempts) {
              final k = wrongAnswers.indexWhere((m) => m['index'] == currentIndex + 1);
              if (k != -1) wrongAnswers[k]["note"] = "พูดผิดเกิน $maxAttempts ครั้ง";
            }
          }
        });

        // ✅ พูดเฉลยเมื่อหมดสิทธิ์ - ใช้ Google TTS
        if (!wasCorrect && nextAttempts >= maxAttempts) {
          await _tts.speak("คำที่ถูกต้องคือ ${expectedList.first}", rate: 0.5);
        }
      } else {
        setState(() => recognizedText = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('❌ Check speech error: $e');
      setState(() => recognizedText = "เชื่อมต่อ Server ไม่ได้: $e");
    }
  }

  void _showResultSheet() {
    final total = words.length;
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
                Text('สรุปคะแนน', style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(label: Text('ได้ $correctCount / $total', style: GoogleFonts.mali())),
                    const SizedBox(width: 8),
                    Chip(label: Text('$percent%', style: GoogleFonts.mali())),
                  ],
                ),
                const SizedBox(height: 12),
                if (wrongAnswers.isEmpty)
                  Text('เก่งมาก! ทำถูกทุกข้อ 🎉', style: GoogleFonts.mali(fontSize: 16))
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
                          'ข้อ ${w['index']}: พูดว่า "${w['recognized']}" | ควรพูด "${w['correct']}"',
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
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                        child: Text('ปิด', style: GoogleFonts.mali(color: Colors.white)),
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
  }

  bool get _isFinalState =>
      (!isReviewingSkipped && currentIndex == words.length - 1 && skippedIndices.isEmpty) ||
      (isReviewingSkipped && skippedIndices.isEmpty);

  void _next() async {
    if (!showResult) return;

    if (!isReviewingSkipped) {
      if (currentIndex < words.length - 1) {
        setState(() {
          currentIndex++;
          attempts = 0;
          recognizedText = "";
          isCorrect = false;
          showResult = false;
          isSkippedWord = false;
        });
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
      return;
    }

    await saveQuizResult();
    _showResultSheet();
  }

  void _skip() {
    if (!skippedIndices.contains(currentIndex)) {
      skippedIndices.add(currentIndex);
    }
    _next();
  }

  int get _maxAttempts => isSkippedWord ? 1 : 3;

  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '');

  List<String> _expectedListFromDoc(Map<String, dynamic> doc) {
    final raw = doc['check'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.contains('|')) {
      return raw.split('|').map((e) => e.trim()).toList();
    }
    return [raw?.toString() ?? ''];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('ฝึกหัดอ่านคำ ชุดที่ ${widget.set}', style: GoogleFonts.mali()),
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(child: Text('ยังไม่มีคำสำหรับชุดนี้', style: GoogleFonts.mali(fontSize: 18))),
      );
    }

    final data = words[currentIndex].data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                instruction.isEmpty ? 'กำลังโหลด...' : instruction,
                style: GoogleFonts.mali(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text('ข้อที่ ${currentIndex + 1} / ${words.length}', style: GoogleFonts.mali(fontSize: 18)),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, cons) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: cons.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🐈⋆୨୧˚ ให้นักเรียนอ่านคำที่เห็นบนจอ', style: GoogleFonts.mali(fontSize: 24)),
                          Center(
                            child: Text(
                              (data['example'] ?? '').toString(),
                              style: GoogleFonts.mali(fontSize: 100, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              '💡 ความหมายว่า: ${(data['meaning'] ?? '').toString()}',
                              style: GoogleFonts.mali(fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.menu_book),
                              label: Text('ฟังความหมาย', style: GoogleFonts.mali(fontSize: 18)),
                              // ✅ ใช้ Google TTS
                              onPressed: () async {
                                await _tts.speak((data['meaning'] ?? '').toString(), rate: 0.75);
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.mic),
                              label: Text(isListening ? 'กำลังพูด...' : 'คลิกเพื่อพูด', style: GoogleFonts.mali(fontSize: 18)),
                              onPressed: _startListening,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isListening ? Colors.green.shade100 : Colors.blue.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (recognizedText.isNotEmpty)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("คุณพูดว่า: $recognizedText", style: GoogleFonts.mali(fontSize: 18)),
                                  const SizedBox(height: 10),
                                  if (showResult) ...[
                                    Icon(isCorrect ? Icons.check_circle : Icons.close,
                                        color: isCorrect ? Colors.green : Colors.red, size: 60),
                                    const SizedBox(height: 10),
                                    Text(
                                      isCorrect
                                          ? "ถูกต้องแล้ว!"
                                          : (attempts > _maxAttempts
                                              ? "หมดโอกาสแล้ว แต่ยังกดตรวจได้นะ"
                                              : (attempts == _maxAttempts
                                                  ? "ถึงเพดานความพยายาม"
                                                  : "ลองใหม่อีกครั้ง")),
                                      style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: isCorrect ? null : _checkSpeech,
                                    child: Text("ตรวจ", style: GoogleFonts.mali(fontSize: 18)),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: (currentIndex == words.length - 1 && skippedIndices.isEmpty) ? null : _skip,
                                child: Text('⏭️ ข้าม', style: GoogleFonts.mali(fontSize: 20)),
                              ),
                              ElevatedButton(
                                onPressed: _isFinalState
                                    ? (showResult
                                        ? (_submitted ? null : () async {
                                            setState(() => _submitted = true);
                                            await saveQuizResult();
                                            _showResultSheet();
                                          })
                                        : null)
                                    : (showResult ? _next : null),
                                child: Text(_isFinalState ? '✅ เสร็จสิ้น' : '➡️ ถัดไป', style: GoogleFonts.mali(fontSize: 20)),
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
                    isCorrect ? 'assets/images/happy.png' : 'assets/images/wrong.png',  // ✅ แก้ path
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