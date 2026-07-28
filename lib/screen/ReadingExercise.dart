import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

class ReadingExercise extends StatefulWidget {
  final String grade;
  final String topicId;
  final String topicName;
  final String type;
  final String set;

  const ReadingExercise({
    super.key,
    required this.grade,
    required this.topicId,
    required this.topicName,
    required this.type,
    required this.set,
  });

  @override
  State<ReadingExercise> createState() => _ReadingExerciseState();
}

class _ReadingExerciseState extends State<ReadingExercise> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();

static const String _ttsBaseUrl = 'https://noneligibly-lathiest-zana.ngrok-free.dev';
final AudioPlayer _audioPlayer = AudioPlayer();


  List<int> skippedIndices = [];
  List<DocumentSnapshot> words = [];
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
  bool isSkippedWord = false;

  String? loggedInUsername;


  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

Future<void> _speak(String text, {String rate = '+0%'}) async {
  if (text.isEmpty) return;

  try {
    final response = await http.post(
      Uri.parse('$_ttsBaseUrl/tts-base64'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'text': text,
        'voice': 'premwadee',
        'rate': rate,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final audioBase64 = data['audio'] as String;
      
      await _audioPlayer.play(UrlSource('data:audio/mp3;base64,$audioBase64'));
    }
  } catch (e) {
    debugPrint('❌ TTS Error: $e');
  }
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
      final gradeKey = widget.grade.replaceAll('ป.', 'g_');

      final snapshot =
          await _firestore
              .collection('questions')
              .doc(gradeKey)
              .collection(widget.topicId)
              .where('type', isEqualTo: widget.type)
              .where('set', isEqualTo: widget.set)
              .where('mode', isEqualTo: 'reading')
              .orderBy(FieldPath.documentId)
              .get();

      setState(() {
        words = snapshot.docs;
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

      final userSnapshot =
          await _firestore
              .collection("users")
              .where("username", isEqualTo: loggedInUsername)
              .limit(1)
              .get();

      if (userSnapshot.docs.isEmpty) return;

      final userData = userSnapshot.docs.first.data();
      final fullName = "${userData["first_name"]} ${userData["last_name"]}";

      await _firestore.collection('quiz_results').add({
        "username": loggedInUsername,
        "full_name": fullName,
        "score": correctCount,
        "total": words.length,
        "timestamp": Timestamp.now(),
        "category":
            "${widget.topicName} (ประเภท ${widget.type} ชุดที่ ${widget.set})",
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint('saveQuizResult error: $e');
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
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          Navigator.pop(context);
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
      isSkippedWord = false;
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
          currentIndex == words.length - 1 &&
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

  void _startListening() async {
    await _audioPlayer.stop();

    final ok = await _speech.initialize();
    if (ok) {
      setState(() {
        isListening = true;
        showResult = false;
        recognizedText = "";
      });

      _speech.listen(
        localeId: 'th-TH',
        onResult: (res) {
          setState(() {
            recognizedText = res.recognizedWords.trim();
          });
        },
      );
    }
  }

  int get _maxAttempts => isSkippedWord ? 1 : 3;

  String _norm(String s) {
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  List<String> _expectedListFromDoc(Map<String, dynamic> doc) {
    final raw = doc['check'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.contains('|')) {
      return raw.split('|').map((e) => e.trim()).toList();
    }
    return [raw?.toString() ?? ''];
  }

  void _checkSpeech() async {
    _speech.stop();

    if (isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ตอบถูกแล้ว ไม่ต้องกดซ้ำ", style: GoogleFonts.mali()),
        ),
      );
      return;
    }

    final doc = words[currentIndex].data() as Map<String, dynamic>;
    final expectedList = _expectedListFromDoc(doc);

    final recNorm = _norm(recognizedText);
    final wasCorrect = expectedList.any((c) => _norm(c) == recNorm);

    final maxAttempts = _maxAttempts;
    final nextAttempts = attempts + 1;

    setState(() {
      isListening = false;
      attempts = nextAttempts;
      showResult = true;
      isCorrect = wasCorrect;

      if (wasCorrect) {
        if (attempts <= maxAttempts) {
          correctCount++;
        }
      } else {
        wrongAnswers.add({
          "index": currentIndex + 1,
          "correct": expectedList.first,
          "recognized": recognizedText,
          "attempt": nextAttempts,
          "note":
              nextAttempts >= maxAttempts ? "พยายาม $nextAttempts ครั้ง" : null,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "${widget.topicName} - อ่านออกเสียง",
            style: GoogleFonts.mali(),
          ),
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(
          child: Text(
            'ยังไม่มีคำสำหรับชุดนี้',
            style: GoogleFonts.mali(fontSize: 18),
          ),
        ),
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
                "${widget.topicName} (ประเภท ${widget.type} ชุดที่ ${widget.set})",
                style: GoogleFonts.mali(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'ข้อที่ ${currentIndex + 1} / ${words.length}',
              style: GoogleFonts.mali(fontSize: 16),
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
                            ' 🐈⋆୨୧˚ ให้นักเรียนอ่านคำที่เห็นบนจอ',
                            style: GoogleFonts.mali(fontSize: 24),
                          ),
                          Center(
                            child: Text(
                              (data['example'] ?? data['word'] ?? '')
                                  .toString(),
                              style: GoogleFonts.mali(
                                fontSize: 80,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (data['meaning'] != null)
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    '💡 ความหมายว่า: ${data['meaning']}',
                                    style: GoogleFonts.mali(fontSize: 20),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (data['meaning'] != null)
                            Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.volume_up),
                                label: Text(
                                  'ฟังความหมาย',
                                  style: GoogleFonts.mali(fontSize: 18),
                                ),
                                // ✅ กดแล้วพูดเลย - ง่ายๆ
                                onPressed:
                                    () => _speak(
                                      (data['meaning'] ?? '').toString(),
                                      rate: '+0%',
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.mic),
                              label: Text(
                                isListening ? 'กำลังพูด...' : 'คลิกเพื่อพูด',
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              onPressed: _startListening,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isListening
                                        ? Colors.green.shade100
                                        : Colors.blue.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                          ? "ถูกต้องแล้ว! กดถัดไปได้เลย"
                                          : (attempts >= _maxAttempts
                                              ? "ไม่เป็นไร ลองพูดใหม่อีกครั้งนะ"
                                              : "ลองใหม่อีกครั้ง (${attempts}/${_maxAttempts})"),
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
                                onPressed:
                                    (currentIndex == words.length - 1 &&
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
