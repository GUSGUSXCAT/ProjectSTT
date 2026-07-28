import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ReadingLongPracticeScreen extends StatefulWidget {
  const ReadingLongPracticeScreen({super.key});

  @override
  State<ReadingLongPracticeScreen> createState() =>
      _ReadingLongPracticeScreenState();
}

class _ReadingLongPracticeScreenState extends State<ReadingLongPracticeScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<DocumentSnapshot> paragraphs = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool isListening = false;
  bool showResult = false;
  bool isCorrect = false;
  String recognizedText = "";
  

  @override
  void initState() {
    super.initState();
    fetchParagraphs();
  }

  Future<void> fetchParagraphs() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('questions')
            .doc('g_3')
            .collection('reding_long') 
            .orderBy(FieldPath.documentId)
            .get();

    setState(() {
      paragraphs = snapshot.docs;
      isLoading = false;
    });

    speakCurrentTts();
  }

  Future<void> speakCurrentTts() async {
    final text = paragraphs[currentIndex]['paragraph'];
    await _tts.setLanguage("th-TH");
    await _tts.speak(text);
  }

  void _next() {
    if (currentIndex < paragraphs.length - 1) {
      setState(() {
        currentIndex++;
        recognizedText = "";
        isCorrect = false;
        showResult = false;
      });
      speakCurrentTts();
    } else {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text("จบบทฝึก", style: GoogleFonts.mali()),
              content: Text(
                "คุณฝึกอ่านจบบทความทั้งหมดแล้ว",
                style: GoogleFonts.mali(fontSize: 18),
              ),
              actions: [
                TextButton(
                  child: Text("กลับหน้าหลัก", style: GoogleFonts.mali()),
                  onPressed:
                      () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                ),
              ],
            ),
      );
    }
  }

  void _startListening() async {
    final available = await _speech.initialize(
    onStatus: (status) => print('💬 STATUS: $status'),
  onError: (error) => print('❌ ERROR: $error'),
);
print("STT Available: $available");
    if (available) {
      setState(() {
        isListening = true;
        showResult = false;
        recognizedText = "";
      });

      _speech.listen(
        localeId: 'th-TH',
        onResult: (result) {
          setState(() {
            recognizedText = result.recognizedWords.trim();
          });
        },
      );
    }
  }

  void _checkSpeech() {
    _speech.stop();
    final expected = paragraphs[currentIndex]['check'].trim();
    setState(() {
      isListening = false;
      isCorrect = recognizedText == expected;
      showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = paragraphs[currentIndex].data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text('อ่านบทความยาว ป.3', style: GoogleFonts.mali()),
        backgroundColor: Colors.teal,
      ),
      backgroundColor: const Color(0xFFFAF7F0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    data['paragraph'],
                    style: GoogleFonts.mali(
                      fontSize: 24, // ใหญ่ขึ้นจากเดิม
                      height: 1.6, // เพิ่มความห่างบรรทัดให้อ่านง่าย
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up),
              label: Text("ฟังเสียงบทความ", style: GoogleFonts.mali()),
              onPressed: speakCurrentTts,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: Text(
                isListening ? "กำลังพูด..." : "คลิกเพื่อพูด",
                style: GoogleFonts.mali(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isListening ? Colors.green.shade100 : Colors.blue.shade50,
              ),
              onPressed: _startListening,
            ),
            const SizedBox(height: 16),
            if (recognizedText.isNotEmpty)
              Column(
                children: [
                  Text("คุณพูดว่า:", style: GoogleFonts.mali(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(recognizedText, style: GoogleFonts.mali(fontSize: 16)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _checkSpeech,
                    child: Text("ตรวจ", style: GoogleFonts.mali()),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (showResult)
              Column(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.close,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isCorrect ? "✅ อ่านถูกต้อง!" : "❌ ลองใหม่อีกครั้ง",
                    style: GoogleFonts.mali(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isCorrect)
                    ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        "➡️ ถัดไป",
                        style: GoogleFonts.mali(fontSize: 18),
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
