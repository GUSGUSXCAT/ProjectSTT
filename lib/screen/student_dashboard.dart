///ปจบ.ใช้หน้านี้
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:LumoRead/screen/TopicRouter_Univer.dart';
import 'package:LumoRead/screen/guidepage.dart';
import 'package:LumoRead/screen/helppage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:LumoRead/screen/Login.dart';
import 'package:LumoRead/screen/ResultChart.dart';
import 'package:LumoRead/screen/Profilescreen.dart';

class StudentDashboard extends StatefulWidget {
  final String classLevel;
  const StudentDashboard({super.key, required this.classLevel});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _classLevel = '';
  String _fullName = '';
  bool _classReady = false;
  String _username = '';

  List<Map<String, dynamic>> _topics = [];
  bool _loadingTopics = false;

  bool _isMobile(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return kIsWeb ? w < 768 : w < 600;
  }

  Future<void> _loadFromSP() async {
    final sp = await SharedPreferences.getInstance();
    final lv = sp.getString('class_level') ?? '';
    final name = sp.getString('username') ?? '';
    if (!mounted) return;
    setState(() {
      _classLevel = lv;
      _username = name;
      _classReady = true;
    });

    if (_classLevel.isNotEmpty) {
      _loadTopics();
    }
  }

  Future<void> _loadUserFullName() async {
    final sp = await SharedPreferences.getInstance();
    final username = sp.getString('username');

    if (username == null || username.isEmpty) return;

    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (qs.docs.isNotEmpty) {
      final data = qs.docs.first.data();
      final firstName = data['first_name'] ?? '';
      final lastName = data['last_name'] ?? '';
      setState(() {
        _fullName = '$firstName $lastName';
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _loadUserFullName();

    if (widget.classLevel.isNotEmpty) {
      _classLevel = widget.classLevel;
      _classReady = true;
      _loadTopics();
    } else {
      _loadFromSP();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    if (_classLevel.isEmpty) return;

    setState(() => _loadingTopics = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exercise_topics')
          .where('grade', isEqualTo: _classLevel)
          .where('is_active', isEqualTo: true)
          .get();

      final topics = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        topics.add({
          'id': doc.id,
          'name_th': data['name_th'] ?? '',
          'name_en': data['name_en'] ?? '',
          'classify': data['classify'] ?? '',
          'mode': data['mode'] ?? 'speech',
          'main_screen_type': data['main_screen_type'] ?? '',
          'icon': data['icon'] ?? '📚',
          'color': data['color'] ?? '#90CAF9',
          'order': data['order'] ?? 0,
        });
      }

      topics.sort((a, b) => a['order'].compareTo(b['order']));

      setState(() {
        _topics = topics;
        _loadingTopics = false;
      });
    } catch (e) {
      setState(() => _loadingTopics = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('sounds/mixkit-game-click-1114.mp3'));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_classReady) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFAF0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('กำลังโหลด...', style: GoogleFonts.mali()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                if (!_isMobile(context)) _buildSidebar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isMobile(context) ? 16 : 32, // ✅ แก้แล้ว
                          vertical: 32,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_loadingTopics)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_topics.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      'ยังไม่มีหัวข้อสำหรับชั้น $_classLevel',
                                      style: GoogleFonts.mali(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                _buildDynamicTopics(),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── greeting chip ──
            Positioned(
              top: 20,
              right: 30,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 5),
                  ],
                ),
                child: Text(
                  '👤 สวัสดี $_fullName ชั้น ป.$_classLevel 👋',
                  style: GoogleFonts.mali(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 10,
              right: 10,
              child: Image.asset(
                'images/reading.png',
                width: 120,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicTopics() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final topic in _topics) {
      final classify = topic['classify'] as String;
      final groupKey = classify.isEmpty ? 'อื่นๆ' : classify;
      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(topic);
    }

    if (grouped.length == 1 && grouped.containsKey('อื่นๆ')) {
      return _buildTopicGroup('📚 แบบฝึกหัดทั้งหมด', _topics);
    }

    final widgets = <Widget>[];
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      widgets.add(_buildTopicGroup(_getGroupTitle(key), grouped[key]!));
      widgets.add(const SizedBox(height: 32));
    }

    return Column(children: widgets);
  }

  String _getGroupTitle(String classify) {
    const titles = {
      'consonants': '🔤 พยัญชนะ',
      'vowels': '🔠 สระ',
      'vowel_single': '📝 สระเดี่ยว',
      'vowel_compound': '📖 สระประสม',
      'tones': '🎵 วรรณยุกต์',
      'consonant_clusters': '✨ พยัญชนะควบกล้ำ',
      'leading_consonants': '💐 อักษรนำ',
      'trailing_consonants': '📣 มาตราตัวสะกด',
      'reading': '📖 การอ่าน',
      'reading_article': '📰 อ่านบทความ',
      'reading_story': '📚 อ่านนิทาน',
      'spelling': '✍️ การสะกดคำ',
      'vocabulary': '📝 คำศัพท์',
      'sentence': '💬 ประโยค',
      'grammar': '📐 ไวยากรณ์',
      'อื่นๆ': '📚 แบบฝึกหัด',
    };
    return titles[classify] ?? '📚 $classify';
  }

  Widget _buildTopicGroup(String title, List<Map<String, dynamic>> topics) {
    // ✅ คำนวณขนาดปุ่มตาม screen size — ทำที่นี่ถูกต้อง ไม่ใช่ใน Wrap parameter
    final double btnWidth = _isMobile(context) ? 140 : 160;
    final double btnHeight = 120;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.mali(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // ✅ Wrap ที่ถูกต้อง — ไม่มีโค้ดปนใน parameter
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: topics
                .map((t) => _buildTopicButton(t, btnWidth, btnHeight))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicButton(
    Map<String, dynamic> topic,
    double width,
    double height,
  ) {
    final name = topic['name_th'] as String;
    final icon = topic['icon'] as String;
    final colorHex = topic['color'] as String;

    Color buttonColor;
    try {
      buttonColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    } catch (e) {
      buttonColor = Colors.blue.shade200;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          _playSound();
          TopicRouter.navigate(context, topic, _classLevel);
        },
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mali(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 30),
          Text(
            "LumoRead",
            style: GoogleFonts.mali(fontSize: 24, color: Colors.blueAccent),
          ),
          const SizedBox(height: 30),
          _buildSidebarItem("🅰️", "การเรียนรู้", isActive: true),
          _buildSidebarItem(
            "🌟",
            "ประวัติคะแนน",
            onTap: () => _navigate(ResultChartScreen()),
          ),
          _buildSidebarItem(
            "👤",
            "โปรไฟล์",
            onTap: () => _navigate(const ProfileScreen()),
          ),
          _buildSidebarItem(
            "📖",
            "คู่มือ",
            onTap: () => _navigate(GuidePage()),
          ),
          _buildSidebarItem(
            "❓",
            "ช่วยเหลือ",
            onTap: () => _navigate(HelpPage()),
          ),
          _buildSidebarItem("⬅️", "ออกจากระบบ", onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    String icon,
    String label, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      color: isActive ? Colors.lightGreen.shade100 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          label,
          style: GoogleFonts.mali(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}