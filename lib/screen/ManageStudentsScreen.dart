import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _teacherUsername;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _selectedGrade = 'ทั้งหมด';
  final List<String> _grades = ['ทั้งหมด', 'ป.1', 'ป.2', 'ป.3'];
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _teacherUsername =
          prefs.getString("loggedInUsername") ?? prefs.getString("username");

      if (_teacherUsername == null || _teacherUsername!.isEmpty) {
        final userId = prefs.getString("userId");
        if (userId != null && userId.isNotEmpty) {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _teacherUsername = data?['username'] ?? data?['email'] ?? userId;
          }
        }
      }

      await _loadStudents();
    } catch (e) {
      debugPrint('Error in _init: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final usersSnap =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'student')
              .get();

      if (usersSnap.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _students = [];
            _isLoading = false;
          });
        }
        return;
      }

      final studentFutures =
          usersSnap.docs.map((doc) async {
            final data = doc.data();
            final isActive = data['is_active'] ?? true;
            if (!isActive) return null;

            try {
              final resultsSnap =
                  await _firestore
                      .collection('quiz_results')
                      .where('username', isEqualTo: data['username'])
                      .orderBy('timestamp', descending: true)
                      .get();

              double avgScore = 0;
              final attempts = resultsSnap.docs.length;
              final Map<String, int> wrongWordsCount = {};

              if (attempts > 0) {
                double sumPercent = 0;
                for (final r in resultsSnap.docs) {
                  final rd = r.data();
                  final score = ((rd['score'] ?? 0) as num).toDouble();
                  final total = ((rd['total'] ?? 1) as num).toDouble();
                  sumPercent += (total > 0 ? (score / total) * 100 : 0);

                  if (rd['wrong_answers'] != null) {
                    final List<dynamic> wrongs = rd['wrong_answers'];
                    for (var w in wrongs) {
                      if (w is Map) {
                        String? word = w['correct']?.toString();
                        if (word == null || word.isEmpty) {
                          word = w['recognized']?.toString();
                        }
                        if (word != null && word.isNotEmpty) {
                          wrongWordsCount[word] =
                              (wrongWordsCount[word] ?? 0) + 1;
                        }
                      }
                    }
                  }
                }
                avgScore = sumPercent / attempts;
              }

              return {
                ...data,
                'doc_id': doc.id,
                'attempts': attempts,
                'avg_score': avgScore,
                'wrong_words': wrongWordsCount,
              };
            } catch (e) {
              debugPrint('Error loading student ${data['username']}: $e');
              return {
                ...data,
                'doc_id': doc.id,
                'attempts': 0,
                'avg_score': 0.0,
                'wrong_words': <String, int>{},
              };
            }
          }).toList();

      final results = await Future.wait(studentFutures);
      final students = results.whereType<Map<String, dynamic>>().toList();

      students.sort((a, b) {
        final aGrade = int.tryParse(a['class_level']?.toString() ?? '0') ?? 0;
        final bGrade = int.tryParse(b['class_level']?.toString() ?? '0') ?? 0;
        if (aGrade != bGrade) return aGrade.compareTo(bGrade);

        final aNum = int.tryParse(a['student_number']?.toString() ?? '0') ?? 0;
        final bNum = int.tryParse(b['student_number']?.toString() ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('loadStudents error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_selectedGrade == 'ทั้งหมด') return _students;
    final grade = _selectedGrade.replaceAll('ป.', '');
    return _students.where((s) => s['class_level'] == grade).toList();
  }

  Future<void> _showAddStudentDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const StudentFormDialog(title: 'เพิ่มนักเรียน'),
    );

    if (result != null) {
      if (!mounted) return;
      try {
        final existing =
            await _firestore
                .collection('users')
                .where('username', isEqualTo: result['username'])
                .get();

        if (!mounted) return;

        if (existing.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Username "${result['username']}" ซ้ำ',
                style: GoogleFonts.mali(),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _firestore.collection('users').add({
          'username': result['username'],
          'password': result['password'],
          'first_name': result['first_name'],
          'last_name': result['last_name'],
          'class_level': result['class_level'],
          'student_number': result['student_number'],
          'role': 'student',
          'created_at': Timestamp.now(),
          'is_active': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เพิ่มนักเรียนสำเร็จ ✅', style: GoogleFonts.mali()),
              backgroundColor: Colors.green,
            ),
          );
          _loadStudents();
        }
      } catch (e) {
        debugPrint('Error adding student: $e');
      }
    }
  }

  //  โปรโหมด
  Future<void> _promoteAll() async {
  final students = _filteredStudents;
  if (students.isEmpty) return;
  final grade = _selectedGrade;
  final levelNum = grade.replaceAll('ป.', '');

  if (levelNum == '3') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เลื่อนชั้นไม่ได้', style: GoogleFonts.mali()),
          backgroundColor: Colors.orange),
    );
    return;
  }

  final newLevel = (int.parse(levelNum) + 1).toString();

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('เลื่อนชั้น', style: GoogleFonts.mali(fontWeight: FontWeight.bold)),
      content: Text(
        'เลื่อนนักเรียน $grade ทั้งหมด ${students.length} คน → ป.$newLevel ?',
        style: GoogleFonts.mali(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('ยกเลิก', style: GoogleFonts.mali()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text('ยืนยัน', style: GoogleFonts.mali(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true || !mounted) return;

  final batch = _firestore.batch();
  for (final s in students) {
    batch.update(
      _firestore.collection('users').doc(s['doc_id']),
      {'class_level': newLevel, 'promoted_at': Timestamp.now()},
    );
  }
  await batch.commit();

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เลื่อนชั้นสำเร็จ ${students.length} คน ✅', style: GoogleFonts.mali()),
        backgroundColor: Colors.green,
      ),
    );
    _loadStudents();
  }
}
  Future<void> _showEditStudentDialog(Map<String, dynamic> student) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (_) =>
              StudentFormDialog(title: 'แก้ไขนักเรียน', initialData: student),
    );

    if (result != null) {
      if (!mounted) return;
      try {
        final docId = student['doc_id'] as String;

        await _firestore.collection('users').doc(docId).update({
          'first_name': result['first_name'],
          'last_name': result['last_name'],
          'class_level': result['class_level'],
          'student_number': result['student_number'],
          'updated_at': Timestamp.now(),
        });

        if (result['password'] != null && result['password']!.isNotEmpty) {
          await _firestore.collection('users').doc(docId).update({
            'password': result['password'],
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('แก้ไขข้อมูลสำเร็จ ✅', style: GoogleFonts.mali()),
              backgroundColor: Colors.green,
            ),
          );
          _loadStudents();
        }
      } catch (e) {
        debugPrint('Error editing student: $e');
      }
    }
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('ยืนยันการลบ', style: GoogleFonts.mali()),
            content: Text(
              'ต้องการลบ ${student['first_name']} ใช่หรือไม่?',
              style: GoogleFonts.mali(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก', style: GoogleFonts.mali()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('ลบ', style: GoogleFonts.mali()),
              ),
            ],
          ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final docId = student['doc_id'] as String;
        await _firestore.collection('users').doc(docId).update({
          'is_active': false,
          'deleted_at': Timestamp.now(),
          'deleted_by': _teacherUsername,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบนักเรียนสำเร็จ ✅', style: GoogleFonts.mali()),
              backgroundColor: Colors.green,
            ),
          );
          _loadStudents();
        }
      } catch (e) {
        debugPrint('Error deleting student: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รายชื่อนักเรียน',
          style: GoogleFonts.mali(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [


          // โปรหมด
          if (_selectedGrade != 'ทั้งหมด')
    IconButton(
      icon: const Icon(Icons.arrow_upward, color: Colors.orange),
      tooltip: 'เลื่อนชั้นทั้ง ${_selectedGrade}',
      onPressed: _promoteAll,
    ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _grades.map((grade) {
                      final isSelected = _selectedGrade == grade;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(grade),
                          labelStyle: GoogleFonts.mali(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          selected: isSelected,
                          onSelected:
                              (val) => setState(() => _selectedGrade = grade),
                          selectedColor: const Color(0xFF7C3AED),
                          backgroundColor: Colors.grey[100],
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _filteredStudents.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่มีนักเรียนในชั้นนี้',
                            style: GoogleFonts.mali(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredStudents.length,
                      itemBuilder: (_, i) {
                        final s = _filteredStudents[i];
                        final avg = (s['avg_score'] as double?) ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: 12,
                            left: 16,
                            right: 16,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.mali(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${s['first_name']} ${s['last_name']}',
                                      style: GoogleFonts.mali(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ชั้น ป.${s['class_level']} เลขที่ ${s['student_number']}',
                                      style: GoogleFonts.mali(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${s['attempts']} ครั้ง',
                                            style: GoogleFonts.mali(
                                              fontSize: 12,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                avg >= 80
                                                    ? Colors.green.shade50
                                                    : avg >= 60
                                                    ? Colors.orange.shade50
                                                    : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${avg.toStringAsFixed(0)}%',
                                            style: GoogleFonts.mali(
                                              fontSize: 12,
                                              color:
                                                  avg >= 80
                                                      ? Colors.green.shade700
                                                      : avg >= 60
                                                      ? Colors.orange.shade700
                                                      : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _showEditStudentDialog(s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteStudent(s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => StudentDetailScreen(
                                            student: s,
                                            teacherUsername: _teacherUsername,
                                            classLevel:
                                                s['class_level']
                                                    .toString(), //  ส่งระดับชั้นไปด้วย
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'เพิ่มนักเรียน',
          style: GoogleFonts.mali(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class StudentFormDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  const StudentFormDialog({super.key, required this.title, this.initialData});
  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  String? selectedClass;
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
  final _studentNumberCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  bool get _isEdit => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final data = widget.initialData!;
      _firstNameCtl.text = data['first_name'] ?? '';
      _lastNameCtl.text = data['last_name'] ?? '';
      selectedClass = data['class_level']?.toString();
      _studentNumberCtl.text = data['student_number']?.toString() ?? '';
      _usernameCtl.text = data['username'] ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _studentNumberCtl.dispose();
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'first_name': _firstNameCtl.text.trim(),
        'last_name': _lastNameCtl.text.trim(),
        'class_level': selectedClass!,
        'student_number': _studentNumberCtl.text.trim(),
        'username': _usernameCtl.text.trim(),
        'password': _passwordCtl.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: GoogleFonts.mali(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameCtl,
                style: GoogleFonts.mali(),
                decoration: InputDecoration(
                  labelText: 'ชื่อจริง',
                  labelStyle: GoogleFonts.mali(),
                  border: const OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtl,
                style: GoogleFonts.mali(),
                decoration: InputDecoration(
                  labelText: 'นามสกุล',
                  labelStyle: GoogleFonts.mali(),
                  border: const OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'กรุณากรอกนามสกุล'
                            : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedClass,
                hint: Text("ระดับชั้น", style: GoogleFonts.mali()),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items:
                    ["1", "2", "3"]
                        .map(
                          (classLevel) => DropdownMenuItem(
                            value: classLevel,
                            child: Text(
                              'ป.$classLevel',
                              style: GoogleFonts.mali(),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => selectedClass = value),
                validator:
                    (value) => value == null ? 'กรุณาเลือกชั้นเรียน' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentNumberCtl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.mali(),
                decoration: InputDecoration(
                  labelText: 'เลขที่',
                  labelStyle: GoogleFonts.mali(),
                  border: const OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'กรุณากรอกเลขที่'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtl,
                style: GoogleFonts.mali(),
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: GoogleFonts.mali(),
                  border: const OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        !_isEdit && (v == null || v.trim().isEmpty)
                            ? 'กรุณากรอก username'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtl,
                obscureText: true,
                style: GoogleFonts.mali(),
                decoration: InputDecoration(
                  labelText: _isEdit ? 'รหัสผ่านใหม่ (ถ้ามี)' : 'รหัสผ่าน',
                  labelStyle: GoogleFonts.mali(),
                  border: const OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        !_isEdit &&
                                (v == null || v.trim().isEmpty || v.length < 4)
                            ? 'รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร'
                            : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก', style: GoogleFonts.mali(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
          ),
          child: Text('บันทึก', style: GoogleFonts.mali()),
        ),
      ],
    );
  }
}

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final String? teacherUsername;
  final String classLevel; // ✅ เพิ่มตัวแปรรับระดับชั้น

  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.teacherUsername,
    required this.classLevel,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _quizResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizResults();
  }

  Future<void> _loadQuizResults() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snap =
          await _firestore
              .collection('quiz_results')
              .where('username', isEqualTo: widget.student['username'])
              .orderBy('timestamp', descending: true)
              .get();

      if (mounted) {
        setState(() {
          _quizResults = snap.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = (widget.student['avg_score'] as double?) ?? 0;
    final wrongWords =
        widget.student['wrong_words'] as Map<String, dynamic>? ?? {};
    final sortedWords =
        wrongWords.entries.toList()
          ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: Text(
          '${widget.student['first_name']}',
          style: GoogleFonts.mali(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ส่วนแสดงข้อมูลสรุปนักเรียน (เหมือนเดิม)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.purple.shade100,
                                  child: Text(
                                    (widget.student['first_name'] ?? '?')
                                        .toString()[0],
                                    style: GoogleFonts.mali(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.student['first_name']} ${widget.student['last_name']}',
                                        style: GoogleFonts.mali(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'ชั้น ป.${widget.student['class_level']} เลขที่ ${widget.student['student_number']}',
                                        style: GoogleFonts.mali(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _statBox(
                                    'ทำแบบฝึก',
                                    '${widget.student['attempts']} ครั้ง',
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statBox(
                                    'คะแนนเฉลี่ย',
                                    '${avg.toStringAsFixed(0)}%',
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (sortedWords.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'คำที่ผิดบ่อย',
                                style: GoogleFonts.mali(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    sortedWords
                                        .take(6)
                                        .map(
                                          (e) => Chip(
                                            label: Text(e.key),
                                            avatar: CircleAvatar(
                                              backgroundColor:
                                                  Colors.red.shade100,
                                              radius: 10,
                                              child: Text('${e.value}'),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text(
                        'ประวัติการทำแบบฝึกหัด',
                        style: GoogleFonts.mali(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _quizResults.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'ยังไม่มีข้อมูล',
                              style: GoogleFonts.mali(color: Colors.grey),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _quizResults.length,
                            itemBuilder: (_, i) {
                              final data =
                                  _quizResults[i].data()
                                      as Map<String, dynamic>;
                              final score = data['score'] ?? 0;
                              final total = data['total'] ?? 0;
                              final percent =
                                  total > 0
                                      ? ((score / total) * 100).round()
                                      : 0;
                              final category = data['category'] ?? '';
                              final ts = data['timestamp'] as Timestamp?;
                              final dateStr =
                                  ts != null
                                      ? DateFormat(
                                        'dd/MM/yyyy HH:mm',
                                      ).format(ts.toDate())
                                      : '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        percent >= 80
                                            ? Colors.green.shade100
                                            : percent >= 60
                                            ? Colors.orange.shade100
                                            : Colors.red.shade100,
                                    child: Text(
                                      '$percent%',
                                      style: GoogleFonts.mali(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    category,
                                    style: GoogleFonts.mali(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$score/$total คะแนน • $dateStr',
                                    style: GoogleFonts.mali(fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => QuizDetailScreen(
                                              quizId: _quizResults[i].id,
                                              quizData: data,
                                              teacherUsername:
                                                  widget.teacherUsername,
                                              studentClass:
                                                  widget
                                                      .classLevel, // ✅ ส่งระดับชั้นต่อ
                                            ),
                                      ),
                                    ).then((_) => _loadQuizResults());
                                  },
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _statBox(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.mali(fontSize: 12, color: color.shade900),
          ),
          Text(
            value,
            style: GoogleFonts.mali(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// หน้ารายละเอียดแบบฝึกหัด (เพิ่มการเชื่อมต่อกับ ReadingArticle)
class QuizDetailScreen extends StatefulWidget {
  final String quizId;
  final Map<String, dynamic> quizData;
  final String? teacherUsername;
  final String studentClass; // ✅ รับระดับชั้นมาด้วย

  const QuizDetailScreen({
    super.key,
    required this.quizId,
    required this.quizData,
    required this.teacherUsername,
    required this.studentClass,
  });

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _feedbackCtl = TextEditingController();
  bool _isSending = false;
  List<String> _articleLines = []; // เก็บเนื้อหาบทความ
  bool _isLoadingArticle = false;

  @override
  void initState() {
    super.initState();
    _feedbackCtl.text = widget.quizData['feedback'] ?? '';
    if (_isReadingArticle()) {
      _loadReadingArticleContent();
    }
  }

  bool _isReadingArticle() {
    final cat = widget.quizData['category'].toString().toLowerCase();
    return cat.contains('readingarticle') ||
        cat.contains('อ่านบทความ') ||
        cat.contains('อ่านยาว') ||
        cat.contains('reading_article');
  }

  Future<void> _loadReadingArticleContent() async {
    setState(() => _isLoadingArticle = true);
    try {
      // 1. ระบุ path: questions -> g_{class} -> ReadingArticle
      final gradeCollection = 'g_${widget.studentClass}';

      // 2. หา document ID
      // สมมติว่า quizData['quiz_id'] เก็บ ID ของคำถามไว้ (เช่น '01')
      // หรือถ้า quizData['title'] เก็บชื่อ เช่น '01' ก็ใช้ได้
      // ต้องดูว่าตอนบันทึก quiz_results บันทึกอะไรไว้บ้าง
      // ลองใช้ quiz_id หรือ title ในการค้นหา
      String docId =
          widget.quizData['quiz_id']?.toString() ??
          widget.quizData['title']?.toString() ??
          '';

      // ถ้า docId เป็นชื่อไทย อาจจะต้องไป query หา ID ก่อน แต่ถ้าเก็บ ID ไว้แล้วก็ใช้ได้เลย
      // กรณีนี้ลองดึงตรงๆ ดูก่อน

      DocumentSnapshot doc =
          await _firestore
              .collection('questions')
              .doc(gradeCollection)
              .collection('ReadingArticle')
              .doc(docId) // ลองใช้ ID ตรงๆ
              .get();

      if (!doc.exists) {
        // ถ้าไม่เจอ ลอง Query ด้วย title (กรณีเก็บ title ไว้แต่ไม่ใช่ ID)
        final query =
            await _firestore
                .collection('questions')
                .doc(gradeCollection)
                .collection('ReadingArticle')
                .where(
                  'title',
                  isEqualTo: widget.quizData['category'],
                ) // หรือ field อื่นที่ตรงกัน
                .limit(1)
                .get();

        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['lines'] != null) {
          setState(() {
            _articleLines = List<String>.from(data['lines']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading article: $e');
    } finally {
      if (mounted) setState(() => _isLoadingArticle = false);
    }
  }

  Future<void> _sendFeedback() async {
    if (_feedbackCtl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await _firestore.collection('quiz_results').doc(widget.quizId).update({
        'feedback': _feedbackCtl.text.trim(),
        'feedback_by': widget.teacherUsername,
        'feedback_at': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งคำแนะนำแล้ว', style: GoogleFonts.mali()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.quizData['score'] ?? 0;
    final total = widget.quizData['total'] ?? 0;
    final percent = total > 0 ? ((score / total) * 100).round() : 0;
    final rawWrongAnswers = widget.quizData['wrong_answers'];
    final List<dynamic> wrongAnswers =
        rawWrongAnswers is List ? rawWrongAnswers : [];

    // ดึงคำที่ผิดออกมาเป็น Set เพื่อเอาไปเช็ค Highlight
    final Set<String> wrongWordsSet = {};
    for (var w in wrongAnswers) {
      if (w is Map) {
        wrongWordsSet.add(w['correct']?.toString() ?? '');
        wrongWordsSet.add(w['recognized']?.toString() ?? '');
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
        title: Text(
          'ผลการทดสอบ',
          style: GoogleFonts.mali(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // การ์ดคะแนน (เหมือนเดิม)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '$percent%',
                    style: GoogleFonts.mali(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color:
                          percent >= 80
                              ? Colors.green
                              : percent >= 60
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  Text(
                    '$score / $total คะแนน',
                    style: GoogleFonts.mali(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.quizData['category'] ?? '',
                    style: GoogleFonts.mali(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ส่วนแสดงเนื้อหาบทความ (ถ้ามี)
            if (_isReadingArticle()) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เนื้อหาที่อ่าน',
                      style: GoogleFonts.mali(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingArticle
                        ? const Center(child: CircularProgressIndicator())
                        : _articleLines.isEmpty
                        ? Text(
                          'ไม่พบเนื้อหาบทความ',
                          style: GoogleFonts.mali(color: Colors.grey),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              _articleLines.map((line) {
                                // แยกคำในบรรทัดเพื่อ Highlight คำผิด (แบบง่ายๆ)
                                // ถ้าจะให้แม่นยำต้องใช้ logic ตัดคำไทย แต่นี่เช็คแบบ contains คร่าวๆ
                                bool hasError = false;
                                for (var w in wrongWordsSet) {
                                  if (w.isNotEmpty && line.contains(w)) {
                                    hasError = true;
                                    break;
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    line,
                                    style: GoogleFonts.mali(
                                      fontSize: 16,
                                      color:
                                          hasError
                                              ? Colors.red
                                              : Colors
                                                  .black87, // เปลี่ยนสีถ้าบรรทัดนี้มีคำผิด
                                      fontWeight:
                                          hasError
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                  ],
                ),
              ),
            ],

            // ส่วนแสดงคำผิด (List ด้านล่าง เหมือนเดิม)
            if (wrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'คำที่ตอบผิด (${wrongAnswers.length} คำ)',
                          style: GoogleFonts.mali(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...wrongAnswers.map((w) {
                      final wMap =
                          w is Map
                              ? Map<String, dynamic>.from(w)
                              : <String, dynamic>{};
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ข้อที่ ${wMap['index'] ?? wMap['number'] ?? '-'}',
                              style: GoogleFonts.mali(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'พูดว่า: "${wMap['recognized'] ?? ''}"',
                              style: GoogleFonts.mali(fontSize: 13),
                            ),
                            Text(
                              'ควรพูด: "${wMap['correct'] ?? wMap['word'] ?? ''}"',
                              style: GoogleFonts.mali(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // กล่องส่ง Feedback (เหมือนเดิม)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ส่งคำแนะนำ',
                    style: GoogleFonts.mali(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackCtl,
                    maxLines: 3,
                    style: GoogleFonts.mali(),
                    decoration: InputDecoration(
                      hintText: 'พิมพ์คำแนะนำ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                      child:
                          _isSending
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text('ส่ง', style: GoogleFonts.mali()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
