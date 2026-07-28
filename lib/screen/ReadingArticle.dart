///ปจบ.ใช้หน้านี้
library;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:LumoRead/screen/exercise_guidedialog.dart';

class ReadingArticleScreen extends StatefulWidget {
  final String articleId;
  final String title;
  final String grade;
  final String topicId;
  final String set;

  const ReadingArticleScreen({
    super.key,
    required this.articleId,
    required this.title,
    required this.grade,
    required this.topicId,
    required this.set,
  });

  @override
  State<ReadingArticleScreen> createState() => _ReadingArticleScreenState();
}

class _ReadingArticleScreenState extends State<ReadingArticleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  List<String> lines = [];
  bool isLoading = true;
  String? username;

  bool isRecording = false;
  bool isProcessing = false;
  bool isSpeaking = false;
  int currentLine = 0;

  List<int> bestScores = []; // เก็บ correctWords ที่ดีที่สุดของแต่ละบรรทัด
  List<int> bestTotals = []; // เก็บ totalWords ของแต่ละบรรทัด

  List<List<Map<String, dynamic>>> allAttempts = [];
  List<String> recognized = [];

  @override
  void initState() {
    super.initState();
    _initTts();
     WidgetsBinding.instance.addPostFrameCallback((_) =>
    ExerciseGuideDialog.show(context, mode: 'main_screen'));
    _loadUsername();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("th-TH");
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => setState(() => isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => isSpeaking = false));
    _tts.setCancelHandler(() => setState(() => isSpeaking = false));
  }

  Future<void> _speak(String text) async {
    if (isSpeaking) {
      await _tts.stop();
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> _loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      username =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");

      if (username == null) {
        _showSnackBar('กรุณาเข้าสู่ระบบใหม่', Colors.red);
        Navigator.pop(context);
        return;
      }

      _loadArticle();
    } catch (e) {
      debugPrint('Error loading username: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadArticle() async {
    try {
      final gradeKey = 'g_${widget.grade}';
      debugPrint(
        '📁 Loading article from: questions/$gradeKey/${widget.topicId}/${widget.articleId}',
      );

      final doc = await _firestore
          .collection('questions')
          .doc(gradeKey)
          .collection(widget.topicId)
          .doc(widget.articleId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        if (data['is_deleted'] == true) {
          if (mounted) {
            _showSnackBar('บทความนี้ถูกลบแล้ว', Colors.red);
            Navigator.pop(context);
          }
          return;
        }

        List<dynamic> linesData = [];
        if (data['lines'] is List) {
          linesData = data['lines'] as List;
        } else if (data['lines'] is String) {
          try {
            linesData = jsonDecode(data['lines']);
          } catch (e) {
            linesData = (data['lines'] as String)
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .toList();
          }
        }

        setState(() {
          lines = linesData.map((e) => e.toString()).toList();
          bestScores = List.filled(lines.length, 0); // correctWords
          bestTotals = List.filled(lines.length, 0); // totalWords
          allAttempts = List.generate(lines.length, (_) => []);
          recognized = List.filled(lines.length, '');
          isLoading = false;
        });

        debugPrint('✅ Loaded ${lines.length} lines');
      } else {
        debugPrint('❌ Document not found');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading article: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _startRecording() async {
    if (allAttempts[currentLine].length >= 3) {
      _showSnackBar(
        'อ่านครบ 3 ครั้งแล้ว กรุณาไปข้อถัดไป',
        Colors.blueGrey.shade400,
      );
      return;
    }
    if (isSpeaking) await _tts.stop();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('กรุณาอนุญาตใช้ไมโครโฟน', Colors.red);
      return;
    }

    try {
      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: '',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/temp_reading_audio.wav';
        await _recorder.start(
          const RecordConfig(sampleRate: 16000, numChannels: 1),
          path: path,
        );
      }

      setState(() => isRecording = true);
    } catch (e) {
      _showSnackBar('เริ่มบันทึกไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[Record] Stop timeout!');
          return null;
        },
      );

      setState(() {
        isRecording = false;
        isProcessing = true;
      });

      if (path == null) {
        _showSnackBar('ไม่พบไฟล์เสียง', Colors.red);
        setState(() => isProcessing = false);
        return;
      }

      final expectedText = lines[currentLine];

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://noneligibly-lathiest-zana.ngrok-free.dev/stt'),
      );

      request.fields['expected'] = expectedText;

      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            response.bodyBytes,
            filename: 'audio.wav',
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', path));
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        var resData = await response.stream.bytesToString();
        var json = jsonDecode(resData);
        String serverText = json['text'] ?? "";

        final List<String> transcriptWords =
            json['transcript_words'] != null
                ? List<String>.from(json['transcript_words'])
                : serverText
                    .split(' ')
                    .where((w) => w.trim().isNotEmpty)
                    .toList();

        final List<String> expectedWords =
            json['expected_words'] != null
                ? List<String>.from(json['expected_words'])
                : expectedText
                    .split(' ')
                    .where((w) => w.trim().isNotEmpty)
                    .toList();

        debugPrint('📝 Expected words: $expectedWords');
        debugPrint('🎤 Transcript words: $transcriptWords');

        final filteredTranscript =
            transcriptWords.where((w) => w.trim().isNotEmpty).toList();
        final filteredExpected =
            expectedWords.where((w) => w.trim().isNotEmpty).toList();
        final result = _wordLevelMatching(filteredTranscript, filteredExpected);

        final correctWords = result['correctWords'] as int;
        final totalWords = result['totalWords'] as int;
        final matchedWords = result['matchedWords'] as List<String>;
        final missedWords = result['missedWords'] as List<String>;

        final accuracy = totalWords == 0 ? 0.0 : correctWords / totalWords;

        debugPrint(
          '✅ Accuracy: ${(accuracy * 100).toStringAsFixed(1)}% ($correctWords/$totalWords)',
        );

        final attempt = {
          'text': serverText,
          'correctWords': correctWords,
          'totalWords': totalWords,
          'matchedWords': matchedWords,
          'missedWords': missedWords,
          'accuracy': accuracy,
          'timestamp': DateTime.now(),
        };

        setState(() {
          allAttempts[currentLine].add(attempt);
          recognized[currentLine] = serverText;

          // อัพเดต best ถ้า accuracy ครั้งนี้ดีกว่าเดิม
          final prevAccuracy = bestTotals[currentLine] == 0
              ? 0.0
              : bestScores[currentLine] / bestTotals[currentLine];
          if (accuracy > prevAccuracy) {
            bestScores[currentLine] = correctWords;
            bestTotals[currentLine] = totalWords;
          }

          isProcessing = false;
        });

        _showResultDialog(
          correctWords,
          totalWords,
          accuracy,
          matchedWords,
          missedWords,
        );
      } else {
        _showSnackBar('Server Error: ${response.statusCode}', Colors.red);
        setState(() => isProcessing = false);
      }
    } catch (e) {
      setState(() => isProcessing = false);
      _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    }
  }

  Map<String, dynamic> _wordLevelMatching(
    List<String> transcriptWords,
    List<String> expectedWords,
  ) {
    List<String> matchedWords = [];
    List<String> missedWords = [];
    List<String> availableTokens = List.from(transcriptWords);

    for (final word in expectedWords) {
      final currentJoined = availableTokens.join('');

      if (availableTokens.contains(word)) {
        matchedWords.add(word);
        availableTokens.remove(word);
      } else if (currentJoined.contains(word)) {
        matchedWords.add(word);
        int charsToRemove = word.length;
        while (charsToRemove > 0 && availableTokens.isNotEmpty) {
          if (availableTokens.first.length <= charsToRemove) {
            charsToRemove -= availableTokens.first.length;
            availableTokens.removeAt(0);
          } else {
            availableTokens[0] = availableTokens[0].substring(charsToRemove);
            charsToRemove = 0;
          }
        }
      } else {
        missedWords.add(word);
      }
    }

    return {
      'correctWords': matchedWords.length,
      'totalWords': expectedWords.length,
      'matchedWords': matchedWords,
      'missedWords': missedWords,
    };
  }

  /// แสดง Dialog ผลลัพธ์ — ใช้ accuracy แทน score 0-3
  void _showResultDialog(
    int correctWords,
    int totalWords,
    double accuracy,
    List<String> matchedWords,
    List<String> missedWords,
  ) {
    String message;
    Color color;
    String emoji;

    if (accuracy >= 0.75) {
      message = 'ดีมาก! อ่านถูกต้องและคล่อง';
      color = Colors.green;
      emoji = '🌟';
    } else if (accuracy >= 0.50) {
      message = 'ดี! อ่านถูกส่วนใหญ่';
      color = Colors.blue;
      emoji = '👍';
    } else if (accuracy >= 0.25) {
      message = 'พอใช้ อ่านได้บางส่วน';
      color = Colors.orange;
      emoji = '📝';
    } else {
      message = 'ควรฝึกฝนเพิ่มเติม';
      color = Colors.red;
      emoji = '💪';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          '$emoji ผลการอ่าน',
          style: GoogleFonts.mali(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.mali(fontSize: 16, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                'ถูก: $correctWords / $totalWords คำ',
                style: GoogleFonts.mali(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ความแม่นยำ: ${(accuracy * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.mali(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'ครั้งที่: ${allAttempts[currentLine].length}',
                style: GoogleFonts.mali(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'ดีที่สุด: ${bestScores[currentLine]} / ${bestTotals[currentLine]} คำ',
                style: GoogleFonts.mali(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (matchedWords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '✅ คำที่อ่านถูก:',
                  style: GoogleFonts.mali(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: matchedWords.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        word,
                        style: GoogleFonts.mali(
                            fontSize: 11, color: Colors.green.shade800),
                      ),
                    );
                  }).toList(),
                ),
              ],

              if (missedWords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '❌ คำที่ควรอ่านเพิ่ม:',
                  style: GoogleFonts.mali(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: missedWords.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        word,
                        style: GoogleFonts.mali(
                            fontSize: 11, color: Colors.red.shade800),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (allAttempts[currentLine].length < 3)
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh, color: Colors.blue),
              label: Text('อ่านซ้ำ',
                  style: GoogleFonts.mali(color: Colors.blue)),
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _goToNextLine();
            },
            icon: Icon(
              currentLine == lines.length - 1
                  ? Icons.check
                  : Icons.arrow_forward,
              color: Colors.green,
            ),
            label: Text(
              currentLine == lines.length - 1 ? 'เสร็จสิ้น' : 'ข้อถัดไป',
              style: GoogleFonts.mali(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _goToNextLine() {
    if (currentLine < lines.length - 1) {
      setState(() => currentLine++);
    } else {
      _showCompletionDialog();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mali()),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveResults() async {
    if (username == null) return;

    try {
      List<Map<String, dynamic>> answers = [];
      List<Map<String, dynamic>> wrongAnswers = [];

      for (int i = 0; i < lines.length; i++) {
        final correctWords = bestScores[i];
        final totalWords = bestTotals[i];
        final attempts = allAttempts[i].length;
        final accuracy =
            totalWords == 0 ? 0.0 : correctWords / totalWords;

        answers.add({
          'number': i + 1,
          'text': lines[i],
          'recognized': recognized[i],
          'correct_words': correctWords,
          'total_words': totalWords,
          'accuracy': accuracy,
          'attempts': attempts,
          'is_correct': accuracy >= 0.75,
        });

        // บันทึก wrong answers ถ้าไม่ได้ครบ 100%
        if (accuracy < 1.0 && allAttempts[i].isNotEmpty) {
          final bestAttempt = allAttempts[i].reduce(
            (a, b) => (a['accuracy'] as double) >= (b['accuracy'] as double)
                ? a
                : b,
          );
          wrongAnswers.add({
            'number': i + 1,
            'correct': lines[i],
            'recognized': recognized[i],
            'correct_words': correctWords,
            'total_words': totalWords,
            'attempts': attempts,
            'missed_words': bestAttempt['missedWords'] ?? [],
            'matched_words': bestAttempt['matchedWords'] ?? [],
          });
        }
      }

      await _firestore.collection('quiz_results').add({
        'username': username,
        'category': 'การอ่านบทความ',
        'article_id': widget.articleId,
        'title': widget.title,
        'score': bestScores.reduce((a, b) => a + b),  // รวม correctWords
        'total': bestTotals.reduce((a, b) => a + b),  // รวม totalWords
        'answers': answers,
        'wrong_answers': wrongAnswers,
        'timestamp': Timestamp.now(),
        'grade': widget.grade,
        'topic_id': widget.topicId,
        'recognized_lines': List.generate(
          lines.length,
          (i) => {
            'number': i + 1,
            'text': lines[i],
            'recognized': recognized[i],
            'correct_words': bestScores[i],
            'total_words': bestTotals[i],
          },
        ),
      });

      debugPrint(
          '✅ Saved results: ${bestScores.reduce((a, b) => a + b)}/${bestTotals.reduce((a, b) => a + b)}');
    } catch (e) {
      debugPrint('❌ Error saving: $e');
    }
  }

  void _showCompletionDialog() async {
    await _saveResults();
    if (!mounted) return;

    final totalCorrect = bestScores.reduce((a, b) => a + b);
    final totalWords = bestTotals.reduce((a, b) => a + b);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('🎉 อ่านจบแล้ว!', style: GoogleFonts.mali()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'คะแนนรวม',
              style: GoogleFonts.mali(fontSize: 16, color: Colors.grey),
            ),
            Text(
              '$totalCorrect / $totalWords คำ',
              style: GoogleFonts.mali(
                  fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'รายละเอียด:',
              style: GoogleFonts.mali(fontSize: 14, color: Colors.grey),
            ),
            ...List.generate(lines.length, (index) {
              return Text(
                'ข้อ ${index + 1}: ${bestScores[index]}/${bestTotals[index]} คำ (${allAttempts[index].length} ครั้ง)',
                style: GoogleFonts.mali(fontSize: 12),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('เสร็จสิ้น', style: GoogleFonts.mali()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('กำลังโหลด...', style: GoogleFonts.mali()),
          backgroundColor: const Color(0xFFD4D2F2),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: GoogleFonts.mali()),
          backgroundColor: const Color(0xFFE1FEFE),
        ),
        body: Center(
          child: Text('ไม่พบข้อมูล', style: GoogleFonts.mali(fontSize: 20)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.mali()),
        backgroundColor: const Color(0xFFE3EBFD),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF8F5FD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'บรรทัดที่ ${currentLine + 1}/${lines.length}',
                  style: GoogleFonts.mali(fontSize: 16),
                ),
                Text(
                  'คะแนน: ${bestScores[currentLine]} / ${bestTotals[currentLine]} คำ',
                  style: GoogleFonts.mali(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          if (isProcessing)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE2D1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3D6CE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 16),
                  Text('กำลังประมวลผล...',
                      style: GoogleFonts.mali(fontSize: 16)),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'กดปุ่มไมค์ → อ่าน → กดหยุด',
                  style: GoogleFonts.mali(
                      fontSize: 14, color: Colors.grey.shade700),
                ),
                if (allAttempts[currentLine].isNotEmpty)
                  Text(
                    'อ่านไปแล้ว: ${allAttempts[currentLine].length} ครั้ง',
                    style: GoogleFonts.mali(fontSize: 12, color: Colors.blue),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 80),
              itemCount: lines.length,
              itemBuilder: (_, index) {
                final isCurrent = currentLine == index;
                final attempts = allAttempts[index].length;

                return InkWell(
                  onTap: () {
                    if (index <= currentLine) {
                      if (allAttempts[index].length >= 3) {
                        _showSnackBar(
                          'ข้อนี้อ่านครบ 3 ครั้งแล้ว',
                          Colors.blueGrey.shade400,
                        );
                        return;
                      }
                      setState(() => currentLine = index);
                      _showSnackBar(
                          'เลือกข้อที่ ${index + 1} แล้ว', Colors.blue);
                    } else {
                      _showSnackBar(
                          'กรุณาอ่านตามลำดับ', const Color(0xFF695A5B));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFE0C7EE)
                            : Colors.grey.shade300,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFE0C7EE)
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lines[index],
                                style: GoogleFonts.mali(
                                  fontSize: 16,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              IconButton(
                                icon: Icon(
                                  isSpeaking
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _speak(lines[index]),
                              ),
                          ],
                        ),
                        if (attempts > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'คะแนน: ${bestScores[index]} / ${bestTotals[index]} คำ',
                                style: GoogleFonts.mali(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'อ่าน: $attempts ครั้ง',
                                style: GoogleFonts.mali(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                        if (recognized[index].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '💬 "${recognized[index]}"',
                            style: GoogleFonts.mali(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            allAttempts.isNotEmpty && allAttempts[currentLine].length >= 3
                ? null
                : isRecording
                    ? _stopRecording
                    : _startRecording,
        backgroundColor:
            allAttempts.isNotEmpty && allAttempts[currentLine].length >= 3
                ? Colors.grey
                : isRecording
                    ? Colors.red
                    : Colors.orange,
        icon: Icon(isRecording ? Icons.stop : Icons.mic),
        label: Text(
          allAttempts.isNotEmpty && allAttempts[currentLine].length >= 3
              ? 'อ่านครบ 3 ครั้งแล้ว'
              : isRecording
                  ? 'หยุด'
                  : 'กดอ่าน',
          style: GoogleFonts.mali(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}