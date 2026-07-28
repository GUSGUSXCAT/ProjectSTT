import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminApproveTeachers extends StatefulWidget {
  const AdminApproveTeachers({super.key});

  @override
  _AdminApproveTeachersState createState() => _AdminApproveTeachersState();
}

class _AdminApproveTeachersState extends State<AdminApproveTeachers> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _approveTeacher(String teacherId) async {
    try {
      DocumentSnapshot teacherDoc =
          await _firestore.collection('pending_teachers').doc(teacherId).get();
      if (!teacherDoc.exists) return;

      Map<String, dynamic> teacherData =
          teacherDoc.data() as Map<String, dynamic>;
      teacherData['approved'] = true;

      await _firestore.collection('users').doc(teacherId).set(teacherData);
      await _firestore.collection('pending_teachers').doc(teacherId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ อนุมัติครูสำเร็จ!')),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  void _rejectTeacher(String teacherId) async {
    try {
      await _firestore.collection('pending_teachers').doc(teacherId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ลบคำขอสมัครครูสำเร็จ!')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("อนุมัติครู")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('pending_teachers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("ไม่มีครูที่รออนุมัติ"));
          }

          var teachers = snapshot.data!.docs;
          return ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              var teacher = teachers[index];
              var data = teacher.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text("${data['first_name']} ${data['last_name']}"),
                  subtitle: Text(data['email']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveTeacher(teacher.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectTeacher(teacher.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
