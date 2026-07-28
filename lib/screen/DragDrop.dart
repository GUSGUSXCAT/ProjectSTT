import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DragDropScreen extends StatefulWidget {
  final String set;
  const DragDropScreen({Key? key, required this.set}) : super(key: key);

  @override
  State<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends State<DragDropScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String title = '';
  String instruction = '';

  // ตัวเลือกคำทั้งหมด (จากfs)
  List<String> choices = [];

  // นับจำนวนคำซ้ำทั้งหมด และคำที่ใช้แล้ว
  Map<String, int> totalChoicesCount = {};
  Map<String, int> usedChoices = {};

  // โจทย์ และคำตอบ
  List<Map<String, dynamic>> questions = [];
  Map<int, List<String?>> userAnswers = {};
  Map<int, List<String>> correctAnswers = {};

  // แสดงผลหลังตรวจ และเก็บข้อที่ผิด
  bool showResult = false;
  List<Map<String, dynamic>> wrongAnswers = [];

  // ไว้บันทึกชื่อผู้ใช้จาก login
  String? loggedInUsername;

  // ใช้ regex แยกช่องว่าง (จุดติดกัน >=3 ตัว)
  final RegExp _blankRe = RegExp(r'\.{3,}');
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

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // บางหน้าบันทึกเป็น loggedinuser บางหน้า username เลยลองดึงทั้งคู่
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");

      final snap =
          await _firestore
              .collection('questions')
              .doc('g_2')
              .collection('drag_drop')
              .where('set', isEqualTo: widget.set)
              .limit(1)
              .get();

      if (snap.docs.isEmpty) return;

      final data = snap.docs.first.data();

      title = (data['title'] ?? '').toString();
      instruction = (data['instruction'] ?? '').toString();

      // โหลด choices แล้วนับของซ้ำ
      choices = List<String>.from(data['choices'] ?? []);
      totalChoicesCount.clear();
      for (final w in choices) {
        totalChoicesCount[w] = (totalChoicesCount[w] ?? 0) + 1;
      }
      usedChoices.clear();

      // โหลดโจทย์
      final List<dynamic> rawQuestions = (data['questions'] ?? []) as List;
      questions.clear();
      correctAnswers.clear();
      userAnswers.clear();

      for (int i = 0; i < rawQuestions.length; i++) {
        final q = Map<String, dynamic>.from(rawQuestions[i]);
        final sentence = (q['sentence'] ?? '').toString();
        if (sentence.trim().isEmpty) continue;

        questions.add({'index': i, 'sentence': sentence});

        // บางข้อ answers เป็น string เดี่ยว ก็ห่อเป็นลิสต์ให้เหมือนกัน
        final answers = q['answers'];
        final List<String> correctList =
            (answers is List)
                ? List<String>.from(answers.map((e) => e?.toString() ?? ''))
                : [answers.toString()];
        correctAnswers[i] = correctList;

        // ความยาวช่องว่าง = จำนวนจุด (>=3) ที่พบในประโยค
        final blanks = _splitBlanks(sentence).blankCount;
        // ถ้าคีย์ answers ไม่เท่าจำนวนช่อง ก็ยึดตาม answers เดิม
        final len = blanks > 0 ? blanks : correctList.length;
        userAnswers[i] = List<String?>.filled(len, null);
      }

      setState(() {});
    } catch (e) {
      // เอาไว้ดู log ตอนดีบัก
      debugPrint('❌ fetch error: $e');
    }
  }

  Future<void> _saveQuizResult(int score) async {
    try {
      if (loggedInUsername == null || loggedInUsername!.isEmpty) {
        debugPrint('⚠️ ไม่พบ username ใน SharedPreferences');
        return;
      }

      // ดึงชื่อ-สกุล
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
        "category": "เติมคำลงในช่องว่าง (ชุด ${widget.set})",
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint("❌ save result error: $e");
    }
  }

  //  reset คำตอบทั้งหมด เพื่อเริ่มทำใหม่
 void _resetQuiz() {
    setState(() {
      showResult = false;
      wrongAnswers.clear();
      usedChoices.clear();
      userAnswers.updateAll(
        (key, value) => List<String?>.filled(value.length, null),
      );
    });
  }

  // แสดงสรุปคะแนน
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
                      label: Text('ได้ $score / $total',
                          style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text('$percent%', style: GoogleFonts.mali())),
                  ],
                ),
                const SizedBox(height: 12),
                if (wrongAnswers.isEmpty)
                  Center(
                    child: Text('เก่งมาก! ทำถูกทุกข้อ 🎉',
                        style: GoogleFonts.mali(fontSize: 16)),
                  )
                else ...[
                  Text('ข้อที่ทำพลาด',
                      style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
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
                  const SizedBox(height: 8),
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
                        child: Text('ปิด',
                            style: GoogleFonts.mali(color: Colors.white)),
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
    final hasEmpty =
        userAnswers.values.any((rows) => rows.any((e) => e == null));
    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📣 กรุณาเติมคำให้ครบทุกช่อง', style: GoogleFonts.mali()),
        ),
      );
      return;
    }

    int score = 0;
    wrongAnswers.clear();

    for (int i = 0; i < questions.length; i++) {
      final correct = correctAnswers[i] ?? const <String>[];
      final filled = userAnswers[i] ?? const <String?>[];
      bool ok = true;
      for (int j = 0; j < correct.length; j++) {
        final ans = (j < filled.length) ? (filled[j] ?? '') : '';
        if (ans != correct[j]) {
          ok = false;
          break;
        }
      }
      if (ok) {
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

  // กล่องประโยค + ช่องว่างลากวางรองรับหลายช่อง
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
        final correctHere = (correctAnswers[index] ?? const <String>[])[i];
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
                margin:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: answer == null
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
                      usedChoices[received] =
                          (usedChoices[received] ?? 0) + 1;
                    });
                  },
                ),
              ),
            ),
          ),
        );
      }
    }

    final userJoined =
        (userAnswers[index] ?? const <String?>[]).map((e) => e ?? '').join('|');
    final correctJoined =
        (correctAnswers[index] ?? const <String>[]).join('|');
    final allCorrect = showResult && userJoined == correctJoined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ข้อ ${index + 1}',
              style: GoogleFonts.mali(
                  fontSize: fontSize, fontWeight: FontWeight.bold)),
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

  //แผงซ้าย
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
                  fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ...questions.map((q) =>
            _buildSentence(q['index'] as int, q['sentence'] as String, fontSize)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: showResult ? null : _checkAnswers,
            child: Text('ตรวจคำตอบ',
                style:
                    GoogleFonts.mali(fontSize: fontSize, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // แผงขวา
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
            Text('คลังคำ',
                style: GoogleFonts.mali(
                    fontSize: fontSize, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: SingleChildScrollView(child: _buildChoicesWrap(fontSize)),
            ),
            const Divider(height: 20),
            Wrap(spacing: 8, children: [
              Chip(label: Text('เหลือ $remain', style: GoogleFonts.mali())),
              Chip(label: Text('ใช้ไป $used', style: GoogleFonts.mali())),
            ]),
            const SizedBox(height: 12),
            Row(children: [
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
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  child:
                      Text('ตรวจคำตอบ', style: GoogleFonts.mali(color: Colors.white)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: Image.asset('images/reading.png',
                  width: 120, fit: BoxFit.contain),
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
        child: questions.isEmpty
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
                        ...questions.map((q) => _buildSentence(
                            q['index'] as int, q['sentence'] as String, fontSize)),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            onPressed: showResult ? null : _checkAnswers,
                            child: Text(
                              'ตรวจคำตอบ',
                              style: GoogleFonts.mali(
                                  fontSize: fontSize, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset('images/reading.png',
                              width: 110, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}