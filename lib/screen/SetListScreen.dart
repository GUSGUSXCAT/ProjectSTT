library;
import 'package:LumoRead/screen/ReadingArticleList.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/TopicRouter_Univer.dart';

class SetListScreen extends StatefulWidget {
  final String topicId;
  final String topicName;
  final String grade;
  final String mode;

  const SetListScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.grade,
    required this.mode,
  });

  @override
  State<SetListScreen> createState() => _SetListScreenState();
}

class _SetListScreenState extends State<SetListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<DocumentSnapshot>> _groupedData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final gradeKey = 'g_${widget.grade}';

      //  ถ้ามี mode → filter, ถ้าไม่มี (mode = '') → โหลดทุก mode
      Query query = _firestore
          .collection('questions')
          .doc(gradeKey)
          .collection(widget.topicId);

      if (widget.mode.isNotEmpty) {
        query = query.where('mode', isEqualTo: widget.mode);
      }

      final snapshot = await query.get();
      debugPrint('📚 Loaded ${snapshot.docs.length} documents');

      final Map<String, List<DocumentSnapshot>> grouped = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final mode = data['mode']?.toString() ?? '';
        final set = data['set']?.toString() ?? '1';
        final type = data['type']?.toString() ?? '';

        // ถ้าโหลดหลาย mode → key = "mode|set-type"
        //    ถ้าโหลด mode เดียว  → key = "set-type" (เหมือนเดิม)
        String key;
        if (widget.mode.isEmpty) {
          key = type.isNotEmpty ? '$mode|$set-$type' : '$mode|$set';
        } else {
          key = type.isNotEmpty ? '$set-$type' : set;
        }

        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(doc);
      }

      // เรียงลำดับ
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) {
          final aParts = a.split('|').last.split('-');
          final bParts = b.split('|').last.split('-');
          final setA = int.tryParse(aParts[0]) ?? 0;
          final setB = int.tryParse(bParts[0]) ?? 0;
          if (setA != setB) return setA.compareTo(setB);
          if (aParts.length > 1 && bParts.length > 1) {
            return (int.tryParse(aParts[1]) ?? 0)
                .compareTo(int.tryParse(bParts[1]) ?? 0);
          }
          return 0;
        });

      setState(() {
        _groupedData = {for (var k in sortedKeys) k: grouped[k]!};
        _isLoading = false;
      });

      debugPrint(' Grouped into ${_groupedData.length} sets');
    } catch (e) {
      debugPrint(' Error loading: $e');
      setState(() => _isLoading = false);
    }
  }

  /// แปลง mode เป็นชื่อภาษาไทย
  String _modeLabel(String mode) {
    switch (mode) {
      case 'speech':
        return '📖 อ่านออกเสียง';
      case 'drag_drop':
        return '🧩 ลากคำให้ถูกที่';
      case 'quiz':
        return '📝 แบบทดสอบ';
      case 'classify':
        return '🗂️ จัดหมวดหมู่';
        case 'main_screen': return '📚 อ่านบทความ';
      default:
        return mode;
    }
  }

  /// แปลง type code เป็นชื่อที่อ่านง่าย
  String _getTypeName(String type, String topicId) {
    if (topicId == 'leading_consonant' || topicId == 'LeadingConsonant') {
      switch (type) {
        case "1":
          return "อักษร ห นำ";
        case "2":
          return "ไม่มี ห นำ";
        case "3":
          return "อักษร อ นำ";
        default:
          return "ประเภท $type";
      }
    }

    if (topicId == 'consonant_blends' || topicId == 'ConsonantBlends') {
      switch (type) {
        case "คำควบแท้":
          return "คำควบกลํ้าแท้";
        case "คำควบไม่แท้":
          return "คำควบกลํ้าไม่แท้";
        default:
          return "ประเภท $type";
      }
    }

    return type.isEmpty ? "" : "ประเภท $type";
  }

  String _buildLabel(String key) {
    final modePart = key.contains('|') ? key.split('|')[0] : '';
    final setPart = key.contains('|') ? key.split('|')[1] : key;
    final parts = setPart.split('-');
    final set = parts[0];

    String label = 'ชุดที่ $set';

    if (parts.length > 1) {
      label += ' - ${_getTypeName(parts[1], widget.topicId)}';
    }
    if (modePart.isNotEmpty) {
      label = '${_modeLabel(modePart)}\n$label';
    }

    return label;
  }

void _navigateToExercise(String key) {
  String mode = widget.mode;
  String setPart = key;

  if (key.contains('|')) {
    final split = key.split('|');
    mode    = split[0];
    setPart = split[1];
  }

  final parts = setPart.split('-');
  final set   = parts[0];
  final type  = parts.length > 1 ? parts[1] : '';

  if (mode == 'main_screen') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingArticleListScreen(
          grade: widget.grade,
          topicId: widget.topicId,
          topicName: widget.topicName,
        ),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TopicRouter.getExerciseScreen(
        mode: mode,
        grade: widget.grade,
        topicId: widget.topicId,
        topicName: widget.topicName,
        set: set,
        type: type,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topicName,
          style: GoogleFonts.mali(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFD4D2F2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedData.isEmpty
              ? _buildEmptyState()
              : _buildSetList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีแบบฝึกหัด',
            style: GoogleFonts.mali(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSetList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedData.length,
      itemBuilder: (context, index) {
        final key = _groupedData.keys.elementAt(index);
        final docs = _groupedData[key]!;
        final label = _buildLabel(key);

        return _buildSetCard(
          label: label,
          questionCount: docs.length,
          onTap: () => _navigateToExercise(key),
        );
      },
    );
  }

  Widget _buildSetCard({
    required String label,
    required int questionCount,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // ไอคอน
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF6F5F0), Color(0xFFE5D0E2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE8ABB5),
                    size: 32,
                  ),
                ),

                const SizedBox(width: 16),

                // ข้อความ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.mali(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$questionCount ข้อ',
                        style: GoogleFonts.mali(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}