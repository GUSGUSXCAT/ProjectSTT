import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MaeKobDragDropScreen extends StatefulWidget {
  final String type;
  final String set;

  const MaeKobDragDropScreen({
    super.key,
    required this.type,
    required this.set,
  });

  @override
  State<MaeKobDragDropScreen> createState() => _MaeKobDragDropScreenState();
}

class _MaeKobDragDropScreenState extends State<MaeKobDragDropScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  String title = '';
  String instruction = '';


  List<String> allChoices = [];
  List<QuestionItem> questions = [];


  bool showResult = false;
  List<WrongAnswer> wrongAnswers = [];

  String? loggedInUsername;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadExercise();
  }


  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername = prefs.getString("loggedInUsername") ?? 
                         prefs.getString("username");
    });
  }

  Future<void> _loadExercise() async {
    try {

      final snapshot = await _firestore
          .collection('questions')
          .doc('g_2')
          .collection('mae_kob')
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

      title = data['title']?.toString() ?? '';
      instruction = data['instruction']?.toString() ?? '';

      allChoices = _parseChoices(data['choices']);

     
      questions = _parseQuestions(data['questions']);

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading exercise: $e');
      setState(() {});
    }
  }


  List<String> _parseChoices(dynamic choicesData) {
    if (choicesData == null) return [];

    try {
    
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

        final parts = _splitSentence(sentence);
        
        final answers = _parseAnswers(q['answers']);

        result.add(QuestionItem(
          index: i,
          textParts: parts,
          correctAnswers: answers,
          userAnswers: List.filled(answers.length, null), 
        ));
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error parsing questions: $e');
      return [];
    }
  }


  List<String> _splitSentence(String sentence) {
    String temp = sentence.replaceAll('...', '|||BLANK|||');
    return temp.split('|||BLANK|||');
  }

  
  List<String> _parseAnswers(dynamic answersData) {
    if (answersData is List) {
      return List<String>.from(answersData.map((e) => e?.toString() ?? ''));
    }
    return [answersData?.toString() ?? ''];
  }

  void _onWordDropped(int questionIndex, int blankIndex, String word) {
    if (showResult) return; 

    setState(() {
      
      questions[questionIndex].userAnswers[blankIndex] = word;
    });
  }

  
  void _onRemoveWord(int questionIndex, int blankIndex) {
    if (showResult) return; 

    setState(() {
      
      questions[questionIndex].userAnswers[blankIndex] = null;
    });
  }

  
  Future<void> _checkAnswers() async {
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

  
    await _saveScore(score);

  
    if (mounted) _showResultSheet(score);
  }

 
  bool _checkQuestion(QuestionItem q) {
    if (q.userAnswers.length != q.correctAnswers.length) return false;

    for (int i = 0; i < q.correctAnswers.length; i++) {
      if (q.userAnswers[i] != q.correctAnswers[i]) return false;
    }

    return true;
  }


  Future<void> _saveScore(int score) async {
    try {
      if (loggedInUsername == null || loggedInUsername!.isEmpty) return;

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
        "score": score,
        "total": questions.length,
        "timestamp": Timestamp.now(),
        "category": "มาตราตัวสะกด ลากวาง (${widget.type} ชุดที่ ${widget.set})",
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
                       
                        onPressed: () {
                          Navigator.pop(context); // ปิด modal
                          Navigator.pop(context); // กลับไปหน้า SetScreen
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
      wrongAnswers.clear();
      

      for (var q in questions) {
        q.userAnswers = List.filled(q.correctAnswers.length, null);
      }
    });
  }

 
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

  
  Widget _buildQuestion(QuestionItem q, double fontSize) {
    List<Widget> widgets = [];

    
    for (int i = 0; i < q.textParts.length; i++) {
      
      widgets.add(
        Text(
          q.textParts[i],
          style: GoogleFonts.mali(fontSize: fontSize),
        ),
      );

      
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
          // แสดงเฉลย 
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
  Widget _buildWordBank(double fontSize) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allChoices.map((word) {
        return Draggable<String>(
          data: word,
          feedback: Material(
            color: Colors.transparent,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
              backgroundColor: Colors.pink.shade300,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: Chip(
              label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          
          child: Chip(
            label: Text(word, style: GoogleFonts.mali(fontSize: fontSize)),
            backgroundColor: Colors.pink.shade50,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
   
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 480 ? 16.0 : 20.0;
    final isWideScreen = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade200,
        title: Text(
          title.isEmpty
              ? 'ลากวาง ${widget.type} ชุดที่ ${widget.set}'
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

 
  Widget _buildWideLayout(double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                    Row(
                      children: [
                        Text(
                          'คลังคำ',
                          style: GoogleFonts.mali(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'คำแต่ละตัวใช้ได้หลายครั้ง',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'คำแต่ละตัวลากได้หลายครั้ง',
                              style: GoogleFonts.mali(
                                fontSize: fontSize - 2,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
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
                              backgroundColor: Colors.pinkAccent,
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
                        'images/reading.png',
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

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'คลังคำ',
                        style: GoogleFonts.mali(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'คำแต่ละตัวลากได้หลายครั้ง',
                            style: GoogleFonts.mali(
                              fontSize: fontSize - 2,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWordBank(fontSize),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          ...questions.map((q) => _buildQuestion(q, fontSize)),
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Image.asset(
              'images/reading.png',
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