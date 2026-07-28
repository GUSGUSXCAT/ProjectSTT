import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ConsonantBlendDragDrop extends StatefulWidget {
  final String type;
  final String set;

  const ConsonantBlendDragDrop({
    super.key,
    required this.type,
    required this.set,
  });

  @override
  State<ConsonantBlendDragDrop> createState() => _ConsonantBlendDragDropState();
}

class _ConsonantBlendDragDropState extends State<ConsonantBlendDragDrop> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ข้อมูลแบบฝึกหัด
  String title = '';
  String instruction = '';

  // คลังคำทั้งหมดที่ใช้ลาก
  List<String> allChoices = [];
  
  // เก็บว่าแต่ละคำถูกใช้ไปกี่ครั้งแล้ว
  List<String> usedWords = [];

  // โจทย์แต่ละข้อ
  List<QuestionItem> questions = [];

  // แสดงผลหลังตรวจ
  bool showResult = false;
  List<WrongAnswer> wrongAnswers = [];

  String? loggedInUsername;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadExercise();
  }

  // โหลด username
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername = prefs.getString("loggedInUsername") ?? 
                         prefs.getString("username");
    });
  }

  // แปลง type เป็นชื่อ
  String getTypeName() {
    if (widget.type == "1") return "คำควบแท้";
    if (widget.type == "2") return "คำควบไม่แท้";
    return "ประเภทไม่ทราบ";
  }

  // โหลดแบบฝึกหัดจาก Firestore
  Future<void> _loadExercise() async {
    try {
      // ดึงข้อมูลจาก Firebase
      final snapshot = await _firestore
          .collection('questions')
          .doc('g_2')
          .collection('consonant_blends')
          .where('type', isEqualTo: widget.type)
          .where('set', isEqualTo: widget.set)
          .where('mode', isEqualTo: 'drag_drop')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {});
        return;
      }

      final data = snapshot.docs.first.data();

      // โหลดชื่อและคำแนะนำ
      title = data['title']?.toString() ?? '';
      instruction = data['instruction']?.toString() ?? '';

      // โหลดคลังคำ
      allChoices = _parseChoices(data['choices']);

      // โหลดโจทย์
      questions = _parseQuestions(data['questions']);

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading exercise: $e');
      setState(() {});
    }
  }

  // แปลง choices จาก JSON/String มาเป็น List
  List<String> _parseChoices(dynamic choicesData) {
    if (choicesData == null) return [];

    try {
      // ถ้าเป็น JSON string
      final decoded = jsonDecode(choicesData.toString());
      return List<String>.from(decoded);
    } catch (e) {
      // ถ้าเป็น string ธรรมดา แยกด้วย comma
      return choicesData.toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  // แปลงโจทย์จาก JSON มาเป็น List<QuestionItem>
  List<QuestionItem> _parseQuestions(dynamic questionsData) {
    if (questionsData == null) return [];

    try {
      final decoded = jsonDecode(questionsData.toString());
      final List<dynamic> list = List<dynamic>.from(decoded);

      List<QuestionItem> result = [];
      for (int i = 0; i < list.length; i++) {
        final q = list[i];
        final sentence = q['sentence']?.toString() ?? '';
        
        if (sentence.trim().isEmpty) continue;

        // แยกประโยคออกเป็นส่วนๆ ตามจุด ...
        final parts = _splitSentence(sentence);
        
        // คำตอบที่ถูก
        final answers = _parseAnswers(q['answers']);

        result.add(QuestionItem(
          index: i,
          textParts: parts,
          correctAnswers: answers,
          userAnswers: List.filled(answers.length, null), // เริ่มต้นยังไม่ได้ตอบ
        ));
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error parsing questions: $e');
      return [];
    }
  }

  // แยกประโยคตามจุด ... (ง่ายกว่า Regex)
  List<String> _splitSentence(String sentence) {
    // แทนที่ ... ด้วย marker พิเศษ แล้วแยก
    String temp = sentence.replaceAll('...', '|||BLANK|||');
    return temp.split('|||BLANK|||');
  }

  // แปลง answers
  List<String> _parseAnswers(dynamic answersData) {
    if (answersData is List) {
      return List<String>.from(answersData.map((e) => e?.toString() ?? ''));
    }
    return [answersData?.toString() ?? ''];
  }

  // เช็คว่าคำนี้ยังใช้ได้ไหม (ถ้ามีซ้ำก็ใช้ได้หลายครั้ง)
  bool _canUseWord(String word) {
    // นับว่าคำนี้มีทั้งหมดกี่ตัว
    int totalCount = allChoices.where((w) => w == word).length;
    // นับว่าใช้ไปแล้วกี่ตัว
    int usedCount = usedWords.where((w) => w == word).length;
    
    return usedCount < totalCount;
  }

  // เมื่อวางคำลงในช่องว่าง
  void _onWordDropped(int questionIndex, int blankIndex, String word) {
    if (showResult) return; // ตรวจแล้วห้ามเปลี่ยน

    setState(() {
      // ถ้าช่องนี้มีคำอยู่แล้ว ให้คืนคำเก่ากลับไปที่คลัง
      final oldWord = questions[questionIndex].userAnswers[blankIndex];
      if (oldWord != null) {
        usedWords.remove(oldWord);
      }

      // เพิ่มคำใหม่
      questions[questionIndex].userAnswers[blankIndex] = word;
      usedWords.add(word);
    });
  }

  // เมื่อคลิกที่ช่องว่างที่มีคำอยู่แล้ว (เอาคำออก)
  void _onRemoveWord(int questionIndex, int blankIndex) {
    if (showResult) return; // ตรวจแล้วห้ามเปลี่ยน

    final word = questions[questionIndex].userAnswers[blankIndex];
    if (word == null) return;

    setState(() {
      questions[questionIndex].userAnswers[blankIndex] = null;
      usedWords.remove(word);
    });
  }

  // ตรวจคำตอบ
  Future<void> _checkAnswers() async {
    // เช็คว่าตอบครบทุกช่องหรือยัง
    bool hasEmpty = false;
    for (var q in questions) {
      if (q.userAnswers.contains(null)) {
        hasEmpty = true;
        break;
      }
    }

    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📣 กรุณาเติมคำให้ครบทุกช่อง', style: GoogleFonts.mali()),
        ),
      );
      return;
    }

    // นับคะแนน
    int score = 0;
    wrongAnswers.clear();

    for (var q in questions) {
      bool isCorrect = _checkQuestion(q);
      
      if (isCorrect) {
        score++;
      } else {
        wrongAnswers.add(WrongAnswer(
          index: q.index + 1,
          userAnswer: q.userAnswers.join(', '),
          correctAnswer: q.correctAnswers.join(', '),
        ));
      }
    }

    setState(() => showResult = true);

    // บันทึกคะแนน
    await _saveScore(score);

    // แสดงผล
    if (mounted) _showResultSheet(score);
  }

  // เช็คว่าโจทย์ข้อนี้ถูกไหม
  bool _checkQuestion(QuestionItem q) {
    if (q.userAnswers.length != q.correctAnswers.length) return false;

    for (int i = 0; i < q.correctAnswers.length; i++) {
      if (q.userAnswers[i] != q.correctAnswers[i]) return false;
    }

    return true;
  }

  // บันทึกคะแนนลง Firebase
  Future<void> _saveScore(int score) async {
    try {
      if (loggedInUsername == null || loggedInUsername!.isEmpty) return;

      // ดึงข้อมูล user
      final userSnapshot = await _firestore
          .collection("users")
          .where("username", isEqualTo: loggedInUsername)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) return;

      final userData = userSnapshot.docs.first.data();
      final fullName = "${userData["first_name"]} ${userData["last_name"]}";

      // บันทึกคะแนน
      await _firestore.collection('quiz_results').add({
        "username": loggedInUsername,
        "full_name": fullName,
        "score": score,
        "total": questions.length,
        "timestamp": Timestamp.now(),
        "category": "คำควบกล้ำ ลากวาง (${getTypeName()} ชุดที่ ${widget.set})",
        "wrong_answers": wrongAnswers.map((w) => {
          'index': w.index,
          'correct': w.correctAnswer,
          'answered': w.userAnswer,
        }).toList(),
      });
    } catch (e) {
      debugPrint('❌ Error saving score: $e');
    }
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
                          'ข้อ ${w.index}: ตอบ ${w.userAnswer}  |  เฉลย ${w.correctAnswer}',
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
                          backgroundColor: Colors.purpleAccent,
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

  // รีเซ็ตแบบฝึกหัด
  void _resetQuiz() {
    setState(() {
      showResult = false;
      wrongAnswers.clear();
      usedWords.clear();
      
      // รีเซ็ตคำตอบทุกข้อ
      for (var q in questions) {
        q.userAnswers = List.filled(q.correctAnswers.length, null);
      }
    });
  }

  // สร้างช่องว่างสำหรับวางคำ
  Widget _buildBlankBox(int questionIndex, int blankIndex, double fontSize) {
    final q = questions[questionIndex];
    final userAnswer = q.userAnswers[blankIndex];
    final correctAnswer = q.correctAnswers[blankIndex];
    
    // เช็คว่าถูกหรือผิด (ถ้าตรวจแล้ว)
    bool isCorrect = showResult && (userAnswer == correctAnswer);
    bool isWrong = showResult && (userAnswer != correctAnswer);

    return GestureDetector(
      onTap: () => _onRemoveWord(questionIndex, blankIndex),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: userAnswer == null
              ? Colors.grey[200]
              : (isCorrect
                  ? Colors.green.shade100
                  : (isWrong ? Colors.red.shade100 : Colors.white)),
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DragTarget<String>(
          onAccept: (word) => _onWordDropped(questionIndex, blankIndex, word),
          builder: (context, candidateData, rejectedData) {
            return Text(
              userAnswer ?? 'วางคำ',
              style: GoogleFonts.mali(fontSize: fontSize),
            );
          },
        ),
      ),
    );
  }

  // สร้างประโยคพร้อมช่องว่าง
  Widget _buildQuestion(QuestionItem q, double fontSize) {
    List<Widget> widgets = [];

    // วนสร้างประโยคทีละส่วน
    for (int i = 0; i < q.textParts.length; i++) {
      // เพิ่มข้อความ
      widgets.add(
        Text(
          q.textParts[i],
          style: GoogleFonts.mali(fontSize: fontSize),
        ),
      );

      // เพิ่มช่องว่าง (ถ้ายังมี)
      if (i < q.userAnswers.length) {
        widgets.add(_buildBlankBox(q.index, i, fontSize));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อ ${q.index + 1}',
            style: GoogleFonts.mali(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: widgets,
          ),
          // แสดงเฉลย (ถ้าทำผิด)
          if (showResult && !_checkQuestion(q))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '❌ คำตอบที่ถูก: ${q.correctAnswers.join(', ')}',
                style: GoogleFonts.mali(
                  color: Colors.red,
                  fontSize: fontSize - 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // สร้างคลังคำ (Draggable Chips)
  Widget _buildWordBank(double fontSize) {
    List<Widget> chips = [];

    for (String word in allChoices) {
      // เช็คว่าคำนี้ยังใช้ได้ไหม
      if (!_canUseWord(word)) continue;

      chips.add(
        Draggable<String>(
          data: word,
          feedback: Material(
            color: Colors.transparent,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
              backgroundColor: Colors.purple.shade100,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
            ),
          ),
          child: Chip(
            label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบขนาดหน้าจอ
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 480 ? 16.0 : 20.0;
    final isWideScreen = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade200,
        title: Text(
          title.isEmpty
              ? 'ลากวาง ${getTypeName()} ชุดที่ ${widget.set}'
              : title,
          style: GoogleFonts.mali(fontSize: fontSize),
        ),
      ),
      body: questions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: isWideScreen
                  ? _buildWideLayout(fontSize)
                  : _buildNarrowLayout(fontSize),
            ),
    );
  }

  // Layout สำหรับจอกว้าง (แยก 2 คอลัมน์)
  Widget _buildWideLayout(double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ซ้าย: โจทย์
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (instruction.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '📝 $instruction',
                      style: GoogleFonts.mali(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ...questions.map((q) => _buildQuestion(q, fontSize)),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
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
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // ขวา: คลังคำ
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คลังคำ',
                      style: GoogleFonts.mali(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWordBank(fontSize),
                    const Divider(height: 24),
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
                              backgroundColor: Colors.purpleAccent,
                            ),
                            child: Text(
                              'ตรวจ',
                              style: GoogleFonts.mali(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(
                        'images/nani.png',
                        width: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Layout สำหรับจอแคบ 
  Widget _buildNarrowLayout(double fontSize) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (instruction.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '📝 $instruction',
                style: GoogleFonts.mali(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // คลังคำด้านบน
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คลังคำ',
                    style: GoogleFonts.mali(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWordBank(fontSize),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // โจทย์
          ...questions.map((q) => _buildQuestion(q, fontSize)),
          const SizedBox(height: 16),
          // ปุ่มตรวจ
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Image.asset(
              'images/nani.png',
              width: 100,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Helper Classes

// โครงสร้างเก็บข้อมูลโจทย์แต่ละข้อ
class QuestionItem {
  final int index;                    
  final List<String> textParts;       
  final List<String> correctAnswers;  
  List<String?> userAnswers;          

  QuestionItem({
    required this.index,
    required this.textParts,
    required this.correctAnswers,
    required this.userAnswers,
  });
}

// โครงสร้างเก็บข้อที่ทำผิด
class WrongAnswer {
  final int index;
  final String userAnswer;
  final String correctAnswer;

  WrongAnswer({
    required this.index,
    required this.userAnswer,
    required this.correctAnswer,
  });
}