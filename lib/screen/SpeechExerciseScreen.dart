////ใช้งานหน้านี้ในการทดสอบการอ่านค่า
// ✅ แก้ไขปัญหา TTS ค้างเป็นปุ่ม "หยุด" - เพิ่ม onPlayerComplete listener

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:LumoRead/screen/exercise_guidedialog.dart';


class SpeechExerciseScreen extends StatefulWidget {
  final String grade;
  final String topicId;
  final String topicName;
  final String? set;
  final String type;

  const SpeechExerciseScreen({
    super.key,
    required this.grade,
    required this.topicId,
    required this.topicName,
    this.set,
    this.type = '',
  });

  @override
  State<SpeechExerciseScreen> createState() => _SpeechExerciseScreenState();
}

class _SpeechExerciseScreenState extends State<SpeechExerciseScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

  static const String API_URL = 'https://noneligibly-lathiest-zana.ngrok-free.dev';
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSpeaking = false;

  List<DocumentSnapshot> words = [];
  List<int> skippedIndices = [];
  List<Map<String, dynamic>> wrongAnswers = [];

  int currentIndex = 0;
  int correctCount = 0;
  int attempts = 0;

  bool isLoading = true;
  bool isRecording = false;
  bool isProcessing = false;
  bool showResult = false;
  bool isCorrect = false;
  bool _submitted = false;

  String recognizedText = "";
  bool isReviewingSkipped = false;
  bool isSkippedWord = false;
  String? loggedInUsername;

  DateTime? _recordingStartTime;
  static const int _minRecordingMs = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
    ExerciseGuideDialog.show(context, mode: 'speech'));
    _loadData();
    _loadUsername();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        debugPrint('🔊 TTS เล่นจบแล้ว - reset _isSpeaking = false');
      }
    });

    // ✅ กรณีเกิด error ระหว่างเล่น
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (mounted && _isSpeaking) {
          setState(() => _isSpeaking = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }


  Future<void> _speak(String text, {String voice = 'premwadee', String rate = '+0%'}) async {
    if (text.isEmpty) return;
    
    // ✅ ถ้ากำลังพูดอยู่ ไม่ทำซ้ำ
    if (_isSpeaking) {
      debugPrint('🔊 กำลังพูดอยู่แล้ว - ข้าม');
      return;
    }
    
    try {
      setState(() => _isSpeaking = true);
      debugPrint('🔊 Edge TTS: "$text"');
      
      final response = await http.post(
        Uri.parse('$API_URL/tts-base64'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'text': text,
          'voice': voice,
          'rate': rate,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBase64 = data['audio'] as String;
        final audioBytes = base64Decode(audioBase64);

        await _audioPlayer.play(BytesSource(audioBytes));
        debugPrint('✅ เล่นเสียงสำเร็จ');
      } else {
        debugPrint('❌ TTS Error: ${response.statusCode} - ${response.body}');

        if (mounted) setState(() => _isSpeaking = false);
      }
    } catch (e) {
      debugPrint('❌ Edge TTS Error: $e');
      if (mounted) setState(() => _isSpeaking = false);
    }

  }



  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");
    });
  }

  Future<void> _loadData() async {
    try {
      final gradeKey = 'g_${widget.grade}';

      Query query = _firestore
          .collection('questions')
          .doc(gradeKey)
          .collection(widget.topicId)
          .where('mode', isEqualTo: 'speech');

      if (widget.set != null) {
        query = query.where('set', isEqualTo: widget.set);
      }

      if (widget.type.isNotEmpty) {
        query = query.where('type', isEqualTo: widget.type);
      }

      final snapshot = await query.orderBy(FieldPath.documentId).get();

      setState(() {
        words = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _speakCurrent() async {
    final data = words[currentIndex].data() as Map<String, dynamic>;
    final ttsText = data['tts_text'] ?? data['example'] ?? data['word'] ?? '';
    await _speak(ttsText.toString());
  }

  Future<void> _speakCorrectAnswer(String correctWord) async {
    await _speak("คำที่ถูกต้องคือ $correctWord");
  }

  // =====================================================
  // บันทึกเสียง
  // =====================================================

  Future<void> _startRecording() async {
    // ✅ หยุดเสียง TTS ก่อนบันทึก + reset state
    await _audioPlayer.stop();
    if (mounted) setState(() => _isSpeaking = false);

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('กรุณาอนุญาตให้ใช้ไมโครโฟน', Colors.red);
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
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );
      }

      _recordingStartTime = DateTime.now();

      setState(() {
        isRecording = true;
        showResult = false;
        recognizedText = "";
      });
    } catch (e) {
      _showSnackBar('เริ่มบันทึกไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;

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

      if (path == null || path.isEmpty) {
        _showSnackBar('ไม่พบไฟล์เสียง กรุณาลองใหม่', Colors.red);
        setState(() => isProcessing = false);
        return;
      }

      if (!kIsWeb) {
        final file = File(path);
        final fileSize = await file.length();
        debugPrint('[Record] File size: $fileSize bytes');

        if (fileSize < 2000) {
          setState(() => isRecording = false);
          _showSnackBar('กรุณาพูดให้นานขึ้นอีกหน่อย', Colors.orange);
          return;
        }
      }

      setState(() {
        isRecording = false;
        isProcessing = true;
      });

      final recognized = await _sendToAPI(path);

      setState(() {
        recognizedText = recognized;
        isProcessing = false;
      });

      if (recognized.isNotEmpty) {
        _checkAnswer();
      } else {
        _showSnackBar('ไม่ได้ยินเสียง กรุณาลองใหม่อีกครั้ง', Colors.orange);
      }
    } catch (e) {
      _recordingStartTime = null;
      setState(() {
        isRecording = false;
        isProcessing = false;
      });
      _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    }
  }

  // =====================================================
  // ส่ง Audio ไปยัง STT API
  // =====================================================

  Future<String> _sendToAPI(String path) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$API_URL/stt'));

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

      // เพิ่ม header สำหรับ ngrok
      request.headers['ngrok-skip-browser-warning'] = 'true';

      final streamedResponse = await request.send();
      final resData = await streamedResponse.stream.bytesToString();

      debugPrint('[API] Status: ${streamedResponse.statusCode}');
      debugPrint('[API] Response: $resData');

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(resData);
        return json['text'] ?? "";
      } else {
        try {
          final json = jsonDecode(resData);
          final errorMsg =
              json['error'] ?? 'Server Error: ${streamedResponse.statusCode}';
          throw Exception(errorMsg);
        } catch (_) {
          throw Exception('Server Error: ${streamedResponse.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // =====================================================
  // ตรวจคำตอบ
  // =====================================================

  void _checkAnswer() {
    if (isCorrect) return;

    final data = words[currentIndex].data() as Map<String, dynamic>;
    final expectedList = _getExpectedList(data);
    final recNorm = _norm(recognizedText);
    final wasCorrect = expectedList.any((c) => _norm(c) == recNorm);
    final nextAttempts = attempts + 1;

    setState(() {
      attempts = nextAttempts;
      showResult = true;
      isCorrect = wasCorrect;

      if (wasCorrect) {
        if (nextAttempts <= _maxAttempts) correctCount++;
      } else {
        wrongAnswers.add({
          "index": currentIndex + 1,
          "correct": expectedList.first,
          "recognized": recognizedText,
          "attempt": nextAttempts,
          "note":
              nextAttempts >= _maxAttempts
                  ? "พยายาม $nextAttempts ครั้ง"
                  : null,
        });
      }
    });

    if (!wasCorrect && nextAttempts >= _maxAttempts) {
      _speakCorrectAnswer(expectedList.first);
    }
  }

  // =====================================================
  // บันทึกผลลัพธ์
  // =====================================================

  Future<void> _saveResult() async {
    try {
      if (loggedInUsername == null) return;

      final userSnap =
          await _firestore
              .collection("users")
              .where("username", isEqualTo: loggedInUsername)
              .limit(1)
              .get();

      if (userSnap.docs.isEmpty) return;

      final u = userSnap.docs.first.data();
      final fullName = "${u["first_name"]} ${u["last_name"]}";

      await _firestore.collection('quiz_results').add({
        "username": loggedInUsername,
        "full_name": fullName,
        "score": correctCount,
        "total": words.length,
        "timestamp": Timestamp.now(),
        "category": widget.topicName,
        "topic_id": widget.topicId,
        "grade": widget.grade,
        "set": widget.set,
        "type": widget.type.isNotEmpty ? widget.type : null,
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint('Error saving result: $e');
    }
  }

  // =====================================================
  // Navigation
  // =====================================================

  bool get _isFinalState =>
      (!isReviewingSkipped &&
          currentIndex == words.length - 1 &&
          skippedIndices.isEmpty) ||
      (isReviewingSkipped && skippedIndices.isEmpty);

  void _next() {
    if (!isCorrect || !showResult) return;
    _moveToNext();
  }

  void _skip() {
    if (!skippedIndices.contains(currentIndex)) {
      skippedIndices.add(currentIndex);
    }
    _moveToNext();
  }

  Future<void> _moveToNext() async {
    if (!isReviewingSkipped) {
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

      await _saveResult();
      _showResultSheet();
      return;
    }

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

    await _saveResult();
    _showResultSheet();
  }

  void _resetQuiz() {
    setState(() {
      showResult = false;
      isCorrect = false;
      isReviewingSkipped = false;
      isSkippedWord = false;
      currentIndex = 0;
      attempts = 0;
      correctCount = 0;
      recognizedText = "";
      wrongAnswers.clear();
      skippedIndices.clear();
      _submitted = false;
      _isSpeaking = false; // ✅ reset TTS state ด้วย
    });
  }

  // =====================================================
  // Helpers
  // =====================================================

  int get _maxAttempts => isSkippedWord ? 1 : 3;

  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '');

  List<String> _getExpectedList(Map<String, dynamic> data) {
    final check = data['check'];
    if (check is List) return check.map((e) => e.toString()).toList();
    if (check is String && check.contains('|')) {
      return check.split('|').map((e) => e.trim()).toList();
    }
    return [check?.toString() ?? data['example']?.toString() ?? ''];
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mali()),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getTypeName() {
    if (widget.type.isEmpty) return '';

    if (widget.topicId == 'leading_consonant' ||
        widget.topicId == 'LeadingConsonant') {
      switch (widget.type) {
        case "1":
          return "อักษร ห นำ";
        case "2":
          return "ไม่มี ห นำ";
        case "3":
          return "อักษร อ นำ";
        default:
          return "ประเภท ${widget.type}";
      }
    }

    if (widget.topicId == 'consonant_blends' ||
        widget.topicId == 'ConsonantBlends') {
      switch (widget.type) {
        case "คำควบแท้":
          return "คำควบกล้ำแท้";
        case "คำควบไม่แท้":
          return "คำควบกล้ำไม่แท้";
        default:
          return "ประเภท ${widget.type}";
      }
    }

    return "ประเภท ${widget.type}";
  }

  String _buildTitle() {
    final parts = <String>[widget.topicName];
    if (widget.set != null) parts.add('ชุดที่ ${widget.set}');
    final typeName = _getTypeName();
    if (typeName.isNotEmpty) parts.add('($typeName)');
    return parts.join(' - ');
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
                  style: GoogleFonts.mali(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        'ได้ $correctCount / $total',
                        style: GoogleFonts.mali(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text('$percent%', style: GoogleFonts.mali())),
                  ],
                ),
                const SizedBox(height: 12),
                if (wrongAnswers.isEmpty)
                  Text(
                    'เก่งมาก! ทำถูกทุกข้อ 🎉',
                    style: GoogleFonts.mali(fontSize: 16),
                  )
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
                          'ข้อ ${w['index']}: พูดว่า "${w['recognized']}" | '
                          'ควรพูด "${w['correct']}"'
                          '${w['note'] != null ? ' (${w['note']})' : ''}',
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

  // =====================================================
  // Build UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "${widget.topicName} - อ่านออกเสียง",
            style: GoogleFonts.mali(),
          ),
          backgroundColor: Colors.pink.shade100,
        ),
        body: Center(
          child: Text(
            'ยังไม่มีคำสำหรับชุดนี้',
            style: GoogleFonts.mali(fontSize: 18),
          ),
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
                "${widget.topicName} (ประเภท ${widget.type} ชุดที่ ${widget.set})",
                style: GoogleFonts.mali(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'ข้อที่ ${currentIndex + 1} / ${words.length}',
              style: GoogleFonts.mali(fontSize: 16),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, cons) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: cons.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ให้นักเรียนอ่านคำที่เห็นบนจอ',
                            style: GoogleFonts.mali(fontSize: 24, fontWeight:FontWeight.bold),
                          ),
                          Center(
                            child: Text(
                              (data['example'] ?? data['word'] ?? '')
                                  .toString(),
                              style: GoogleFonts.mali(
                                fontSize: 70,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (data['meaning'] != null)
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    '💡 ความหมายว่า: ${data['meaning']}',
                                    style: GoogleFonts.mali(fontSize: 20),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),

                          // =====================================================
                          // ✅ FIX: ปุ่มฟังความหมาย - กดครั้งเดียว เล่นจบเอง
                          // =====================================================
                          if (data['meaning'] != null)
                            Center(
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  _isSpeaking ? Icons.volume_up : Icons.menu_book,
                                ),
                                label: Text(
                                  _isSpeaking ? 'กำลังพูด...' : 'ฟังความหมาย',
                                  style: GoogleFonts.mali(fontSize: 18),
                                ),
                                // ✅ ถ้ากำลังพูดอยู่ → disable ปุ่ม (กันกดซ้ำ)
                                onPressed: _isSpeaking
                                    ? null
                                    : () {
                                        _speak((data['meaning'] ?? '').toString());
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSpeaking 
                                      ? Colors.grey.shade300 
                                      : Colors.blue.shade50,
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // =====================================================
                          // ปุ่มบันทึกเสียง (STT) - toggle เดียว
                          // =====================================================
                          Center(
                            child: ElevatedButton.icon(
                              icon: Icon(isRecording ? Icons.stop : Icons.mic),
                              label: Text(
                                isRecording ? 'หยุด' : 'กดอ่าน',
                                style: GoogleFonts.mali(fontSize: 18),
                              ),
                              onPressed:
                                  isRecording
                                      ? _stopRecording
                                      : _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isRecording
                                        ? Colors.green.shade100
                                        : Colors.blue.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isProcessing)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('กำลังประมวลผล...'),
                                ],
                              ),
                            ),
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
                                          ? "ถูกต้องแล้ว! กดถัดไปได้เลย"
                                          : (attempts >= _maxAttempts
                                              ? "ไม่เป็นไร ลองพูดใหม่อีกครั้งนะ"
                                              : "ลองใหม่อีกครั้ง (${attempts}/${_maxAttempts})"),
                                      style: GoogleFonts.mali(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed:
                                    (currentIndex == words.length - 1 &&
                                            skippedIndices.isEmpty)
                                        ? null
                                        : _skip,
                                child: Text(
                                  '⏭️ ข้าม',
                                  style: GoogleFonts.mali(fontSize: 20),
                                ),
                              ),
                              ElevatedButton(
                                onPressed:
                                    _isFinalState
                                        ? (showResult && isCorrect
                                            ? (_submitted
                                                ? null
                                                : () async {
                                                  setState(
                                                    () => _submitted = true,
                                                  );
                                                  await _saveResult();
                                                  _showResultSheet();
                                                })
                                            : null)
                                        : (showResult && isCorrect
                                            ? _next
                                            : null),
                                child: Text(
                                  _isFinalState ? '✅ เสร็จสิ้น' : '➡️ ถัดไป',
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