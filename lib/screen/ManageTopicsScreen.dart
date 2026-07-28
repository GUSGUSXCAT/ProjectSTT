
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 📚 จัดการหัวข้อแบบฝึกหัด
/// 
/// **สิทธิ์: ครูเท่านั้น**
/// 
/// ✅ ครูสามารถ:
/// - เพิ่มหัวข้อใหม่
/// - แก้ไขหัวข้อ
/// - ลบหัวข้อ
/// - เปิด/ปิดใช้งานหัวข้อ
/// - เรียงลำดับหัวข้อ
class ManageTopicsScreen extends StatefulWidget {
  const ManageTopicsScreen({super.key});

  @override
  State<ManageTopicsScreen> createState() => _ManageTopicsScreenState();
}

class _ManageTopicsScreenState extends State<ManageTopicsScreen> {
  String selectedGrade = 'ป.2';
  final List<String> grades = ['ป.1', 'ป.2', 'ป.3'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F8),
      appBar: AppBar(
        title: const Text('จัดการหัวข้อแบบฝึกหัด'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTopicDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มหัวข้อใหม่'),
      ),
      body: Column(
        children: [
          // เลือกชั้น
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  'เลือกระดับชั้น:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                ...grades.map((grade) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(grade),
                    selected: selectedGrade == grade,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedGrade = grade);
                      }
                    },
                  ),
                )),
              ],
            ),
          ),

          // รายการหัวข้อ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('exercise_topics')
                  .where('grade', isEqualTo: selectedGrade)
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'ยังไม่มีหัวข้อสำหรับ $selectedGrade',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showTopicDialog(null),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มหัวข้อแรก'),
                        ),
                      ],
                    ),
                  );
                }

                final topics = snapshot.data!.docs;

                return ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: topics.length,
                  onReorder: (oldIndex, newIndex) {
                    _reorderTopics(topics, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final doc = topics[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final id = doc.id;
                    final nameTh = data['name_th'] ?? '';
                    final icon = data['icon'] ?? '📚';
                    final color = _parseColor(data['color']);
                    final isActive = data['is_active'] ?? true;
                    final order = data['order'] ?? 0;

                    return Card(
                      key: ValueKey(doc.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        title: Text(
                          nameTh,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text('ID: $id'),
                            const SizedBox(width: 12),
                            Text('ลำดับ: $order'),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? Colors.green[100] 
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive 
                                      ? Colors.green[700] 
                                      : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showTopicDialog(doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              onPressed: () => _confirmDelete(doc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog เพิ่ม/แก้ไขหัวข้อ
  void _showTopicDialog(DocumentSnapshot? doc) {
    final isEditing = doc != null;
    final data = doc?.data() as Map<String, dynamic>?;

    final idController = TextEditingController(text: isEditing ? doc.id : '');
    final nameThController = TextEditingController(text: data?['name_th'] ?? '');
    final nameEnController = TextEditingController(text: data?['name_en'] ?? '');
    final iconController = TextEditingController(text: data?['icon'] ?? '📚');
    final colorController = TextEditingController(text: data?['color'] ?? '#90CAF9');
    final orderController = TextEditingController(
      text: (data?['order'] ?? 0).toString(),
    );
    bool isActive = data?['is_active'] ?? true;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'แก้ไขหัวข้อ' : 'เพิ่มหัวข้อใหม่'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ID
                  TextFormField(
                    controller: idController,
                    enabled: !isEditing, // ไม่ให้แก้ ID
                    decoration: const InputDecoration(
                      labelText: 'Topic ID *',
                      hintText: 'mae_kob, mae_kod, leading_consonant',
                      helperText: 'ใช้ใน code (ตัวพิมพ์เล็ก, _ เท่านั้น)',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอก Topic ID';
                      }
                      if (!RegExp(r'^[a-z_]+$').hasMatch(value)) {
                        return 'ใช้ได้เฉพาะ a-z และ _ เท่านั้น';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ชื่อไทย
                  TextFormField(
                    controller: nameThController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อภาษาไทย *',
                      hintText: 'มาตราตัวสะกด แม่กบ',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกชื่อภาษาไทย';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ชื่ออังกฤษ (optional)
                  TextFormField(
                    controller: nameEnController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อภาษาอังกฤษ (ถ้ามี)',
                      hintText: 'Mae Kob',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Icon/Emoji
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Icon/Emoji',
                      hintText: '🐸',
                      helperText: 'คัดลอก Emoji จากเว็บ emojipedia.org',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Color (hex)
                  TextFormField(
                    controller: colorController,
                    decoration: InputDecoration(
                      labelText: 'สี (Hex Code)',
                      hintText: '#90CAF9',
                      helperText: 'รหัสสี 6 หลัก เช่น #90CAF9',
                      suffixIcon: Container(
                        width: 40,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _parseColor(colorController.text),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // ลำดับ
                  TextFormField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ลำดับการแสดงผล',
                      hintText: '1',
                      helperText: 'เรียงจากน้อยไปมาก',
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (int.tryParse(value) == null) {
                          return 'ต้องเป็นตัวเลขเท่านั้น';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // สถานะ
                  SwitchListTile(
                    title: const Text('เปิดใช้งาน'),
                    subtitle: Text(
                      isActive 
                          ? 'หัวข้อนี้จะแสดงใน App' 
                          : 'หัวข้อนี้จะไม่แสดงใน App',
                    ),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final payload = {
                  'id': idController.text.trim(),
                  'name_th': nameThController.text.trim(),
                  'name_en': nameEnController.text.trim(),
                  'grade': selectedGrade,
                  'icon': iconController.text.trim(),
                  'color': colorController.text.trim(),
                  'order': int.tryParse(orderController.text.trim()) ?? 0,
                  'is_active': isActive,
                };

                if (isEditing) {
                  payload['updated_at'] = FieldValue.serverTimestamp();
                  await doc.reference.update(payload);
                } else {
                  payload['created_at'] = FieldValue.serverTimestamp();
                  payload['updated_at'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('exercise_topics')
                      .doc(idController.text.trim())
                      .set(payload);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? 'แก้ไขสำเร็จ' : 'เพิ่มหัวข้อใหม่สำเร็จ'),
                  ),
                );
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  /// ยืนยันการลบ
  void _confirmDelete(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameTh = data['name_th'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบหัวข้อ?'),
        content: Text('ต้องการลบหัวข้อ "$nameTh" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('ลบหัวข้อสำเร็จ')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  /// เรียงลำดับหัวข้อ
  void _reorderTopics(List<QueryDocumentSnapshot> topics, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < topics.length; i++) {
      int newOrder;
      if (i == oldIndex) {
        newOrder = newIndex;
      } else if (i < oldIndex && i >= newIndex) {
        newOrder = i + 1;
      } else if (i > oldIndex && i <= newIndex) {
        newOrder = i - 1;
      } else {
        newOrder = i;
      }

      batch.update(topics[i].reference, {'order': newOrder});
    }

    await batch.commit();
  }

  /// แปลง hex color เป็น Color
  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}




























