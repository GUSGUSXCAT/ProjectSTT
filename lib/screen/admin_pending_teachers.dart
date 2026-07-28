import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPendingTeachersPage extends StatefulWidget {
  const AdminPendingTeachersPage({super.key});

  @override
  State<AdminPendingTeachersPage> createState() => _AdminPendingTeachersPageState();
}

class _AdminPendingTeachersPageState extends State<AdminPendingTeachersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();

  final TextEditingController _searchCtrl = TextEditingController();

  Future<void> _approveTeacher(String teacherId) async {
    try {
      final snap = await _firestore.collection('pending_teachers').doc(teacherId).get();
      if (!snap.exists) return;

      final raw = (snap.data() ?? {});

      final safe = <String, dynamic>{
        'id'         : teacherId,
        'role'       : _s(raw['role'], 'teacher'),
        'first_name' : _s(raw['first_name']),
        'last_name'  : _s(raw['last_name']),
        'username'   : _s(raw['username']),
        'class_level': _s(raw['class_level']),
        'avatar_url' : _s(raw['avatar_url']),
        'approved'   : true,
        'created_at' : raw['created_at'] ?? FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(teacherId).set(safe, SetOptions(merge: true));
      await _firestore.collection('pending_teachers').doc(teacherId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ อนุมัติครูสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _rejectTeacher(String teacherId) async {
    try {
      await _firestore.collection('pending_teachers').doc(teacherId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ ลบคำขอสมัครครูสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _confirmApprove(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('อนุมัติครู?'),
        content: Text('ยืนยันการอนุมัติ: $name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('อนุมัติ')),
        ],
      ),
    );
    if (ok == true) _approveTeacher(id);
  }

  Future<void> _confirmReject(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ปฏิเสธคำขอ?'),
        content: Text('ต้องการลบคำขอของ $name หรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) _rejectTeacher(id);
  }

  String _formatTime(dynamic ts) {
    try {
      final t = (ts as Timestamp).toDate();
      return '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF7F5F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        title: const Text('แดชบอร์ดแอดมิน • คำขอสมัครครู'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('pending_teachers')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final docs = snapshot.data?.docs ?? [];
          final q = _searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? docs
              : docs.where((d) {
                  final m = d.data();
                  final hay = [
                    _s(m['first_name']),
                    _s(m['last_name']),
                    _s(m['username']),
                    _s(m['class_level']),
                  ].join(' ').toLowerCase();
                  return hay.contains(q);
                }).toList();

          return Column(
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ค้นหา (ชื่อ/นามสกุล/ชื่อผู้ใช้)',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CounterChip(
                      label: 'คำขอรวม',
                      value: docs.length,
                    ),
                    const SizedBox(width: 8),
                    _CounterChip(
                      label: 'ผลคัดกรอง',
                      value: filtered.length,
                      color: Colors.indigo,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),


              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (filtered.isEmpty)
                        ? const _EmptyState()
                        : LayoutBuilder(builder: (context, c) {
                            final w = c.maxWidth;
                            final cols = w > 1100 ? 3 : (w > 720 ? 2 : 1);
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.9,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final doc = filtered[i];
                                final m = doc.data();
                                final first = _s(m['first_name']);
                                final last = _s(m['last_name']);
                                final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
                                final username = _s(m['username'], '—');
                                final classLevel = _s(m['class_level'], '—');
                                final created = _formatTime(m['created_at']);

                                final initials = (first.isNotEmpty || last.isNotEmpty)
                                    ? (first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : '')
                                    : '?';

                                return Card(
                                  elevation: 0.8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name.isEmpty ? '(ไม่มีชื่อ)' : name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text('@$username', style: const TextStyle(color: Colors.black54)),
                                                ],
                                              ),
                                            ),
                                    
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'อนุมัติ',
                                                  onPressed: () => _confirmApprove(doc.id, name.isEmpty ? username : name),
                                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                                ),
                                                IconButton(
                                                  tooltip: 'ปฏิเสธ',
                                                  onPressed: () => _confirmReject(doc.id, name.isEmpty ? username : name),
                                                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _InfoChip(icon: Icons.school, label: 'ชั้นเรียน', value: classLevel),
                                            _InfoChip(icon: Icons.calendar_today, label: 'สมัครเมื่อ', value: created),
                                            _InfoChip(icon: Icons.badge, label: 'บทบาท', value: _s(m['role'], 'teacher')),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _CounterChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _CounterChip({required this.label, required this.value, this.color = Colors.deepPurple});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                color: color.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade200)),
    );
  }
}

extension on Color {
  get shade700 => null;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E7F1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('ไม่มีครูที่รออนุมัติ', style: TextStyle(color: Colors.black54)),
    );
  }
}
