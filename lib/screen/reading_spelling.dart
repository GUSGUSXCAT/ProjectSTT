import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

class ReadingandSpellingScreen extends StatefulWidget {
  const ReadingandSpellingScreen({super.key});

  @override
  State<ReadingandSpellingScreen> createState() =>
      _ReadingandSpellingScreenState();
}

class _ReadingandSpellingScreenState extends State<ReadingandSpellingScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
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
  String recognizedText = "";
  bool isReviewingSkipped = false;
  bool isSkippedWord = false;
  String? loggedInUsername;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    fetchWords();
    loadUsername();
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername = prefs.getString("loggedInUsername");
    });
  }

  Future<void> fetchWords() async {
    final snapshot = await _firestore
        .collection('questions')
        .doc('g_1')
        .collection('reading_spell')
        .orderBy(FieldPath.documentId)
        .get();

    setState(() {
      words = snapshot.docs;
      isLoading = false;
    });
  }

  Future<void> saveQuizResult() async {
    if (loggedInUsername == null) return;

    final userSnapshot = await _firestore
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
      "category": "อ่านสะกดคำ ป.1",
      "wrong_answers": wrongAnswers,
    });
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
                  style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text('ได้ $correctCount / $total', style: GoogleFonts.mali()),
                    ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                        ),
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
      submitted = false;

      currentIndex = 0;
      attempts = 0;
      correctCount = 0;

      recognizedText = "";
      wrongAnswers.clear();
      skippedIndices.clear();
    });
  }

  bool get isFinalQuestion {
    return (!isReviewingSkipped &&
            currentIndex == words.length - 1 &&
            skippedIndices.isEmpty) ||
        (isReviewingSkipped && skippedIndices.isEmpty);
  }

  void _next() async {
    if (!showResult) return;


    if (!isReviewingSkipped) {
      // ยังมีข้อถัดไป
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

      // หมดรอบแรก แต่มีข้อที่ข้ามไว้
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

      // จบจริง
      await saveQuizResult();
      _showResultSheet();
      return;
    }

    // เฉลยข้อที่ข้าม
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

    // จบข้าม
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

  int get maxAttempts => isSkippedWord ? 1 : 3;

  String removeSpaces(String text) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }

  List<String> getCorrectAnswers(Map<String, dynamic> doc) {
    final raw = doc['check'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.contains('|')) {
      return raw.split('|').map((e) => e.trim()).toList();
    }
    return [raw?.toString() ?? ''];
  }

    void _checkAnswer() async {
    _speech.stop();

    if (isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ตอบถูกแล้ว ไม่ต้องกดซ้ำ", style: GoogleFonts.mali())),
      );
      return;
    }

    final doc = words[currentIndex].data() as Map<String, dynamic>;
    final correctAnswers = getCorrectAnswers(doc);

    final userAnswer = removeSpaces(recognizedText);
    final wasCorrect = correctAnswers.any((c) => removeSpaces(c) == userAnswer);

    final newAttempts = attempts + 1;

    setState(() {
      isListening = false;
      attempts = newAttempts;
      showResult = true;
      isCorrect = wasCorrect;

      if (wasCorrect) {
  if (attempts <= maxAttempts) {
    correctCount++;
  }
  // ตอบถูกครั้งแรก
  if (attempts == 1) {
    wrongAnswers.removeWhere((m) => m['index'] == currentIndex + 1);
  }
      } else {
        // ผิด
        final idx = wrongAnswers.indexWhere((m) => m['index'] == currentIndex + 1);
        final wrongData = {
          "index": currentIndex + 1,
          "correct": correctAnswers.first,
          "recognized": recognizedText,
        };

        if (idx == -1) {
          wrongAnswers.add(wrongData);
        } else {
          wrongAnswers[idx] = wrongData;
        }

      
        if (attempts >= maxAttempts) {
          final k = wrongAnswers.indexWhere((m) => m['index'] == currentIndex + 1);
          if (k != -1) {
            wrongAnswers[k]["note"] = "พูดผิดเกิน $maxAttempts ครั้ง";
          }
        }
      }
    });

    if (!wasCorrect && newAttempts >= maxAttempts) {
      await _tts.setLanguage("th-TH");
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak("คำที่ถูกต้องคือ ${correctAnswers.first}");
    }
  }
  Future<void> speakCurrentTts() async {
    final ttsText = words[currentIndex]['tts_text'];
    await _tts.setLanguage("th-TH");
    await _tts.speak(ttsText);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('อ่านสะกดคำ ป.1', style: GoogleFonts.mali()),
          centerTitle: true,
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(
          child: Text('ยังไม่มีคำสำหรับชุดนี้', style: GoogleFonts.mali(fontSize: 18)),
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
                "อ่านสะกดคำ ป.1",
                style: GoogleFonts.mali(fontSize: 18),
              ),
            ),
           
          ],
        ),
      ),
      backgroundColor: const Color(0xFFFFF8FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: Text(
                              data['letter'],
                              style: GoogleFonts.mali(
                                fontSize: constraints.maxWidth > 600 ? 150 : 120,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  'สะกดว่า ${data['example']}',
                                  style: GoogleFonts.mali(fontSize: 24),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.volume_up),
                              label: Text("ฟังเสียงอีกครั้ง", style: GoogleFonts.mali(fontSize: 18)),
                              onPressed: speakCurrentTts,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.mic),
                              label: Text(
                                isListening ? "กำลังพูด..." : "คลิกเพื่อพูด",
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isListening ? Colors.green.shade100 : Colors.blue.shade50,
                              ),
                              onPressed: _startListening,
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
                                      isCorrect ? Icons.check_circle : Icons.close,
                                      color: isCorrect ? Colors.green : Colors.red,
                                      size: 60,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      isCorrect
                                          ? "ถูกต้องแล้ว!"
                                          : (attempts > maxAttempts
                                              ? "หมดโอกาสแล้ว แต่ยังกดตรวจได้นะ"
                                              : (attempts == maxAttempts
                                                  ? "ถึงเพดานความพยายาม"
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
                                    onPressed: isCorrect ? null : _checkAnswer,
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
                                onPressed: (currentIndex == words.length - 1 &&
                                        skippedIndices.isEmpty)
                                    ? null
                                    : _skip,
                                child: Text('⏭️ ข้าม', style: GoogleFonts.mali(fontSize: 20)),
                              ),
                              ElevatedButton(
                                onPressed: isFinalQuestion
                                    ? (showResult
                                        ? (submitted
                                            ? null
                                            : () async {
                                                setState(() => submitted = true);
                                                await saveQuizResult();
                                                _showResultSheet();
                                              })
                                        : null)
                                    : (showResult ? _next : null),
                                child: Text(
                                  isFinalQuestion ? '✅ เสร็จสิ้น' : '➡️ ถัดไป',
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