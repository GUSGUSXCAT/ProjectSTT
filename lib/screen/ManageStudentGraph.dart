import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class ManageStudentGraphScreen extends StatefulWidget {
  const ManageStudentGraphScreen({super.key, required String studentId});

  @override
  State<ManageStudentGraphScreen> createState() =>
      _ManageStudentGraphScreenState();
}

class _ManageStudentGraphScreenState extends State<ManageStudentGraphScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // UI Colors
  final Color primaryColor = const Color(0xFF7C3AED);
  final Color backgroundColor = const Color(0xFFF3F4F6);
  final Color darkTextColor = const Color(0xFF111827);

  // State
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> allResults = [];
  Map<String, Map<String, dynamic>> usersMap = {};
  List<String> studentNames = [];
  String? selectedStudent;
  String viewMode = 'individual';
  String? selectedCategory;
  List<String> categories = [];

  // Filters
  String selectedClassLevel = 'ทั้งหมด';
  final List<String> classLevels = ['ทั้งหมด', 'ป.1', 'ป.2', 'ป.3'];

  // Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          viewMode = _tabController.index == 0 ? 'individual' : 'group';
          _updateDropdowns();
        });
      }
    });
    fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateDropdowns() {
    var tempResults = allResults;

    if (selectedClassLevel != 'ทั้งหมด') {
      final levelNum = selectedClassLevel.replaceAll('ป.', '');
      tempResults =
          tempResults
              .where((r) => r['class_level']?.toString() == levelNum)
              .toList();
    }

    final newNames =
        tempResults
            .map((r) => r['full_name'] as String)
            .toSet()
            .where((name) => name.isNotEmpty && name != 'ไม่ระบุชื่อ')
            .toList()
          ..sort();

    studentNames = newNames;

    if (viewMode == 'individual' && !studentNames.contains(selectedStudent)) {
      selectedStudent = studentNames.isNotEmpty ? studentNames.first : null;
    }

    var categoryResults = tempResults;
    if (viewMode == 'individual' && selectedStudent != null) {
      categoryResults =
          tempResults.where((r) => r['full_name'] == selectedStudent).toList();
    } else if (viewMode == 'group') {
      categoryResults = tempResults;
    }

    final newCategories =
        categoryResults
            .map((r) => r['category'] as String)
            .toSet()
            .where((cat) => cat.isNotEmpty)
            .toList()
          ..sort();

    categories = newCategories;

    if (selectedCategory != null && !categories.contains(selectedCategory)) {
      selectedCategory = null;
    }
  }

  List<Map<String, String>> lowScoreAlerts = [];

  void _findLowScoreAlerts() {
    final List<Map<String, String>> alerts = [];

    // จับกลุ่มตาม category
    final Map<String, List<Map<String, dynamic>>> byCategory = {};
    for (final r in allResults) {
      final cat = r['category'] as String;
      byCategory.putIfAbsent(cat, () => []);
      byCategory[cat]!.add(r);
    }

    byCategory.forEach((category, results) {
      // นับคนที่ได้ต่ำกว่า 50% ในหมวดนี้
      final Set<String> lowNames = {};
      for (final r in results) {
        final score = (r['score'] as num).toDouble();
        final total = (r['total'] as num).toDouble();
        if (total <= 0) continue;
        if ((score / total) * 100 < 50) {
          final name = r['full_name'] as String;
          if (name.isNotEmpty && name != 'ไม่ระบุชื่อ') lowNames.add(name);
        }
      }

      if (lowNames.isNotEmpty) {
        alerts.add({
          'category': category,
          'count': '${lowNames.length}',
          'names': lowNames.take(3).join(', '),
        });
      }
    });

    alerts.sort(
      (a, b) => int.parse(b['count']!).compareTo(int.parse(a['count']!)),
    );
    setState(() => lowScoreAlerts = alerts);
  }

  Future<void> fetchAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final usersSnapshot = await _firestore.collection('users').get();
      usersMap.clear();
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final username = data['username']?.toString() ?? '';
        if (username.isNotEmpty) {
          usersMap[username] = {
            'first_name': data['first_name'] ?? '',
            'last_name': data['last_name'] ?? '',
            'role': data['role'] ?? 'student',
            'class_level': data['class_level'] ?? '',
          };
        }
      }

      final quizSnapshot = await _firestore.collection('quiz_results').get();
      final results = <Map<String, dynamic>>[];

      for (final doc in quizSnapshot.docs) {
        final data = doc.data();
        final username = data['username']?.toString() ?? '';

        String fullName = '';
        String userRole = 'student';
        String classLevel = '';

        if (usersMap.containsKey(username)) {
          final user = usersMap[username]!;
          final firstName = user['first_name']?.toString().trim() ?? '';
          final lastName = user['last_name']?.toString().trim() ?? '';

          fullName = '$firstName $lastName'.trim();
          userRole = user['role'] ?? 'student';
          classLevel = user['class_level'] ?? '';
        }
        // ถ้า quiz_results มี class_level เก็บไว้ ใช้ตัวนั้น
        if (data['class_level'] != null &&
            data['class_level'].toString().isNotEmpty) {
          classLevel = data['class_level'].toString();
        }

        if (fullName.isEmpty) {
          fullName = data['full_name']?.toString().trim() ?? '';
        }

        if (fullName.isEmpty) {
          fullName = username.isNotEmpty ? username : 'ไม่ระบุชื่อ';
        }

        if (userRole == 'teacher') continue;

        results.add({
          'id': doc.id,
          'username': username,
          'full_name': fullName,
          'score': data['score'] ?? 0,
          'total': data['total'] ?? 0,
          'timestamp': data['timestamp'] as Timestamp?,
          'category': data['category'] ?? 'ไม่ระบุหมวดหมู่',
          'title': data['title'] ?? data['category'] ?? '',
          'class_level': classLevel,
          'wrong_answers': data['wrong_answers'] ?? [],
        });
      }

      results.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      setState(() {
        allResults = results;
        _updateDropdowns();
        isLoading = false;
      });
    } catch (e) {
      _findLowScoreAlerts();
      setState(() {
        isLoading = false;
        errorMessage = 'ไม่สามารถดึงข้อมูลได้: ${e.toString()}';
      });
    }
  }

  List<Map<String, dynamic>> getFilteredResults() {
    var filtered = allResults;

    if (selectedClassLevel != 'ทั้งหมด') {
      final levelNum = selectedClassLevel.replaceAll('ป.', '');
      filtered =
          filtered
              .where((r) => r['class_level']?.toString() == levelNum)
              .toList();
    }

    if (viewMode == 'individual' && selectedStudent != null) {
      filtered =
          filtered.where((r) => r['full_name'] == selectedStudent).toList();
    }

    if (selectedCategory != null) {
      filtered =
          filtered.where((r) => r['category'] == selectedCategory).toList();
    }

    return filtered;
  }

  double calculatePercent(int score, int total) {
    if (total <= 0) return 0;
    double percent = (score / total) * 100;
    if (percent > 100) return 100.0;
    return percent;
  }

  Map<String, dynamic> analyzeTrend(List<Map<String, dynamic>> results) {
    if (results.length < 2) {
      return {
        'trend': 'insufficient',
        'message': 'ข้อมูลไม่เพียงพอสำหรับวิเคราะห์ (ต้องทำ 2 ครั้งขึ้นไป)',
        'icon': Icons.info_outline,
        'color': Colors.grey,
      };
    }

    final half = results.length ~/ 2;
    final firstHalf = results.sublist(0, half);
    final secondHalf = results.sublist(half);

    double avgFirst =
        firstHalf.fold(
          0.0,
          (sum, r) =>
              sum + calculatePercent(r['score'] as int, r['total'] as int),
        ) /
        firstHalf.length;
    double avgSecond =
        secondHalf.fold(
          0.0,
          (sum, r) =>
              sum + calculatePercent(r['score'] as int, r['total'] as int),
        ) /
        secondHalf.length;

    final diff = avgSecond - avgFirst;

    if (diff > 5) {
      return {
        'trend': 'improving',
        'message': 'พัฒนาการดีขึ้น (+${diff.toStringAsFixed(2)}%)',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    } else if (diff < -5) {
      return {
        'trend': 'declining',
        'message': 'พัฒนาการลดลง (${diff.toStringAsFixed(2)}%)',
        'icon': Icons.trending_down,
        'color': Colors.red,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    } else {
      return {
        'trend': 'stable',
        'message': 'พัฒนาการคงที่',
        'icon': Icons.trending_flat,
        'color': Colors.orange,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    }
  }

  Map<String, dynamic> analyzeGroupTrend(Map<String, List<FlSpot>> groupData) {
    double totalFirstAvg = 0;
    double totalSecondAvg = 0;
    int validStudentsCount = 0;

    groupData.forEach((name, spots) {
      if (spots.length >= 2) {
        final half = spots.length ~/ 2;
        final firstHalf = spots.sublist(0, half);
        final secondHalf = spots.sublist(half);

        final firstAvg =
            firstHalf.fold(0.0, (sum, s) => sum + s.y) / firstHalf.length;
        final secondAvg =
            secondHalf.fold(0.0, (sum, s) => sum + s.y) / secondHalf.length;

        totalFirstAvg += firstAvg;
        totalSecondAvg += secondAvg;
        validStudentsCount++;
      }
    });

    if (validStudentsCount == 0) {
      return {
        'trend': 'insufficient',
        'message': 'ข้อมูลไม่เพียงพอสำหรับวิเคราะห์ภาพรวม',
        'icon': Icons.info_outline,
        'color': Colors.grey,
      };
    }

    final avgFirst = totalFirstAvg / validStudentsCount;
    final avgSecond = totalSecondAvg / validStudentsCount;
    final diff = avgSecond - avgFirst;

    if (diff > 5) {
      return {
        'trend': 'improving',
        'message':
            'ภาพรวมพัฒนาการของกลุ่มดีขึ้น (+${diff.toStringAsFixed(2)}%)',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    } else if (diff < -5) {
      return {
        'trend': 'declining',
        'message': 'ภาพรวมพัฒนาการของกลุ่มลดลง (${diff.toStringAsFixed(2)}%)',
        'icon': Icons.trending_down,
        'color': Colors.red,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    } else {
      return {
        'trend': 'stable',
        'message': 'ภาพรวมพัฒนาการของกลุ่มคงที่',
        'icon': Icons.trending_flat,
        'color': Colors.orange,
        'avgFirst': avgFirst,
        'avgSecond': avgSecond,
      };
    }
  }

  List<FlSpot> getIndividualChartData(List<Map<String, dynamic>> results) {
    return results.asMap().entries.map((entry) {
      final percent = calculatePercent(
        entry.value['score'] as int,
        entry.value['total'] as int,
      );
      return FlSpot(entry.key.toDouble(), percent);
    }).toList();
  }

  Map<String, List<FlSpot>> getGroupChartData() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    var filtered = allResults;

    if (selectedClassLevel != 'ทั้งหมด') {
      final levelNum = selectedClassLevel.replaceAll('ป.', '');
      filtered =
          filtered
              .where((r) => r['class_level']?.toString() == levelNum)
              .toList();
    }

    if (selectedCategory != null) {
      filtered =
          filtered.where((r) => r['category'] == selectedCategory).toList();
    }

    for (final result in filtered) {
      final name = result['full_name'] as String;
      if (name.isEmpty || name == 'ไม่ระบุชื่อ') continue;
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(result);
    }

    final Map<String, List<FlSpot>> chartData = {};
    grouped.forEach((name, results) {
      chartData[name] =
          results.asMap().entries.map((entry) {
            final percent = calculatePercent(
              entry.value['score'] as int,
              entry.value['total'] as int,
            );
            return FlSpot(entry.key.toDouble(), percent);
          }).toList();
    });

    return chartData;
  }

  Color getStudentColor(int index) {
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF8B5CF6),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('รายงานพัฒนาการนักเรียน', style: GoogleFonts.mali()),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('รายงานพัฒนาการนักเรียน', style: GoogleFonts.mali()),
          backgroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (allResults.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('รายงานพัฒนาการนักเรียน', style: GoogleFonts.mali()),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: Text('ไม่พบข้อมูลผลการทำแบบฝึกหัด')),
      );
    }

    final filteredResults = getFilteredResults();
    final trendAnalysis = analyzeTrend(filteredResults);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'รายงานพัฒนาการนักเรียน',
          style: GoogleFonts.mali(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllData,
            tooltip: 'รีเฟรช',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.mali(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'รายบุคคล'),
            Tab(icon: Icon(Icons.groups), text: 'ภาพรวม'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterSection(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIndividualTab(filteredResults, trendAnalysis),
                    _buildGroupTab(),
                  ],
                ),
              ),
            ],
          ),

          if (lowScoreAlerts.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'แบบฝึกที่มีคนได้ต่ำกว่า 50%',
                            style: GoogleFonts.mali(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => lowScoreAlerts.clear()),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...lowScoreAlerts
                        .take(5)
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${d['category']} — ${d['count']} คน (${d['names']})',
                              style: GoogleFonts.mali(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  classLevels.map((g) {
                    final active = selectedClassLevel == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          g,
                          style: GoogleFonts.mali(
                            color: active ? Colors.white : Colors.black,
                          ),
                        ),
                        selected: active,
                        selectedColor: primaryColor,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedClassLevel = g;
                              _updateDropdowns();
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (viewMode == 'individual') ...[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    value:
                        studentNames.contains(selectedStudent)
                            ? selectedStudent
                            : null,
                    hint: Text('เลือกนักเรียน', style: GoogleFonts.mali()),
                    items:
                        studentNames
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  style: GoogleFonts.mali(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedStudent = v;
                        _updateDropdowns();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  value: selectedCategory,
                  hint: Text('ทุกหมวดหมู่', style: GoogleFonts.mali()),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        'ทุกหมวดหมู่',
                        style: GoogleFonts.mali(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...categories.map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: GoogleFonts.mali(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => selectedCategory = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualTab(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> trend,
  ) {
    if (results.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลของนักเรียนคนนี้'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (selectedCategory == null) ...[
            _buildBarChartCard(results, 'จำนวนครั้งที่ทำแยกตามหมวดหมู่'),
          ] else ...[
            _buildTrendCard(trend),
            const SizedBox(height: 16),
            _buildLineChartCard(getIndividualChartData(results), results),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupTab() {
    final groupData = getGroupChartData();
    if (groupData.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลสำหรับเปรียบเทียบ'));
    }

    final groupTrend = analyzeGroupTrend(groupData);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (selectedCategory == null) ...[
            _buildBarChartCard(
              () {
                //  ตัดซ้ำ เหลือแค่ 1 รายการ ต่อ 1 คน ต่อ 1 หมวด
                final uniqueStu = <String, Map<String, dynamic>>{};
                for (final r in getFilteredResults()) {
                  final key = '${r['full_name']}_${r['category']}';
                  uniqueStu.putIfAbsent(key, () => r);
                }
                return uniqueStu.values.toList();
              }(),
              'ภาพรวมการทำแบบฝึกหัดของชั้นเรียน',
              unit: 'คน',
            ),
          ] else ...[
            _buildTrendCard(groupTrend),
            const SizedBox(height: 16),
            _buildGroupChartCard(groupData),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendCard(Map<String, dynamic> trend) {
    return Card(
      color: (trend['color'] as Color).withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(
          trend['icon'] as IconData,
          color: trend['color'] as Color,
          size: 40,
        ),
        title: Text(
          trend['message'] as String,
          style: GoogleFonts.mali(
            fontWeight: FontWeight.bold,
            color: trend['color'] as Color,
          ),
        ),
        subtitle:
            trend['avgFirst'] != null
                ? Text(
                  'เฉลี่ยครึ่งแรก: ${(trend['avgFirst'] as double).toStringAsFixed(2)}% | เฉลี่ยครึ่งหลัง: ${(trend['avgSecond'] as double).toStringAsFixed(2)}%',
                  style: GoogleFonts.mali(),
                )
                : null,
      ),
    );
  }

  Widget _buildBarChartCard(
    List<Map<String, dynamic>> results,
    String title, {
    String unit = 'ครั้ง',
  }) {
    final Map<String, int> categoryCount = {};
    for (final result in results) {
      final category = result['category'] as String;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    var sortedCategories =
        categoryCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCategories.isEmpty) return const SizedBox.shrink();

    final int maxCount = sortedCategories.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.mali(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...sortedCategories.map((entry) {
            final percent = entry.value / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      entry.key,
                      style: GoogleFonts.mali(
                        fontSize: 13,
                        color: darkTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: 12,
                              width: constraints.maxWidth * percent,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${entry.value} $unit',
                      style: GoogleFonts.mali(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(
    List<FlSpot> chartData,
    List<Map<String, dynamic>> results,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คะแนน (%)',
            style: GoogleFonts.mali(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        // ดึงข้อมูลจริงจาก List results โดยใช้ index (x)
                        final index = barSpot.x.toInt();
                        if (index >= 0 && index < results.length) {
                          final data = results[index];
                          final score = data['score'];
                          final total = data['total'];
                          return LineTooltipItem(
                            '${barSpot.y.toStringAsFixed(2)}%\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: '($score/$total)', // แสดงคะแนนดิบ
                                style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        }
                        return LineTooltipItem(
                          '${barSpot.y.toStringAsFixed(2)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                    left: BorderSide(color: Colors.grey.shade400, width: 1),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget:
                          (value, meta) => Text(
                            '${value.toInt()}',
                            style: GoogleFonts.mali(fontSize: 10),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${(value.toInt() + 1)}',
                            style: GoogleFonts.mali(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    color: primaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ครั้งที่ทำ',
              style: GoogleFonts.mali(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChartCard(Map<String, List<FlSpot>> groupData) {
    final studentNamesList = groupData.keys.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คะแนน (%)',
            style: GoogleFonts.mali(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        //  ดึงชื่อเด็กจาก index ของเส้นกราฟ
                        final studentName = studentNamesList[barSpot.barIndex];

                        return LineTooltipItem(
                          '$studentName\n', //  โชว์ชื่อเด็กก่อน
                          GoogleFonts.mali(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${barSpot.y.toStringAsFixed(2)}%', // โชว์คะแนนสีเหลืองด้านล่าง
                              style: GoogleFonts.mali(
                                color: Colors.yellowAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                    left: BorderSide(color: Colors.grey.shade400, width: 1),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget:
                          (value, meta) => Text(
                            '${value.toInt()}',
                            style: GoogleFonts.mali(fontSize: 10),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),

                          child: Text(
                            '${(value.toInt() + 1)}',
                            style: GoogleFonts.mali(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData:
                    groupData.entries.toList().asMap().entries.map((entry) {
                      return LineChartBarData(
                        spots: entry.value.value,
                        color: getStudentColor(entry.key),
                        isCurved: true,
                        dotData: const FlDotData(show: true),
                      );
                    }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ครั้งที่ทำ',
              style: GoogleFonts.mali(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                groupData.keys.toList().asMap().entries.map((e) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: getStudentColor(e.key),
                      radius: 6,
                    ),
                    label: Text(e.value, style: GoogleFonts.mali(fontSize: 12)),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
