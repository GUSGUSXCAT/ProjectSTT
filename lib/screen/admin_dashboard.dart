import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:LumoRead/screen/admin_pending_teachers.dart';
import 'login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }


  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green[400] : Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deleteTeacher(String teacherId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 28),
            SizedBox(width: 12),
            Text('ยืนยันการลบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text('คุณต้องการลบ "$teacherName" ออกจากระบบใช่หรือไม่?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('ลบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(teacherId).delete();
        _showSnackBar('ลบครูเรียบร้อยแล้ว', true);
      } catch (e) {
        _showSnackBar('เกิดข้อผิดพลาด: $e', false);
      }
    }
  }

  void _editTeacher(String teacherId, Map<String, dynamic> teacherData) {
    final firstNameController = TextEditingController(text: teacherData['first_name'] ?? '');
    final lastNameController = TextEditingController(text: teacherData['last_name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue[400]!, Colors.purple[400]!]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text('แก้ไขข้อมูลครู', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อ',
                prefixIcon: Icon(Icons.person, color: Colors.blue[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              decoration: InputDecoration(
                labelText: 'นามสกุล',
                prefixIcon: Icon(Icons.person_outline, color: Colors.blue[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: teacherData['email'] ?? ''),
              decoration: InputDecoration(
                labelText: 'อีเมล',
                prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(teacherId).update({
                  'first_name': firstNameController.text.trim(),
                  'last_name': lastNameController.text.trim(),
                });
                Navigator.pop(context);
                _showSnackBar('บันทึกข้อมูลเรียบร้อยแล้ว', true);
              } catch (e) {
                _showSnackBar('เกิดข้อผิดพลาด: $e', false);
              }
            },
            child: Text('บันทึก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "แดชบอร์ดแอดมิน",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red[400], size: 20),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.purple[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "เมนูแอดมิน",
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "จัดการระบบและอนุมัติครู",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdminPendingTeachersPage()),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pinkAccent, Colors.purpleAccent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pending_actions, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "รายการรอการอนุมัติครู",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.grey[700], size: 20),
                SizedBox(width: 8),
                Text(
                  "รายชื่อครูที่อนุมัติแล้ว",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                  }

                  var teachers = snapshot.data!.docs;
                  if (teachers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                          SizedBox(height: 16),
                          Text(
                            "ไม่มีครูในระบบ",
                            style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: 16),
                    itemCount: teachers.length,
                    itemBuilder: (context, index) {
                      var teacher = teachers[index];
                      var data = teacher.data() as Map<String, dynamic>;
                      String id = teacher.id;
                      String fullName = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}";

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[300]!, Colors.purple[300]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "${data['first_name']?[0] ?? '?'}${data['last_name']?[0] ?? ''}",
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          title: Text(
                            fullName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                          subtitle: Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "อีเมล: ${data['email'] ?? 'ไม่ระบุ'}",
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _editTeacher(id, data),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.edit, color: Colors.blue[400], size: 20),
                                ),
                              ),
                              SizedBox(width: 8),
                              InkWell(
                                onTap: () => _deleteTeacher(id, fullName),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.delete, color: Colors.red[400], size: 20),
                                ),
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
          ),
        ],
      ),
    );
  }
}