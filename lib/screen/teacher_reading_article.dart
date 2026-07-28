import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';


final db = FirebaseFirestore.instance
    .collection('questions')
    .doc('g_3')
    .collection('ReadingArticle');




List<String> cutline(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

List<String> cutword(String line) {
  return line.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

int? gettime(String s) {
  s = s.trim();
  if (s.isEmpty) return null;
  
  if (s.contains(':')) {
    var p = s.split(':');
    var m = int.tryParse(p[0]) ?? 0;
    var sec = int.tryParse(p[1]) ?? 0;
    return m * 60 + sec;
  }
  
  return int.tryParse(s);
}

String showtime(int? sec) {
  if (sec == null) return '-';
  var m = sec ~/ 60;
  var s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

Future<void> save({
  String? id,
  required String name,
  required String txt,
  int? time,
}) async {
  var lines = cutline(txt);
  
  var words = <String, List<String>>{};
  for (var i = 0; i < lines.length; i++) {
    words['$i'] = cutword(lines[i]);
  }

  var data = {
    'title': name,
    'text': txt,
    'lines': lines,
    'tokens': words,
    'time_limit_sec': time,
    'updated_at': FieldValue.serverTimestamp(),
  };

  if (id == null) {
    data['created_at'] = FieldValue.serverTimestamp();
    data['is_deleted'] = false;
    id = name.toLowerCase().replaceAll(' ', '-');
  }

  await db.doc(id).set(data, SetOptions(merge: true));
}

Future<void> del(String id) async {
  await db.doc(id).update({
    'is_deleted': true,
    'deleted_at': FieldValue.serverTimestamp(),
  });
}

class TeacherArticleListPage extends StatelessWidget {
  const TeacherArticleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade100,
        title: Text('แบบฝึกอ่าน ป.3', style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (c) => EditPage()));
        },
        child: Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.orderBy('created_at', descending: true).snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator());

          var docs = snap.data!.docs.where((d) {
            var data = d.data() as Map;
            return data['is_deleted'] != true;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text('ยังไม่มีแบบฝึกอ่าน\nกดปุ่ม + ด้านล่าง', 
                style: GoogleFonts.mali(fontSize: 16), textAlign: TextAlign.center),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (c, i) => Divider(),
            itemBuilder: (c, i) {
              var doc = docs[i];
              var d = doc.data() as Map;
              var t = d['time_limit_sec'] as int?;
              
              return ListTile(
                title: Text(d['title'] ?? 'ไม่มีชื่อ', 
                  style: GoogleFonts.mali(fontWeight: FontWeight.w600)),
                subtitle: Text('${(d['lines'] as List?)?.length ?? 0} บรรทัด${t != null ? ' • ${showtime(t)}' : ''}',
                  style: GoogleFonts.mali(fontSize: 12)),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(c, MaterialPageRoute(
                    builder: (c) => EditPage(id: doc.id)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class EditPage extends StatefulWidget {
  final String? id;
  const EditPage({super.key, this.id});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  var nameCtrl = TextEditingController();
  var txtCtrl = TextEditingController();
  var timeCtrl = TextEditingController();

  bool loading = false;
  bool preview = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    txtCtrl.dispose();
    timeCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (widget.id == null) return;

    setState(() => loading = true);

    var doc = await db.doc(widget.id!).get();
    if (doc.exists) {
      var d = doc.data()!;
      nameCtrl.text = d['title'] ?? '';
      txtCtrl.text = d['text'] ?? '';
      
      var t = d['time_limit_sec'] as int?;
      if (t != null) timeCtrl.text = showtime(t);
    }

    setState(() => loading = false);
  }

  Future<void> savedata() async {
    var name = nameCtrl.text.trim();
    var txt = txtCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณากรอกชื่อเรื่อง', style: GoogleFonts.mali())));
      return;
    }

    if (txt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณากรอกข้อความ', style: GoogleFonts.mali())));
      return;
    }

    setState(() => loading = true);

    try {
      await save(id: widget.id, name: name, txt: txt, time: gettime(timeCtrl.text));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกสำเร็จ', style: GoogleFonts.mali())));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e', style: GoogleFonts.mali()),
          backgroundColor: Colors.red));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> deldata() async {
    if (widget.id == null) return;

    var ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('ลบแบบฝึกอ่าน?', style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
        content: Text('ต้องการลบหรือไม่', style: GoogleFonts.mali()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
            child: Text('ยกเลิก', style: GoogleFonts.mali())),
          FilledButton(onPressed: () => Navigator.pop(c, true),
            child: Text('ลบ', style: GoogleFonts.mali())),
        ],
      ),
    );

    if (ok == true) {
      await del(widget.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    var lines = txtCtrl.text.isEmpty ? [] : cutline(txtCtrl.text);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple.shade50,
        title: Text(widget.id == null ? 'เพิ่มแบบฝึกอ่าน' : 'แก้ไขแบบฝึกอ่าน',
          style: GoogleFonts.mali(fontWeight: FontWeight.w700)),
        actions: [
          if (widget.id != null)
            IconButton(icon: Icon(Icons.delete), onPressed: deldata),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('ชื่อเรื่อง', style: GoogleFonts.mali(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            style: GoogleFonts.mali(),
            decoration: InputDecoration(hintText: 'ระบุชื่อเรื่อง', border: OutlineInputBorder()),
          ),
          SizedBox(height: 16),

          Text('เวลาเป้าหมาย (ไม่บังคับ)', style: GoogleFonts.mali(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('เช่น 01:30 หรือ 90', style: GoogleFonts.mali(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 8),
          TextField(
            controller: timeCtrl,
            style: GoogleFonts.mali(),
            decoration: InputDecoration(hintText: 'เช่น 01:30', border: OutlineInputBorder()),
          ),
          SizedBox(height: 16),

          Text('ข้อความแบบฝึกหัด', style: GoogleFonts.mali(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('กด Enter ขึ้นบรรทัดใหม่ เว้นวรรคเพื่อแบ่งคำ', 
            style: GoogleFonts.mali(fontSize: 12, color: Colors.blue)),
          SizedBox(height: 8),
          TextField(
            controller: txtCtrl,
            style: GoogleFonts.mali(fontSize: 16),
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'พิมพ์ข้อความที่ต้องการให้นักเรียนอ่าน',
              border: OutlineInputBorder()),
            onChanged: (v) => setState(() {}),
          ),
          SizedBox(height: 16),

          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: loading ? null : () => setState(() => preview = !preview),
                icon: Icon(preview ? Icons.visibility_off : Icons.visibility),
                label: Text(preview ? 'ซ่อน' : 'ดูตัวอย่าง', style: GoogleFonts.mali())),
              OutlinedButton.icon(
                onPressed: loading ? null : savedata,
                icon: Icon(Icons.save),
                label: Text('บันทึก', style: GoogleFonts.mali())),
            ],
          ),
          SizedBox(height: 16),

          if (preview && lines.isNotEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ตัวอย่าง', style: GoogleFonts.mali(fontWeight: FontWeight.w700, fontSize: 18)),
                    Divider(),
                    Text('จำนวนบรรทัด: ${lines.length}', style: GoogleFonts.mali(fontWeight: FontWeight.w600)),
                    SizedBox(height: 16),

                    for (var i = 0; i < lines.length; i++) ...[
                      Text('บรรทัด ${i + 1}', style: GoogleFonts.mali(fontWeight: FontWeight.w600, color: Colors.blue)),
                      SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(lines[i], style: GoogleFonts.mali()),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: cutword(lines[i]).asMap().entries.map((e) {
                          return Chip(
                            label: Text('${e.key + 1}. ${e.value}', style: GoogleFonts.mali(fontSize: 12)),
                            backgroundColor: Colors.green.shade50);
                        }).toList(),
                      ),
                      if (i < lines.length - 1) Divider(height: 24),
                    ],
                  ],
                ),
              ),
            ),

          if (loading)
            Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}