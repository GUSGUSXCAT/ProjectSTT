import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'dart:convert';


class ShortSentencePracticeScreen extends StatefulWidget {
  final String set;

  const ShortSentencePracticeScreen({
    super.key,
    required this.set,
  });

  @override
  State<ShortSentencePracticeScreen> createState() =>
      _ShortSentencePracticeScreenState();
}

class _ShortSentencePracticeScreenState
    extends State<ShortSentencePracticeScreen> {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder(); 
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> sentences = [];
  
  List<int> skippedIndices = [];
  List<Map<String, dynamic>> wrongAnswers = [];

  int currentIndex = 0;
  int correctCount = 0;
  int attempts = 0;

  bool isLoading = true;
  bool isListening = false;
  bool showResult = false;
  bool isCorrect = false;

  bool _submitted = false;
  String recognizedText = "";

  bool isReviewingSkipped = false;
  bool isSkippedSentence = false;

  String? loggedInUsername;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    fetchSentences();
    loadUsername();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");
    });
  }

  Future<void> fetchSentences() async {
    try {
      final snap = await _firestore
          .collection('questions')
          .doc('g_3')
          .collection('short_sentences')
          .where('set', isEqualTo: widget.set)
          .orderBy(FieldPath.documentId)
          .get();

      setState(() {
        sentences = snap.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchSentences error: $e');
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
        "total": sentences.length,
        "timestamp": Timestamp.now(),
        "category": "ฝึกอ่านประโยคสั้น ชุดที่ ${widget.set}",
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint('saveQuizResult error: $e');
    }
  }

  // สรุปคะแนน
  void _showResultSheet() {
    final total = sentences.length;
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
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                         // Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
      isSkippedSentence = false;

      currentIndex = 0;
      attempts = 0;
      correctCount = 0;

      recognizedText = "";
      wrongAnswers.clear();
      skippedIndices.clear();
    });
  }

  bool get _isFinalState =>
      (!isReviewingSkipped &&
          currentIndex == sentences.length - 1 &&
          skippedIndices.isEmpty) ||
      (isReviewingSkipped && skippedIndices.isEmpty);

  void _next() async {
    if (!showResult) return;

    // โหมดทำรอบแรก
    if (!isReviewingSkipped) {
      // ยังมีข้อถัดไป
      if (currentIndex < sentences.length - 1) {
        setState(() {
          currentIndex++;
          attempts = 0;
          recognizedText = "";
          isCorrect = false;
          showResult = false;
          isSkippedSentence = false;
        });
        return;
      }

      // หมดรอบแรก แต่มีข้อที่ข้ามไว้
      if (skippedIndices.isNotEmpty) {
        setState(() {
          isReviewingSkipped = true;
          currentIndex = skippedIndices.removeAt(0);
          attempts = 0;
          recognizedText = "";
          isCorrect = false;
          showResult = false;
          isSkippedSentence = true;
        });
        return;
      }

      // จบจริง ๆ
      await saveQuizResult();
      _showResultSheet();
      return;
    }

    // โหมดเฉลยข้อที่ข้าม
    if (skippedIndices.isNotEmpty) {
      setState(() {
        currentIndex = skippedIndices.removeAt(0);
        attempts = 0;
        recognizedText = "";
        isCorrect = false;
        showResult = false;
        isSkippedSentence = true;
      });
      return;
    }

    // จบโหมดข้าม
    await saveQuizResult();
    _showResultSheet();
  }

  void _skip() {
    if (!skippedIndices.contains(currentIndex)) {
      skippedIndices.add(currentIndex);
    }
    _next();
  }

  void _startListening() async {
    debugPrint('🎤 _startListening called');

    final hasPermission = await _audioRecorder.hasPermission();
    debugPrint('🎤 hasPermission: $hasPermission');

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("กรุณาอนุญาตไมโครโฟน", style: GoogleFonts.mali())),
      );
      return;
    }

    try {
      
      if (kIsWeb) {
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '',
        );
      } else {
        
        final directory = await getTemporaryDirectory();
        _audioPath = '${directory.path}/temp_audio.wav';
        await _audioRecorder.start(const RecordConfig(), path: _audioPath!);
      }

      debugPrint('✅ Recording started');
      setState(() {
        isListening = true;
        showResult = false;
        recognizedText = "กำลังฟัง...";
      });
    } catch (e) {
      debugPrint('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("เกิดข้อผิดพลาด: $e", style: GoogleFonts.mali()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int get _maxAttempts => isSkippedSentence ? 1 : 3;

  String _norm(String s) {
    return s.replaceAll(RegExp(r'\s+'), ''); // ตัดช่องว่าง
  }

  // รองรับ check เป็น string, list หรือ string คั่นด้วย |
  List<String> _expectedListFromDoc(Map<String, dynamic> doc) {
    final raw = doc['check'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.contains('|')) {
      return raw.split('|').map((e) => e.trim()).toList();
    }
    return [raw?.toString() ?? ''];
  }

    void _checkSpeech() async {
    final path = await _audioRecorder.stop();
    setState(() => isListening = false);

    if (path == null || path.isEmpty) {
      setState(() => recognizedText = "ไม่พบไฟล์เสียง");
      return;
    }

    debugPrint('📁 Audio path: $path');

    if (isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ตอบถูกแล้ว ไม่ต้องกดซ้ำ", style: GoogleFonts.mali()),
        ),
      );
      return;
    }

    final doc = sentences[currentIndex].data() as Map<String, dynamic>;
    final expectedList = _expectedListFromDoc(doc);
    

    try {
      setState(() => recognizedText = "กำลังประมวลผล...");

      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/stt'),
      );

      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          response.bodyBytes,
          filename: 'audio.wav',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', path));
      }

      // ไม่ต้องส่ง expected_text และ method ไปที่ server

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
            if (attempts <= maxAttempts) {
              correctCount++;
            }
            wrongAnswers.removeWhere((m) => m['index'] == currentIndex + 1);
          } else {
            // upsert รายการผิดของข้อนี้
            final idx = wrongAnswers.indexWhere(
              (m) => m['index'] == currentIndex + 1,
            );
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
              final k = wrongAnswers.indexWhere(
                (m) => m['index'] == currentIndex + 1,
              );
              if (k != -1) {
                wrongAnswers[k]["note"] = "พูดผิดเกิน $maxAttempts ครั้ง";
              }
            }
          }
        });

        if (!wasCorrect && nextAttempts >= maxAttempts) {
          await _tts.setLanguage("th-TH");
          await _tts.setSpeechRate(0.5);
          await _tts.awaitSpeakCompletion(true);
          await _tts.speak("คำที่ถูกต้องคือ ${expectedList.first}");
        }
      } else {
         setState(() => recognizedText = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('❌ Check speech error: $e');
      setState(() => recognizedText = "เชื่อมต่อ Server ไม่ได้: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (sentences.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'ฝึกอ่านประโยคสั้น ๆ ป.3 ชุดที่ ${widget.set}',
            style: GoogleFonts.mali(),
          ),
          backgroundColor: Colors.deepOrange.shade100,
        ),
        body: Center(
          child: Text(
            'ยังไม่มีประโยคสำหรับชุดนี้',
            style: GoogleFonts.mali(fontSize: 18),
          ),
        ),
      );
    }

    final data = sentences[currentIndex].data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange.shade100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ฝึกอ่านประโยคสั้น ๆ ป.3 ชุดที่ ${widget.set}',
              style: GoogleFonts.mali(fontSize: 18),
            ),
            Text(
              'ข้อที่ ${currentIndex + 1} / ${sentences.length}',
              style: GoogleFonts.mali(fontSize: 18),
            ),
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
                          Text(
                            ' 📖 ให้นักเรียนอ่านประโยคที่เห็นบนจอ',
                            style: GoogleFonts.mali(fontSize: 24),
                          ),
                          const SizedBox(height: 60),
                          Center(
                            child: Text(
                              (data['sentence'] ?? '').toString(),
                              style: GoogleFonts.mali(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 60),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.mic),
                              label: Text(
                                isListening ? 'กำลังพูด...' : 'คลิกเพื่อพูด',
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              onPressed: _startListening,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isListening
                                    ? Colors.green.shade100
                                    : Colors.blue.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (recognizedText.isNotEmpty)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "คุณพูดว่า: $recognizedText",
                                    style: GoogleFonts.mali(fontSize: 18),
                                    textAlign: TextAlign.center,
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
                                          ? "ถูกต้องแล้ว!"
                                          : (attempts > _maxAttempts
                                              ? "หมดโอกาสแล้ว แต่ยังกดตรวจได้นะ"
                                              : (attempts == _maxAttempts
                                                  ? "ยังไม่ถูกนะ"
                                                  : "ลองใหม่อีกครั้ง")),
                                      style: GoogleFonts.mali(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: isCorrect ? null : _checkSpeech,
                                    child: Text(
                                      "ตรวจ",
                                      style: GoogleFonts.mali(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: (currentIndex ==
                                            sentences.length - 1 &&
                                        skippedIndices.isEmpty)
                                    ? null
                                    : _skip,
                                child: Text(
                                  '⏭️ ข้าม',
                                  style: GoogleFonts.mali(fontSize: 20),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isFinalState
                                    ? (showResult
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
                                    : (showResult ? _next : null),
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

              // รูปฟีดแบ็ก
              if (showResult)
                Positioned(
                  bottom: 80,
                  right: 12,
                  child: Image.asset(
                    isCorrect ? 'images/happy.png' : 'images/wrong.png',
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