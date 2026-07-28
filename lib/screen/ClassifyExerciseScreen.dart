///ปจบ.ใช้หน้านี้
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:LumoRead/screen/exercise_guidedialog.dart';

class ClassifyExerciseScreen extends StatefulWidget {
  final String set;
  const ClassifyExerciseScreen({super.key, required this.set, required String grade, required String topicId, required String topicName, required String type});

  @override
  State<ClassifyExerciseScreen> createState() => _ClassifyExerciseScreenState();
}

class _ClassifyExerciseScreenState extends State<ClassifyExerciseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String title = '';
  String instruction = '';

  late List<_Bucket> buckets = [];

  List<String> choices = [];
  Map<String, String> answer = {};

  final Map<String, String> placed = {};

  bool showResult = false;
  int score = 0;
  String? username;
  final List<Map<String, dynamic>> wrongAnswers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
    ExerciseGuideDialog.show(context, mode: 'classify'));
    _load();
  }

  // รองรับทั้ง Array และ String
  List<String> _parseStringList(dynamic data) {
    if (data == null) return [];

    List<String> raw = [];

    // กรณี Array จริงๆ ใน Firestore
    if (data is List) {
      raw = data.map((e) => e.toString()).toList();
    }
    // กรณี String เช่น "[\"เด็ก\",\"เย็น\"]"
    else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          raw = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        raw = data
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

    // ล้าง [] ที่ติดหัว/ท้ายคำ 
    return raw.map((e) => e.replaceAll('[', '').replaceAll(']', '').trim()).toList();
  }

  List<Map<String, dynamic>> _parseBuckets(dynamic data) {
    List<Map<String, dynamic>> result = [];

    if (data == null) return result;

    debugPrint('Parsing buckets: ${data.runtimeType} - $data');

    if (data is String) {
      String cleanStr = data.trim();
      if (cleanStr.startsWith('[') && cleanStr.endsWith(']')) {
        cleanStr = cleanStr.substring(1, cleanStr.length - 1);
      }

      List<String> parts = [];
      int bracketCount = 0;
      StringBuffer current = StringBuffer();

      for (int i = 0; i < cleanStr.length; i++) {
        String char = cleanStr[i];
        if (char == '{' || char == '[') bracketCount++;
        if (char == '}' || char == ']') bracketCount--;

        if (char == ',' && bracketCount == 0) {
          parts.add(current.toString());
          current.clear();
        } else {
          current.write(char);
        }
      }
      if (current.isNotEmpty) parts.add(current.toString());

      for (String part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;

        if (part.startsWith('{') && part.endsWith('}')) {
          part = part.substring(1, part.length - 1);
        }

        RegExp idRegex = RegExp(r'id:\s*([^,}]+)');
        RegExp labelRegex = RegExp(r'label:\s*([^,}]+)');

        String? id;
        String? label;

        var idMatch = idRegex.firstMatch(part);
        if (idMatch != null) {
          id = idMatch.group(1)?.trim().replaceAll('"', '').replaceAll("'", '');
        }

        var labelMatch = labelRegex.firstMatch(part);
        if (labelMatch != null) {
          label = labelMatch.group(1)?.trim().replaceAll('"', '').replaceAll("'", '');
        }

        if (id != null && label != null) {
          result.add({'id': id, 'label': label});
        }
      }
    }

    if (data is List) {
      for (var item in data) {
        if (item is Map) {
          result.add({
            'id': item['id']?.toString() ?? '',
            'label': item['label']?.toString() ?? '',
          });
        } else if (item is String) {
          try {
            var parsed = jsonDecode(item);
            if (parsed is Map) {
              result.add({
                'id': parsed['id']?.toString() ?? '',
                'label': parsed['label']?.toString() ?? '',
              });
            }
          } catch (e) {
            RegExp idRegex = RegExp(r'id:\s*([^,}]+)');
            RegExp labelRegex = RegExp(r'label:\s*([^,}]+)');

            String? id;
            String? label;

            var idMatch = idRegex.firstMatch(item);
            if (idMatch != null) {
              id = idMatch.group(1)?.trim().replaceAll('"', '').replaceAll("'", '');
            }

            var labelMatch = labelRegex.firstMatch(item);
            if (labelMatch != null) {
              label = labelMatch.group(1)?.trim().replaceAll('"', '').replaceAll("'", '');
            }

            if (id != null && label != null) {
              result.add({'id': id, 'label': label});
            }
          }
        }
      }
    }

    return result;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString('loggedInUsername') ?? prefs.getString('username');

      final snap = await _firestore
          .collection('questions')
          .doc('g_3')
          .collection('classify')
          .where('set', isEqualTo: widget.set)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('No documents found');
        return;
      }

      final m = snap.docs.first.data();
      debugPrint('Data loaded: $m');

      title = (m['title'] ?? '').toString();
      instruction = (m['instruction'] ?? '').toString();

      // โหลด choices รองรับทั้ง Array และ String
      choices = _parseStringList(m['choices']);
      debugPrint('Parsed choices: $choices');

      // โหลด buckets
      List<Map<String, dynamic>> bucketMaps = _parseBuckets(m['buckets']);
      buckets = bucketMaps
          .map((e) => _Bucket(
                id: e['id']?.toString() ?? '',
                label: e['label']?.toString() ?? 'ไม่ทราบ',
              ))
          .toList();

      // โหลด answer
      if (m['answer'] is Map) {
        final ak = Map<String, dynamic>.from(m['answer'] ?? {});
        answer = ak.map((k, v) => MapEntry(k.toString(), v.toString()));
      } else if (m['answer'] is String) {
        try {
          final ak = jsonDecode(m['answer']) as Map<String, dynamic>;
          answer = ak.map((k, v) => MapEntry(k.toString(), v.toString()));
        } catch (e) {
          debugPrint('Error parsing answer: $e');
        }
      }

      debugPrint('Loaded: ${buckets.length} buckets, ${choices.length} choices');
      debugPrint('Buckets: ${buckets.map((b) => '${b.id}:${b.label}')}');

      setState(() {});
    } catch (e) {
      debugPrint('Error loading: $e');
    }
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
        SnackBar(
          content: Text('📣 ยังลากคำไม่ครบ', style: GoogleFonts.mali()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int s = 0;
    wrongAnswers.clear();

    for (int i = 0; i < choices.length; i++) {
      final w = choices[i];
      final chosenId = placed[w] ?? '';
      final correctId = answer[w] ?? '';

      if (chosenId == correctId) {
        s++;
      } else {
        wrongAnswers.add({
          'index': i + 1,
          'word': w,
          'answered': _bucketLabel(chosenId),
          'correct': _bucketLabel(correctId),
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
        "username": username,
        "full_name": fullName,
        "score": score,
        "total": choices.length,
        "timestamp": Timestamp.now(),
        "category": "จัดหมวดคำ (ชุด ${widget.set})",
        "topic_id": "classify",
        "grade": "3",
        "set": widget.set,
        "wrong_answers": wrongAnswers,
      });
    } catch (e) {
      debugPrint("❌ save result error: $e");
    }
  }

  void _showResultSheet() {
    final total = choices.length;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('สรุปคะแนน',
                  style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text('ได้ $score / $total',
                        style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
                    backgroundColor: Colors.purple.shade100,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('$percent%', style: GoogleFonts.mali()),
                    backgroundColor: Colors.blue.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wrongAnswers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('🎉 เก่งมาก! จัดหมวดหมู่ถูกทุกคำ',
                      style: GoogleFonts.mali(fontSize: 16, color: Colors.green)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _reset();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.purple.shade200),
                      ),
                      child: Text('ทำใหม่', style: GoogleFonts.mali()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: Text('ปิด',
                          style: GoogleFonts.mali(color: Colors.white)),
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

  List<String> get _remaining =>
      choices.where((w) => !placed.containsKey(w)).toList();

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

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.purple.shade200,
          title: Text('กำลังโหลด...', style: GoogleFonts.mali()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (buckets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.purple.shade200,
          title: Text(title.isEmpty ? 'จัดหมวดหมู่' : title,
              style: GoogleFonts.mali()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 64, color: Colors.orange.shade300),
              const SizedBox(height: 16),
              Text('ไม่พบข้อมูลหมวดหมู่',
                  style: GoogleFonts.mali(fontSize: 18)),
              const SizedBox(height: 8),
              Text('กรุณาตรวจสอบข้อมูลใน Firebase',
                  style: GoogleFonts.mali(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FC),
      appBar: AppBar(
        backgroundColor: Colors.purple.shade200,
        elevation: 0,
        title: Text(
          title.isEmpty ? 'จัดหมวดหมู่' : title,
          style: GoogleFonts.mali(fontSize: fontSize, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (instruction.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text('📝 $instruction',
                    style: GoogleFonts.mali(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade900,
                    )),
              ),
            const SizedBox(height: 16),

            Text('📦 คำศัพท์',
                style: GoogleFonts.mali(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                )),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: _remaining.isEmpty
                  ? Center(
                      child: Text('จัดครบทุกคำแล้ว!',
                          style: GoogleFonts.mali(
                              fontSize: fontSize, color: Colors.purple)),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _remaining.map((word) {
                        return Draggable<String>(
                          data: word,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade300,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(2, 4),
                                  ),
                                ],
                              ),
                              child: Text(word,
                                  style: GoogleFonts.mali(
                                    fontSize: fontSize,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildWordChip(word, fontSize, false),
                          ),
                          child: _buildWordChip(word, fontSize, true),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 16),

            Text('🗂️ หมวดหมู่',
                style: GoogleFonts.mali(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                )),
            const SizedBox(height: 8),

            Expanded(
              child: Row(
                children: buckets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final b = entry.value;
                  final wordsInThis = placed.entries
                      .where((e) => e.value == b.id)
                      .map((e) => e.key)
                      .toList();

                  final List<Color> bucketColors = [
                    Colors.blue.shade50,
                    
                  ];
                  final bgColor = bucketColors[index % bucketColors.length];

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.purple.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DragTarget<String>(
                        builder: (context, candidateData, rejectedData) {
                          final isOver = candidateData.isNotEmpty;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOver
                                  ? Colors.purple.shade100
                                  : bgColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    b.label,
                                    style: GoogleFonts.mali(
                                      fontSize: fontSize - 2,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: wordsInThis.isEmpty
                                      ? Center(
                                          child: Text(
                                            'วางคำที่นี่',
                                            style: GoogleFonts.mali(
                                              fontSize: fontSize - 4,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: wordsInThis.map((w) {
                                              return GestureDetector(
                                                onTap: () {
                                                  if (showResult) return;
                                                  setState(() =>
                                                      placed.remove(w));
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: _chipColor(w, b.id),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                      color: _chipColor(w, b.id) ==
                                                              Colors.green.shade100
                                                          ? Colors.green
                                                          : _chipColor(w, b.id) ==
                                                                  Colors
                                                                      .red.shade100
                                                              ? Colors.red
                                                              : Colors.purple
                                                                  .shade200,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        w,
                                                        style: GoogleFonts.mali(
                                                          fontSize: fontSize - 2,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (showResult &&
                                                          _chipColor(w, b.id) ==
                                                              Colors
                                                                  .green.shade100) ...[
                                                        const SizedBox(width: 4),
                                                        const Icon(
                                                            Icons.check_circle,
                                                            size: 16,
                                                            color: Colors.green),
                                                      ],
                                                      if (showResult &&
                                                          _chipColor(w, b.id) ==
                                                              Colors
                                                                  .red.shade100) ...[
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.cancel,
                                                            size: 16,
                                                            color: Colors.red),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
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

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${placed.length}/${choices.length}',
                            style: GoogleFonts.mali(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showResult)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$score คะแนน',
                              style: GoogleFonts.mali(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: showResult ? null : _check,
                    icon: const Icon(Icons.check_circle),
                    label: Text('ตรวจคำตอบ',
                        style: GoogleFonts.mali(fontSize: fontSize - 2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(String word, double fontSize, bool isDraggable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDraggable ? Colors.purple.shade100 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDraggable ? Colors.purple.shade400 : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Text(
        word,
        style: GoogleFonts.mali(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isDraggable ? Colors.purple.shade900 : Colors.grey.shade700,
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