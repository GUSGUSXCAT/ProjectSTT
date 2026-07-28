import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DragDropClassifyScreen extends StatefulWidget {
  final String set;
  const DragDropClassifyScreen({super.key, required this.set});

  @override
  State<DragDropClassifyScreen> createState() => _DragDropClassifyScreenState();
}

class _DragDropClassifyScreenState extends State<DragDropClassifyScreen> {
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  String title = '';
  String instruction = '';

  // กล่องปลายทาง 
  late List<_Bucket> buckets = [];

  // คำทั้งหมด และเฉลย 
  List<String> choices = [];
  Map<String, String> answer = {};

  // คำที่ถูกลากไปอยู่ในกล่องไหนแล้ว 
  final Map<String, String> placed = {};

  // สรุปผล
  bool showResult = false;
  int score = 0;
  String? username;
  // เก็บข้อที่ผิดเพื่อเซฟ/แสดงผลภายหลัง
  final List<Map<String, dynamic>> wrongAnswers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('loggedInUsername') ?? prefs.getString('username');

    final snap = await _firestore
        .collection('questions')
        .doc('g_3')
        .collection('classify')
        .where('set', isEqualTo: widget.set)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final m = snap.docs.first.data();
    title = (m['title'] ?? '').toString();
    instruction = (m['instruction'] ?? '').toString();

    choices = List<String>.from(m['choices'] ?? []);
    buckets = List<Map<String, dynamic>>.from(m['buckets'] ?? [])
        .map((e) => _Bucket(id: e['id'].toString(), label: e['label'].toString()))
        .toList();

    final ak = Map<String, dynamic>.from(m['answer'] ?? {});
    answer = ak.map((k, v) => MapEntry(k.toString(), v.toString()));

    setState(() {});
  }

  
  String _bucketLabel(String id) {
    for (final b in buckets) {
      if (b.id == id) return b.label;
    }
    return id;
  }

  void _reset() {
    setState(() {
      placed.clear();
      wrongAnswers.clear();
      showResult = false;
      score = 0;
    });
  }

  void _check() async {
    if (placed.length < choices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📣 ยังลากคำไม่ครบ', style: GoogleFonts.mali())),
      );
      return;
    }

    int s = 0;
    wrongAnswers.clear();

    for (int i = 0; i < choices.length; i++) {
      final w = choices[i];
      final chosenId  = placed[w] ?? '';
      final correctId = answer[w] ?? '';

      if (chosenId == correctId) {
        s++;
      } else {
        wrongAnswers.add({
          'index'   : i + 1,
          'word'    : w,                          // คำที่จัดหมวด
          'answered': _bucketLabel(chosenId),     // กล่องที่เลือก
          'correct' : _bucketLabel(correctId),    // กล่องที่ถูก
        });
      }
    }

    setState(() {
      score = s;
      showResult = true;
    });

    await _saveQuizResult();    
    _showResultSheet();
  }

  Future<void> _saveQuizResult() async {
    try {
      if (username == null || username!.isEmpty) return;

      // ดึงชื่อ-สกุล
      String fullName = "ไม่ทราบชื่อเต็ม";
      final uSnap = await _firestore
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();
      if (uSnap.docs.isNotEmpty) {
        final u = uSnap.docs.first.data();
        fullName = "${u["first_name"]} ${u["last_name"]}";
      }

      await _firestore.collection('quiz_results').add({
        "username"     : username,
        "full_name"    : fullName,
        "score"        : score,
        "total"        : choices.length,
        "timestamp"    : Timestamp.now(),
        "category"     : "จัดหมวดคำ (ชุด ${widget.set})", 
        "wrong_answers": wrongAnswers,                    
      });
    } catch (e) {
      debugPrint("❌ save result error: $e");
    }
  }

  void _showResultSheet() {
    final total = choices.length;
    

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('สรุปคะแนน', style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(label: Text('ได้ $score / $total', style: GoogleFonts.mali(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.pop(context); _reset(); },
                      child: Text('ทำใหม่', style: GoogleFonts.mali()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade300),
                      child: Text('ปิด', style: GoogleFonts.mali(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // คำที่ยังไม่ได้วางในกล่องใดเลย
  List<String> get _remaining => choices.where((w) => !placed.containsKey(w)).toList();

  Color _chipColor(String word, String bucketId) {
    if (!showResult) return Colors.white;
    final ok = answer[word] == bucketId;
    return ok ? Colors.green.shade100 : Colors.red.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final fontSize = w < 480 ? 16.0 : 20.0;

    final isLoading = (title.isEmpty && choices.isEmpty && buckets.isEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.purpleAccent.shade100,
        title: Text(
          title.isEmpty ? 'กำลังโหลด...' : title,
          style: GoogleFonts.mali(fontSize: fontSize),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (instruction.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('📝 ⋆⁺₊⋆ $instruction',
                          style: GoogleFonts.mali(fontSize: fontSize, fontWeight: FontWeight.w600)),
                    ),

                  // แถวคำให้ลาก
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _remaining.map((word) {
                      return Draggable<String>(
                        data: word,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Chip(label: Text(word, style: GoogleFonts.mali(fontSize: fontSize))),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: Chip(label: Text(word, style: GoogleFonts.mali(fontSize: fontSize))),
                        ),
                        child: Chip(label: Text(word, style: GoogleFonts.mali(fontSize: fontSize))),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // กล่องปลายทาง
                  Expanded(
                    child: Row(
                      children: buckets.map((b) {
                        final wordsInThis = placed.entries
                            .where((e) => e.value == b.id)
                            .map((e) => e.key)
                            .toList();

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                              color: Colors.grey.shade100,
                            ),
                            child: DragTarget<String>(
                              builder: (context, _, __) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.label,
                                        style: GoogleFonts.mali(fontSize: fontSize, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: wordsInThis.map((w) {
                                            return GestureDetector(
                                              onTap: () {
                                                if (showResult) return;
                                                setState(() => placed.remove(w)); // เอาออกเพื่อย้ายใหม่
                                              },
                                              child: Chip(
                                                backgroundColor: _chipColor(w, b.id),
                                                label: Text(w, style: GoogleFonts.mali()),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              onAccept: (word) {
                                if (showResult) return;
                                setState(() => placed[word] = b.id);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ปุ่มตรวจ
                  Center(
                    child: ElevatedButton(
                      onPressed: showResult ? null : _check,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text('ตรวจคำตอบ',
                          style: GoogleFonts.mali(fontSize: fontSize, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

class _Bucket {
  final String id;
  final String label;
  _Bucket({required this.id, required this.label});
}