import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance; 

  bool _loading = true;
  bool _savingAvatar = false;

  String? _docId;
  String? _username;
  String _firstName = '';
  String _lastName  = '';
  String _classLv   = '';
  String _stunum   = '';
  String _role      = '';
  String _avatarUrl = '';

  List<_Recent> _recent = [];

  static const avatars = <String>[
    'assets/images/happy.png',
    'assets/images/nani.png',
    'assets/images/reading.png',
    'assets/images/wrong.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadProfile();
    await _loadProgress();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    _username = sp.getString('loggedInUsername') ?? sp.getString('username');

    DocumentSnapshot<Map<String, dynamic>>? userDoc;

    if (_username != null && _username!.isNotEmpty) {
      final qs = await _fs
          .collection('users')
          .where('username', isEqualTo: _username)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        userDoc = qs.docs.first;
      }
    }

    if (userDoc == null) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _fs.collection('users').doc(uid).get();
        if (doc.exists) userDoc = doc;
      }
    }

    if (userDoc == null || !userDoc.exists) return;

    final m = userDoc.data()!;
    _docId     = userDoc.id;
    _username ??= (m['username'] ?? '').toString(); 
    _firstName = (m['first_name']  ?? '').toString();
    _lastName  = (m['last_name']   ?? '').toString();
    _classLv   = (m['class_level'] ?? '').toString();
    _role      = (m['role']        ?? '').toString();
    _avatarUrl = (m['avatar_url']  ?? '').toString();
    _stunum    = (m['student_number'] ?? '').toString();
  }

  Future<void> _loadProgress() async {
    if (_username == null) return;

    final snap = await _fs
        .collection('quiz_results')
        .where('username', isEqualTo: _username)
        .orderBy('timestamp', descending: true)
        .get();

    // เก็บ 8 รายการล่าสุด
    _recent = [];
    final list = snap.docs.take(8).toList().reversed.toList();
    for (final d in list) {
      final m = d.data();
      final s = ((m['score'] ?? 0) as num).toDouble();
      final t = ((m['total'] ?? 1)  as num).toDouble();
      final p = t <= 0 ? 0.0 : (s / t) * 100.0;

      final cat = (m['category'] ?? '').toString();
      String label = cat.isEmpty ? '-' : cat.split(' ').first; 
      if (m['timestamp'] is Timestamp) {
        final dt = (m['timestamp'] as Timestamp).toDate();
        label = '${dt.day}/${dt.month}'; 
      }

      final dt = m['timestamp'] is Timestamp ? (m['timestamp'] as Timestamp).toDate() : null;
      final when = dt == null ? '' : '${dt.day}/${dt.month}';
      _recent.add(_Recent(
        percent: p,
        label: label,
        hint: '$cat | ${s.toInt()}/${t.toInt()} | $when',
      ));
    }
  }

  Future<void> _pickAvatar() async {
    if (_docId == null) return;

    final path = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: avatars.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemBuilder: (_, i) => InkWell(
            onTap: () => Navigator.pop(context, avatars[i]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(avatars[i], width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(height: 6),
                Text(avatars[i].split('/').last.replaceAll('.png', ''),
                  style: GoogleFonts.mali(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (path == null) return;

    setState(() => _savingAvatar = true);
    await _fs.collection('users').doc(_docId).update({'avatar_url': path});
    setState(() {
      _avatarUrl = path;
      _savingAvatar = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ตั้งรูปโปรไฟล์แล้ว', style: GoogleFonts.mali())),
    );
  }

  ImageProvider? _avatarImage() {
    if (_avatarUrl.isEmpty) return null;
    if (_avatarUrl.startsWith('assets/')) return AssetImage(_avatarUrl);
    return null; 
  }

  Color _barColor(double p) {
    if (p >= 80) return Colors.lightGreen;
    if (p >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent,
        title: Text('โปรไฟล์นักเรียน', style: GoogleFonts.mali()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // ปุ่มแก้ka
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.pink.shade50,
                            backgroundImage: _avatarImage(),
                            child: _avatarUrl.isEmpty
                                ? Text(_firstName.isNotEmpty ? _firstName[0] : '?',
                                    style: GoogleFonts.mali(fontSize: 34, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          FloatingActionButton.small(
                            heroTag: 'editAvatar',
                            backgroundColor: Colors.white,
                            onPressed: _savingAvatar ? null : _pickAvatar,
                            child: _savingAvatar
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.edit, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('$_firstName $_lastName',
                          style: GoogleFonts.mali(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${_username ?? "-"}  ชั้น ป.${_classLv.isEmpty ? "-" : _classLv} เลขที่${_stunum.isEmpty ? "-" : _stunum}',
                          style: GoogleFonts.mali(color: Colors.black54)),
                      const SizedBox(height: 16),

                  
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Column(
                          children: [
                            _infoTile(Icons.badge_outlined, 'ชื่อ - นามสกุล', '$_firstName $_lastName'),
                            const Divider(height: 0),
                            _infoTile(Icons.school_outlined, 'ระดับชั้น', 'ป.${_classLv.isEmpty ? "-" : _classLv}'),
                            const Divider(height: 0),
                            _infoTile(Icons.verified_user_outlined, 'สิทธิ์ผู้ใช้', _role.isEmpty ? '-' : _role),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      _recentResultsCard(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: GoogleFonts.mali()),
      subtitle: Text(value, style: GoogleFonts.mali(fontSize: 16)),
    );
  }

  Widget _recentResultsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผลล่าสุด', style: GoogleFonts.mali(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _recent.isEmpty 
                ? Text('ยังไม่มีประวัติการทำแบบฝึก', style: GoogleFonts.mali())
                : _recentChart(),
          ],
        ),
      ),
    );
  }

  // กราฟแท่ง
  Widget _recentChart() {
    const barW = 56.0;
    const barMaxH = 96.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: barMaxH + 28,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recent.map((r) {
                final barH = ((r.percent / 100) * barMaxH).clamp(8.0, barMaxH);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: r.hint,
                        child: Container(
                          width: barW,
                          height: barH,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _barColor(r.percent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${r.percent.toStringAsFixed(0)}%',
                              style: GoogleFonts.mali(
                                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: barW,
                        child: Text(r.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.mali(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('เก่า', style: GoogleFonts.mali(fontSize: 12, color: Colors.black45)),
            Text('ใหม่', style: GoogleFonts.mali(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ],
    );
  }
}

// ข้อมูลกราฟ
class _Recent {
  final double percent;  
  final String label;   
  final String hint;     
  _Recent({required this.percent, required this.label, required this.hint});
}