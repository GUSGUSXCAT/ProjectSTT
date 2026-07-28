import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpellingaccstandardScreen extends StatefulWidget {
  const SpellingaccstandardScreen({super.key});

  @override
  State<SpellingaccstandardScreen> createState() => _SpellingaccstandardScreenState();
}

class _SpellingaccstandardScreenState extends State<SpellingaccstandardScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<DocumentSnapshot> spellingaccstandard = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool isListening = false;
  bool showResult = false;
  bool isCorrect = false;
  String recognizedText = "";

  @override
  void initState() {
    super.initState();
    fetchConsonants();
  }

  Future<void> fetchConsonants() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('questions')
            .doc('g_1')
            .collection('spellingaccstandard')
            .orderBy(FieldPath.documentId)
            .get();

    setState(() {
      spellingaccstandard = snapshot.docs;
      isLoading = false;
    });

    speakCurrentTts();
  }

  Future<void> speakCurrentTts() async {
    final ttsText = spellingaccstandard[currentIndex]['tts_text'];
    await _tts.setLanguage("th-TH");
    await _tts.speak(ttsText);
  }

  void _next() {
    if (currentIndex < spellingaccstandard.length - 1) {
      setState(() {
        currentIndex++;
        recognizedText = "";
        isCorrect = false;
        showResult = false;
      });
      speakCurrentTts();
    } else {
      Navigator.pop(context); // จบแล้วกลับ
    }
  }

  void _startListening() async {
    final available = await _speech.initialize();
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
    setState(() {
      isListening = false;
      final expected = spellingaccstandard[currentIndex]['check'].trim();
      isCorrect = recognizedText == expected;
      showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = spellingaccstandard[currentIndex].data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text('การอ่านตัวสะกด ป.1', style: GoogleFonts.mali()),
        centerTitle: true,
        backgroundColor: Colors.pink.shade100,
      ),
      backgroundColor: const Color(0xFFFFF8FC),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade100,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "📘 คำอธิบายเรื่องตัวสะกด",
                                  style: GoogleFonts.mali(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "ตัวสะกด คือ พยัญชนะที่ประกอบอยู่ท้ายสระ และมีเสียงประสมเข้ากับสระ ทำให้หนักขึ้น\nตามฐานของพยัญชนะ มี ๘ มาตรา",
                                  style: GoogleFonts.mali(fontSize: 18),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.volume_up),
                                  label: Text(
                                    "ฟังคำอธิบาย",
                                    style: GoogleFonts.mali(),
                                  ),
                                  onPressed: () async {
                                    await _tts.setLanguage("th-TH");
                                    await _tts.setSpeechRate(0.6);
                                    await _tts.speak(
                                      "ตัวสะกด คือ พะยันชนะ ที่ ประกอบ อยู่ท้าย สะหระ และ มีเสียง ปะ สม เข้ากับ สะหระ ทำให้หนักขึ้น "
                                      "ตามฐาน ของ พะยัน ชนะ มีทั้งหมด แปดมาตรา",
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Text(
                              data['letter'],
                              style: GoogleFonts.mali(
                                fontSize:
                                    constraints.maxWidth > 600 ? 150 : 120,
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
                                  'อ่านว่า ${data['example']}',
                                  style: GoogleFonts.mali(fontSize: 24),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.volume_up),
                              label: Text(
                                "ฟังเสียงอีกครั้ง",
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
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
                                    isListening
                                        ? Colors.green.shade100
                                        : Colors.blue.shade50,
                              ),
                              onPressed: _startListening,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (recognizedText.isNotEmpty)
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "คุณพูดว่า: $recognizedText",
                                    style: GoogleFonts.mali(fontSize: 20),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _checkSpeech,
                                    child: Text(
                                      "ตรวจ",
                                      style: GoogleFonts.mali(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (showResult)
                            Center(
                              child: Column(
                                children: [
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
                                        : "ลองใหม่อีกครั้ง",
                                    style: GoogleFonts.mali(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 50),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ✅ ปุ่ม "➡️ ถัดไป" ลอยมุมขวาบนเมื่อพูดถูก
          if (showResult && isCorrect)
            Positioned(
              top: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  "➡️ ถัดไป",
                  style: GoogleFonts.mali(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
