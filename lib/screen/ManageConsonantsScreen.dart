import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageConsonantsScreen extends StatelessWidget {
  final String gradeLevel;

  ManageConsonantsScreen({super.key, required this.gradeLevel});

  final CollectionReference consonantRef = FirebaseFirestore.instance
      .collection('questions')
      .doc('g_1')
      .collection('consonants');

  void _showAddDialog(BuildContext context) {
    final letterController = TextEditingController();
    final wordController = TextEditingController();
    final exampleController = TextEditingController();
    final ttsTextController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('➕ เพิ่มพยัญชนะ'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: letterController, decoration: InputDecoration(labelText: 'letter')),
              TextField(controller: wordController, decoration: InputDecoration(labelText: 'word')),
              TextField(controller: exampleController, decoration: InputDecoration(labelText: 'example')),
              TextField(controller: ttsTextController, decoration: InputDecoration(labelText: 'tts_text')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              consonantRef.add({
                'letter': letterController.text,
                'word': wordController.text,
                'example': exampleController.text,
                'tts_text': ttsTextController.text,
              });
              Navigator.pop(context);
            },
            child: Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final letterController = TextEditingController(text: doc['letter']);
    final wordController = TextEditingController(text: doc['word']);
    final exampleController = TextEditingController(text: doc['example']);
    final ttsTextController = TextEditingController(text: doc['tts_text']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('✏️ แก้ไขพยัญชนะ'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: letterController, decoration: InputDecoration(labelText: 'letter')),
              TextField(controller: wordController, decoration: InputDecoration(labelText: 'word')),
              TextField(controller: exampleController, decoration: InputDecoration(labelText: 'example')),
              TextField(controller: ttsTextController, decoration: InputDecoration(labelText: 'tts_text')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              consonantRef.doc(doc.id).update({
                'letter': letterController.text,
                'word': wordController.text,
                'example': exampleController.text,
                'tts_text': ttsTextController.text,
              });
              Navigator.pop(context);
            },
            child: Text('บันทึก'),
          ),
          TextButton(
            onPressed: () => consonantRef.doc(doc.id).delete(),
            child: Text('🗑 ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📚 จัดการพยัญชนะ ป.1', style: GoogleFonts.mali()),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: consonantRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return ListTile(
                leading: CircleAvatar(child: Text(doc['letter'])),
                title: Text("คำ: ${doc['word']}"),
                subtitle: Text("ตัวอย่าง: ${doc['example']}"),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
