import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quiz_matcher/flutter_quiz_matcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_quiz_matcher/models/model.dart';

class ToneMarksMatchingScreen extends StatefulWidget {
  const ToneMarksMatchingScreen({super.key});

  @override
  State<ToneMarksMatchingScreen> createState() =>
      _ToneMarksMatchingScreenState();
}

class _ToneMarksMatchingScreenState extends State<ToneMarksMatchingScreen> {
  List<Widget> questions = [];
  List<Widget> answers = [];

  List<String> correctAnswers = [];
  bool isLoading = true;
  int correctCount = 0;

  @override
  void initState() {
    super.initState();
    loadToneMarks();
  }

  Future<void> loadToneMarks() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('questions')
            .doc('g_1')
            .collection('tonemarks')
            .orderBy(FieldPath.documentId)
            .get();

    final docs = snapshot.docs;

setState(() {
  questions = docs.map((doc) {
    final data = doc.data();
    final imageUrl = data['image_url'];
    final letter = data['letter'] ?? '';

    Widget content = imageUrl != null && imageUrl != ''
        ? Image.network(imageUrl, width: 60, height: 60)
        : Text(letter, style: GoogleFonts.mali(fontSize: 50));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.deepPurple, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: content,
    );
  }).toList();

  correctAnswers = docs.map((doc) => doc['example'] as String).toList();

  answers = correctAnswers.map((text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.deepPurple, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: Text(text, style: GoogleFonts.mali(fontSize: 22)),
    );
  }).toList()
    ..shuffle();

  isLoading = false;
});
  }
  Future<void> saveScore(int correct, int total) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('exercise_results').add({
      'student_id': user.uid,
      'category': 'tone_marks',
      'score': correct,
      'total': total,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void showResultDialog(int correct, int total) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("ผลลัพธ์", style: GoogleFonts.mali()),
            content: Text(
              "คุณจับคู่ถูกต้อง $correct จากทั้งหมด $total",
              style: GoogleFonts.mali(fontSize: 20),
            ),
            actions: [
              TextButton(
                child: Text("ปิด", style: GoogleFonts.mali()),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("จับคู่วรรณยุกต์", style: GoogleFonts.mali()),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: const Color(0xFFF3F0F8),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: QuizMatcher(
                  questions: questions,
                  answers: answers,
                  onScoreUpdated: (UserScore score) {
                    if (score.questionAnswer == true) correctCount++;
                    if (correctCount == questions.length) {
                      showResultDialog(correctCount, questions.length);
                      saveScore(correctCount, questions.length);
                    }

                    print(
                      "คำถามข้อที่ ${score.questionIndex} - ${score.questionAnswer ? 'ถูก' : 'ผิด'}",
                    );
                  },
                  defaultLineColor: Colors.black,
                  correctLineColor: Colors.green,
                  incorrectLineColor: Colors.red,
                  drawingLineColor: Colors.grey,
                  paddingAround: const EdgeInsets.all(8),
                ),
              ),
    );
  }
}
