///ปจบ.ใช้หน้านี้
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizScreen extends StatefulWidget {
  final String set;
  final String classLevel;
  final String topicId;
  final String topicName;

  const QuizScreen({
    super.key,
    required this.set,
    required this.classLevel,
    required this.topicId,
    this.topicName = '',
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  int selectedIndex = -1;
  int totalScore = 0;

  String? username;
  bool isLoading = true;
  Timer? timer;
  int seconds = 20 * 60;
  List<Map<String, dynamic>> studentAnswers = [];
  List<int> skippedIndices = [];

  @override
  void initState() {
    super.initState();
    loadUsername();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    List<String> raw = [];
    if (data is List) {
      raw = data.map((e) => e.toString()).toList();
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          raw = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        raw = data
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return raw;
      }
    }
    return raw
        .map((e) => e.replaceAll('[', '').replaceAll(']', '').trim())
        .toList();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString("username");
    if (username == null) {
      showError("กรุณาเข้าสู่ระบบใหม่");
      return;
    }
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    try {
      final snapshot = await _firestore
          .collection('questions')
          .doc('g_${widget.classLevel}')
          .collection(widget.topicId)
          .where('set', isEqualTo: widget.set)
          .get();

      if (snapshot.docs.isEmpty) {
        showError("ไม่พบแบบทดสอบ");
        return;
      }

      questions = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // ✅✅✅ แก้ไข: รองรับทั้ง choices array และ choice1-4 ✅✅✅
        List<String> options = [];
        
        // ลองอ่านจาก choices ก่อน
        if (data.containsKey('choices')) {
          options = _parseStringList(data['choices']);
        }
        
        // ถ้า choices ว่าง ให้อ่านจาก choice1-4
        if (options.isEmpty) {
          if (data['choice1'] != null && data['choice1'].toString().isNotEmpty) {
            options.add(data['choice1'].toString());
          }
          if (data['choice2'] != null && data['choice2'].toString().isNotEmpty) {
            options.add(data['choice2'].toString());
          }
          if (data['choice3'] != null && data['choice3'].toString().isNotEmpty) {
            options.add(data['choice3'].toString());
          }
          if (data['choice4'] != null && data['choice4'].toString().isNotEmpty) {
            options.add(data['choice4'].toString());
          }
        }
        
        // Debug: แสดงข้อมูลที่โหลดได้
        debugPrint('📝 Question: ${data['question']}');
        debugPrint('📋 Options loaded: $options');
        debugPrint('✅ Answer: ${data['answer']}');
        
        return {
          "question": data['question'] ?? '',
          "paragraph": data['paragraph'] ?? '',
          "options": options,  // ✅ ใช้ options ที่สร้างขึ้น
          "correctAnswer": data['answer'] ?? '',
        };
      }).toList();

      setState(() => isLoading = false);
      startTimer();
    } catch (e) {
      debugPrint('❌ loadQuestions error: $e');
      showError("ไม่สามารถโหลดแบบทดสอบได้");
    }
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        finishQuiz();
      }
    });
  }

  // ข้ามข้อ
  void _skip() {
    if (!skippedIndices.contains(currentIndex)) {
      skippedIndices.add(currentIndex);
    }

    // หาข้อถัดไปที่ยังไม่ตอบและไม่ใช่ข้อปัจจุบัน
    int next = -1;
    for (int i = currentIndex + 1; i < questions.length; i++) {
      bool answered = studentAnswers.any((a) => a['number'] == i + 1);
      if (!answered) {
        next = i;
        break;
      }
    }

    // ถ้าหาไม่เจอข้างหน้า วนกลับมาข้อที่ข้ามไว้
    if (next == -1 && skippedIndices.isNotEmpty) {
      next = skippedIndices.first;
    }

    if (next != -1 && next != currentIndex) {
      setState(() {
        currentIndex = next;
        selectedIndex = -1;
      });
    } else {
      finishQuiz();
    }
  }

  // ถัดไป — บันทึกคำตอบแล้วไปข้อต่อ
  void _next() {
    final question = questions[currentIndex];
    String studentAnswer = selectedIndex != -1
        ? question["options"][selectedIndex]
        : '(ไม่ได้เลือก)';

    bool isCorrect = studentAnswer == question["correctAnswer"];
    if (isCorrect) totalScore += 2;

    studentAnswers.add({
      'number': currentIndex + 1,
      'paragraph': question['paragraph'],
      'question': question['question'],
      'studentAnswer': studentAnswer,
      'correctAnswer': question["correctAnswer"],
      'isCorrect': isCorrect,
    });

    skippedIndices.remove(currentIndex);

    // หาข้อถัดไปที่ยังไม่ตอบ
    int next = -1;
    for (int i = currentIndex + 1; i < questions.length; i++) {
      bool answered = studentAnswers.any((a) => a['number'] == i + 1);
      if (!answered) {
        next = i;
        break;
      }
    }

    // วนกลับข้อที่ข้ามไว้
    if (next == -1 && skippedIndices.isNotEmpty) {
      next = skippedIndices.first;
    }

    if (next != -1) {
      setState(() {
        currentIndex = next;
        selectedIndex = -1;
      });
    } else {
      finishQuiz();
    }
  }

  // ตรวจว่าเป็นข้อสุดท้ายที่เหลือหรือไม่
  bool get _isLastQuestion {
    int unanswered = 0;
    for (int i = 0; i < questions.length; i++) {
      bool answered = studentAnswers.any((a) => a['number'] == i + 1);
      if (!answered && i != currentIndex) unanswered++;
    }
    // กรองเอา currentIndex ออกจาก skippedIndices ก่อนเช็ค
  final otherSkipped = skippedIndices.where((i) => i != currentIndex).toList();
    return unanswered == 0 && otherSkipped.isEmpty;
  }

  void finishQuiz() async {
    timer?.cancel();
    await saveToFirebase();
    showResultDialog();
  }

  Future<void> saveToFirebase() async {
    if (username == null) return;
    try {
      int correctCount = studentAnswers.where((a) => a['isCorrect']).length;
      int wrongCount = studentAnswers.where((a) => !a['isCorrect']).length;

      await _firestore.collection('quiz_results').add({
        "username": username,
        "set": widget.set,
        "class_level": widget.classLevel,
        "topic_id": widget.topicId,
        "category": "แบบทดสอบ",
        "score": totalScore,
        "total": questions.length * 2,
        "correct_count": correctCount,
        "wrong_count": wrongCount,
        "answers": studentAnswers,
        "timestamp": Timestamp.now(),
        "time_taken": (20 * 60) - seconds,
        "wrong_answers": studentAnswers
            .where((a) => a['isCorrect'] == false)
            .map((a) => {
                  'index': a['number'],
                  'paragraph': a['paragraph'],
                  'question': a['question'],
                  'correct': a['correctAnswer'],
                  'answered': a['studentAnswer'],
                })
            .toList(),
      });

      debugPrint('✅ บันทึกผลสำเร็จ');
    } catch (e) {
      debugPrint('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  void showResultDialog() {
    int correctCount = studentAnswers.where((a) => a['isCorrect']).length;
    int wrongCount = studentAnswers.where((a) => !a['isCorrect']).length;
    int maxScore = questions.length * 2;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("เสร็จสิ้น", style: GoogleFonts.mali(fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ชุดที่ ${widget.set}",
                style: GoogleFonts.mali(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text(
                "คะแนน: $totalScore / $maxScore",
                style: GoogleFonts.mali(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Text("ถูก: $correctCount ข้อ", style: GoogleFonts.mali()),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 4),
                  Text("ผิด: $wrongCount ข้อ", style: GoogleFonts.mali()),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                totalScore >= (maxScore * 0.8) ? "🎉 ผ่าน!" : "📚 ควรทบทวนอีกครั้งนะ",
                style: GoogleFonts.mali(
                  fontSize: 16,
                  color: totalScore >= (maxScore * 0.8)
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (wrongCount > 0) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  "ข้อที่ตอบผิด:",
                  style: GoogleFonts.mali(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                const SizedBox(height: 8),
                ...studentAnswers
                    .where((ans) => ans['isCorrect'] == false)
                    .map((ans) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ข้อ ${ans['number']}',
                            style: GoogleFonts.mali(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (ans['paragraph'] != null &&
                            ans['paragraph'].toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAE0D8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.article,
                                        size: 16, color: Color(0xFFB0564A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'บทความ:',
                                      style: GoogleFonts.mali(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFB0564A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ans['paragraph'],
                                  style: GoogleFonts.mali(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          ans['question'],
                          style: GoogleFonts.mali(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.close,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'เลือก: ${ans['studentAnswer']}',
                                style: GoogleFonts.mali(
                                    fontSize: 13,
                                    color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.check,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'ถูกต้อง: ${ans['correctAnswer']}',
                                style: GoogleFonts.mali(
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text("กลับหน้าหลัก", style: GoogleFonts.mali()),
          ),
        ],
      ),
    );
  }

  void showError(String message) {
    setState(() => isLoading = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("เกิดข้อผิดพลาด", style: GoogleFonts.mali()),
        content: Text(message, style: GoogleFonts.mali()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text("ตกลง", style: GoogleFonts.mali()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text("แบบทดสอบ", style: GoogleFonts.mali()),
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(
          child: Text("ไม่พบแบบทดสอบ", style: GoogleFonts.mali(fontSize: 20)),
        ),
      );
    }

    final question = questions[currentIndex];
    

    return Scaffold(
      appBar: AppBar(
        title: Text("ชุดที่ ${widget.set}", style: GoogleFonts.mali(fontSize: 18)),
        backgroundColor: Colors.pink.shade100,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  "${(seconds ~/ 60)}:${(seconds % 60).toString().padLeft(2, '0')}",
                  style: GoogleFonts.mali(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ข้อที่ ${currentIndex + 1} / ${questions.length}",
                  style: GoogleFonts.mali(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF695A5B)),
                ),
                // แสดงจำนวนข้อที่ข้ามไว้
                if (skippedIndices.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "ข้ามไว้ ${skippedIndices.length} ข้อ",
                      style: GoogleFonts.mali(
                          fontSize: 13, color: Colors.orange.shade800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (question["paragraph"].toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                question["paragraph"],
                style: GoogleFonts.mali(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            if(question["paragraph"].toString().isNotEmpty)
            const SizedBox(height: 20),
            Text(
              question["question"],
              style: GoogleFonts.mali(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: question["options"].length,
                itemBuilder: (context, index) {
                  final option = question["options"][index];
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFAE0D8)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFAE0D8), width: 2),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.mali(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ปุ่มข้าม
                TextButton(
                  onPressed: _isLastQuestion ? null : _skip,
                  child: Text('⏭️ ข้าม', style: GoogleFonts.mali(fontSize: 20)),
                ),
                // ปุ่มถัดไป / สิ้นสุด
                ElevatedButton(
                  onPressed: selectedIndex == -1 ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAE0D8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLastQuestion ? '✅ สิ้นสุด' : '➡️ ถัดไป',
                    style: GoogleFonts.mali(
                        fontSize: 20, color: const Color(0xFF695A5B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}