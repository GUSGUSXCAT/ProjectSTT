///ปจบ.ใช้หน้านี้
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:LumoRead/screen/exercise_guidedialog.dart';

class DragDropExerciseScreen extends StatefulWidget {
  final String grade;
  final String topicId;
  final String topicName;
  final String? set;

  const DragDropExerciseScreen({
    Key? key,
    required this.grade,
    required this.topicId,
    required this.topicName,
    this.set,
  }) : super(key: key);

  @override
  State<DragDropExerciseScreen> createState() => _DragDropExerciseScreenState();
}

class _DragDropExerciseScreenState extends State<DragDropExerciseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String title = '';
  String instruction = '';
  String dragDropMode = 'fill_blanks';

  List<String> choices = [];
  Map<String, int> totalChoicesCount = {};
  Map<String, int> usedChoices = {};

  List<Map<String, dynamic>> questions = [];
  Map<int, List<String?>> userAnswers = {};
  Map<int, List<String>> correctAnswers = {};

  bool showResult = false;
  List<Map<String, dynamic>> wrongAnswers = [];
  String? loggedInUsername;

  final RegExp _blankRe = RegExp(r'\.{3,}');

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) =>
    ExerciseGuideDialog.show(context, mode: 'drag_drop'));
    _fetchQuestions();

  }

  /// แยกประโยคกับช่องว่าง
  ({List<String> parts, int blankCount}) _splitBlanks(String s) {
    final parts = <String>[];
    int last = 0, blanks = 0;
    for (final m in _blankRe.allMatches(s)) {
      parts.add(s.substring(last, m.start));
      last = m.end;
      blanks++;
    }
    parts.add(s.substring(last));
    return (parts: parts, blankCount: blanks);
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
        raw =
            data
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

  void _debugCheckData() {
    debugPrint('=== DEBUG INFO ===');
    debugPrint('Questions count: ${questions.length}');
    for (int i = 0; i < questions.length; i++) {
      final sentence = questions[i]['sentence'] as String;
      final blanks = _splitBlanks(sentence).blankCount;
      final userAnsLen = userAnswers[i]?.length ?? 0;
      final correctLen = correctAnswers[i]?.length ?? 0;

      debugPrint('Question $i:');
      debugPrint('  Sentence: "$sentence"');
      debugPrint('  Blanks: $blanks');
      debugPrint('  userAnswers length: $userAnsLen');
      debugPrint('  correctAnswers length: $correctLen');

      if (blanks != userAnsLen) {
        debugPrint('  ⚠️ WARNING: blanks($blanks) != userAnswers($userAnsLen)');
      }
      if (blanks != correctLen && blanks > 0) {
        debugPrint(
          '  ⚠️ WARNING: blanks($blanks) != correctAnswers($correctLen)',
        );
      }
    }
    debugPrint('=== END DEBUG ===');
  }

  Future<void> _fetchQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");

      final gradeKey = 'g_${widget.grade}';

      // Query ข้อมูล
      Query query = _firestore
          .collection('questions')
          .doc(gradeKey)
          .collection(widget.topicId)
          .where('mode', isEqualTo: 'drag_drop');

      // ถ้ามี set ให้ filter ตาม set
      if (widget.set != null) {
        query = query.where('set', isEqualTo: widget.set);
      }

      final snap = await query.limit(1).get();

      if (snap.docs.isEmpty) {
        debugPrint('❌ No documents found');
        return;
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;

      title = (data['title'] ?? widget.topicName).toString();
      instruction = (data['instruction'] ?? '').toString();
      dragDropMode = (data['drag_drop_mode'] ?? 'fill_blanks').toString();

      // โหลด choices
      choices = _parseStringList(data['choices']);
      totalChoicesCount.clear();
      for (final w in choices) {
        totalChoicesCount[w] = (totalChoicesCount[w] ?? 0) + 1;
      }
      usedChoices.clear();

      // จัดการ questions ที่อาจจะเป็น String หรือ List
      List<dynamic> rawQuestions = [];

      if (data['questions'] is String) {
        // ถ้า questions เป็น String, แปลงเป็น List
        try {
          final String questionsString = data['questions'] as String;
          debugPrint('📥 questions string: $questionsString');

          // ลอง parse JSON โดยตรง
          try {
            final dynamic parsed = jsonDecode(questionsString);
            if (parsed is List) {
              rawQuestions = parsed;
            } else {
              debugPrint('❌ parsed is not a List: ${parsed.runtimeType}');
              rawQuestions = [];
            }
          } catch (e) {
            debugPrint('⚠️ Direct JSON parse failed, trying regex: $e');
            final RegExp jsonArrayRegex = RegExp(r'\[.*\]', dotAll: true);
            final match = jsonArrayRegex.firstMatch(questionsString);

            if (match != null) {
              final jsonArrayString = match.group(0)!;
              final List<dynamic> parsedList = jsonDecode(jsonArrayString);
              rawQuestions = parsedList;
            } else {
              debugPrint(
                '❌ Could not extract JSON array from: $questionsString',
              );
              rawQuestions = [];
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing questions JSON: $e');
          rawQuestions = [];
        }
      } else if (data['questions'] is List) {
        // ถ้า questions เป็น List อยู่แล้ว
        rawQuestions = data['questions'] as List;
        debugPrint('questions is List with ${rawQuestions.length} items');
      } else {
        debugPrint(
          '❌ questions is unexpected type: ${data['questions'].runtimeType}',
        );
        rawQuestions = [];
      }

      questions.clear();
      correctAnswers.clear();
      userAnswers.clear();

      debugPrint('Processing ${rawQuestions.length} questions');

      for (int i = 0; i < rawQuestions.length; i++) {
        final item = rawQuestions[i];

        Map<String, dynamic> q;
        if (item is Map) {
          q = Map<String, dynamic>.from(item);
        } else if (item is String) {
          try {
            final parsed = jsonDecode(item);
            if (parsed is Map) {
              q = Map<String, dynamic>.from(parsed);
            } else {
              debugPrint(
                '❌ Question $i is string but not a JSON object: $item',
              );
              continue;
            }
          } catch (e) {
            debugPrint('❌ Question $i is invalid JSON string: $item');
            continue;
          }
        } else {
          debugPrint('❌ Question $i is unexpected type: ${item.runtimeType}');
          continue;
        }

        final sentence = (q['sentence'] ?? '').toString();
        if (sentence.trim().isEmpty) {
          debugPrint('⚠️ Question $i has empty sentence');
          continue;
        }

        questions.add({'index': i, 'sentence': sentence});

        final answers = q['answers'];
        final List<String> correctList;

        if (answers is List) {
          correctList = List<String>.from(
            answers.map((e) => e?.toString() ?? ''),
          );
        } else if (answers != null) {
          correctList = [answers.toString()];
        } else {
          correctList = [];
        }
        final blanks = _splitBlanks(sentence).blankCount;
        final finalCorrectList =
            (correctList.length == 1 && blanks > 1)
                ? correctList.first
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : correctList;
        correctAnswers[i] = finalCorrectList;

        // ตรวจสอบความถูกต้องของข้อมูล
        if (blanks > 0 && correctList.length != blanks) {
          debugPrint(
            '⚠️ Warning: Question $i has $blanks blanks but ${correctList.length} answers',
          );
        }

        // ใช้จำนวนช่องว่างเป็นหลัก ถ้าไม่มีช่องว่างให้ใช้จำนวนคำตอบ
        final len = blanks > 0 ? blanks : correctList.length;

        // สร้าง userAnswers ให้มีขนาดที่ถูกต้อง
        if (len > 0) {
          userAnswers[i] = List<String?>.filled(len, null);
        } else {
          debugPrint('⚠️ Question $i has no blanks and no answers, skipping');
          continue;
        }

        debugPrint(
          ' Processed question $i: "$sentence" with $len blanks and ${correctList.length} answers',
        );
      }

      debugPrint('Loaded ${questions.length} questions successfully');

      _debugCheckData();

      setState(() {});
    } catch (e) {
      debugPrint('❌ fetch error: $e');
    }
  }

  Future<void> _saveQuizResult(int score) async {
    try {
      if (loggedInUsername == null || loggedInUsername!.isEmpty) return;

      String fullName = "ไม่ทราบชื่อเต็ม";
      final userSnapshot =
          await _firestore
              .collection("users")
              .where("username", isEqualTo: loggedInUsername)
              .limit(1)
              .get();
      if (userSnapshot.docs.isNotEmpty) {
        final u = userSnapshot.docs.first.data();
        fullName = "${u["first_name"]} ${u["last_name"]}";
      }

      await _firestore.collection('quiz_results').add({
        "username": loggedInUsername,
        "full_name": fullName,
        "score": score,
        "total": questions.length,
        "timestamp": Timestamp.now(),
        "category": widget.topicName,
        "topic_id": widget.topicId,
        "grade": widget.grade,
        "set": widget.set,
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint("❌ save result error: $e");
    }
  }

  void _resetQuiz() {
    setState(() {
      showResult = false;
      wrongAnswers.clear();
      usedChoices.clear();
      for (int i = 0; i < questions.length; i++) {
        final len = userAnswers[i]?.length ?? 0;
        if (len > 0) {
          userAnswers[i] = List<String?>.filled(len, null);
        }
      }
    });
  }

  void _showResultSheet(int score) {
    final total = questions.length;
    final percent = total == 0 ? 0 : ((score * 100) / total).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'สรุปคะแนน',
                    style: GoogleFonts.mali(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        'ได้ $score / $total',
                        style: GoogleFonts.mali(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text('$percent%', style: GoogleFonts.mali())),
                  ],
                ),
                const SizedBox(height: 12),
                if (wrongAnswers.isEmpty)
                  Center(
                    child: Text(
                      'เก่งมาก! ทำถูกทุกข้อ 🎉',
                      style: GoogleFonts.mali(fontSize: 16),
                    ),
                  )
                else ...[
                  Text(
                    'ข้อที่ทำพลาด',
                    style: GoogleFonts.mali(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: wrongAnswers.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (_, i) {
                        final w = wrongAnswers[i];
                        return Text(
                          'ข้อ ${w['index']}: ตอบ ${w['answered']}  |  เฉลย ${w['correct']}',
                          style: GoogleFonts.mali(fontSize: 14),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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

  Future<void> _checkAnswers() async {
    // ตรวจสอบว่าผู้ใช้ตอบครบทุกช่องหรือไม่
    bool hasEmpty = false;
    for (int i = 0; i < questions.length; i++) {
      final answers = userAnswers[i];
      if (answers == null) {
        hasEmpty = true;
        break;
      }
      if (answers.any((e) => e == null)) {
        hasEmpty = true;
        break;
      }
    }

    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📣 กรุณาเติมคำให้ครบทุกช่อง',
            style: GoogleFonts.mali(),
          ),
        ),
      );
      return;
    }

    int score = 0;
    wrongAnswers.clear();

    for (int i = 0; i < questions.length; i++) {
      final correct = correctAnswers[i] ?? <String>[];
      final filled = userAnswers[i] ?? <String?>[];

      bool ok = true;
      // ตรวจสอบทีละช่อง
      for (int j = 0; j < correct.length; j++) {
        if (j >= filled.length) {
          ok = false;
          break;
        }
        final ans = filled[j] ?? '';
        if (ans != correct[j]) {
          ok = false;
          break;
        }
      }

      if (ok && filled.length == correct.length) {
        score++;
      } else {
        wrongAnswers.add({
          'index': i + 1,
          'correct': correct.join(', '),
          'answered': filled.map((e) => e ?? '-').join(', '),
        });
      }
    }

    setState(() => showResult = true);
    await _saveQuizResult(score);
    if (mounted) _showResultSheet(score);
  }

  Widget _buildSentence(int index, String sentence, double fontSize) {
    final split = _splitBlanks(sentence);
    final parts = split.parts;
    final blanks = userAnswers[index] ?? <String?>[];

    final spans = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(
        TextSpan(text: parts[i], style: GoogleFonts.mali(fontSize: fontSize)),
      );

      if (i < blanks.length) {
        final answer = blanks[i];
        final correctList = correctAnswers[index] ?? const <String>[];
        final correctHere = i < correctList.length ? correctList[i] : '';
        final isRight = (answer ?? '') == correctHere;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              // แตะเพื่อลบคำคืนคลัง
              onTap: () {
                if (showResult || answer == null) return;
                setState(() {
                  final String a = answer!;
                  usedChoices[a] = (usedChoices[a] ?? 1) - 1;
                  if ((usedChoices[a] ?? 0) <= 0) usedChoices.remove(a);
                  userAnswers[index]![i] = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      answer == null
                          ? Colors.grey[200]
                          : (showResult
                              ? (isRight
                                  ? Colors.green.shade100
                                  : Colors.red.shade100)
                              : Colors.white),
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DragTarget<String>(
                  builder: (context, c, r) {
                    return Text(
                      answer ?? 'วางคำ',
                      style: GoogleFonts.mali(fontSize: fontSize),
                    );
                  },
                  onAccept: (received) {
                    if (received.isEmpty) return;
                    setState(() {
                      // ถ้ามีคำเก่าอยู่แล้ว คืนจำนวนก่อน
                      final old = userAnswers[index]![i];
                      if (old != null) {
                        usedChoices[old] = (usedChoices[old] ?? 1) - 1;
                        if ((usedChoices[old] ?? 0) <= 0) {
                          usedChoices.remove(old);
                        }
                      }
                      // วางคำใหม่
                      userAnswers[index]![i] = received;
                      usedChoices[received] = (usedChoices[received] ?? 0) + 1;
                    });
                  },
                ),
              ),
            ),
          ),
        );
      }
    }

    final userJoined = (userAnswers[index] ?? const <String?>[])
        .map((e) => e ?? '')
        .join('|');
    final correctJoined = (correctAnswers[index] ?? const <String>[]).join('|');
    final allCorrect = showResult && userJoined == correctJoined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อ ${index + 1}',
            style: GoogleFonts.mali(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          RichText(text: TextSpan(children: spans)),
          if (showResult && !allCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '❌ คำตอบที่ถูก: ${(correctAnswers[index] ?? const <String>[]).join(', ')}',
                style: GoogleFonts.mali(color: Colors.red, fontSize: fontSize),
              ),
            ),
        ],
      ),
    );
  }

  //ตัวเลือกคำแบบ Wrap
  Widget _buildChoicesWrap(double fontSize) {
    final chips = <Widget>[];
    totalChoicesCount.forEach((word, total) {
      final used = usedChoices[word] ?? 0;
      if (used >= total) return;
      chips.add(
        Draggable<String>(
          data: word,
          feedback: Material(
            color: Colors.transparent,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
            ),
          ),
          child: Chip(
            label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
          ),
        ),
      );
    });
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildLeftContent(double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (instruction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              ' 📝·˚ˎˊ˗ $instruction',
              style: GoogleFonts.mali(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ...questions.map(
          (q) => _buildSentence(
            q['index'] as int,
            q['sentence'] as String,
            fontSize,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: showResult ? null : _checkAnswers,
            child: Text(
              'ตรวจคำตอบ',
              style: GoogleFonts.mali(fontSize: fontSize, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRightPanel(double fontSize) {
    final used = usedChoices.values.fold<int>(0, (s, v) => s + v);
    final total = totalChoicesCount.values.fold<int>(0, (s, v) => s + v);
    final remain = total - used;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คลังคำ',
              style: GoogleFonts.mali(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: SingleChildScrollView(child: _buildChoicesWrap(fontSize)),
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('เหลือ $remain', style: GoogleFonts.mali())),
                Chip(label: Text('ใช้ไป $used', style: GoogleFonts.mali())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetQuiz,
                    child: Text('ทำใหม่', style: GoogleFonts.mali()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: showResult ? null : _checkAnswers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                    ),
                    child: Text(
                      'ตรวจคำตอบ',
                      style: GoogleFonts.mali(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: Image.asset(
                'images/reading.png',
                width: 120,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final fontSize = w < 480 ? 16.0 : 20.0;
    final isWide = w >= 900; // จอกว้างค่อยแยก 2

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade200,
        title: Text(
          title.isEmpty ? 'กำลังโหลด...' : title,
          style: GoogleFonts.mali(fontSize: fontSize),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child:
            questions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : isWide
                // จอกว้าง
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: _buildLeftContent(fontSize),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRightPanel(fontSize),
                      ),
                    ),
                  ],
                )
                // จอแคบ
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (instruction.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            ' 📝·˚ˎˊ˗ $instruction',
                            style: GoogleFonts.mali(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _buildChoicesWrap(fontSize),
                      const SizedBox(height: 14),
                      ...questions.map(
                        (q) => _buildSentence(
                          q['index'] as int,
                          q['sentence'] as String,
                          fontSize,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: showResult ? null : _checkAnswers,
                          child: Text(
                            'ตรวจคำตอบ',
                            style: GoogleFonts.mali(
                              fontSize: fontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'images/reading.png',
                          width: 110,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
      ),
    );
  }
}
