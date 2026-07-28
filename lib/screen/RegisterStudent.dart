import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterStudent extends StatefulWidget {
  const RegisterStudent({super.key});

  @override
  _RegisterStudentState createState() => _RegisterStudentState();
}

class _RegisterStudentState extends State<RegisterStudent> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  String? selectedClass;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentNumberController.dispose();
    super.dispose();
  }


  String _emailFromUsername(String username) {
    final sanitized = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$sanitized@student.local';
  }


  String? _validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
    if (v.length < 3) return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
      return 'ใช้ได้เฉพาะตัวอักษร/ตัวเลข/._-';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    return null;
  }

  String? _validateNotEmpty(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอก$label';
    return null;
  }

  // ===== สมัครนักเรียน (Auth + Firestore) =====
  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final studentNo = _studentNumberController.text.trim();
      final classLevel = selectedClass;

      // เช็ก username ซ้ำใน users
      final existingUsers = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('😣 Username ถูกใช้แล้ว กรุณาเลือกชื่ออื่น', style: GoogleFonts.mali())),
        );
        return;
      }

      // (ออปชัน) กันเลขที่ซ้ำในชั้นเดียวกัน
      final dupNo = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('class_level', isEqualTo: classLevel)
          .where('student_number', isEqualTo: studentNo)
          .limit(1)
          .get();
      if (dupNo.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เลขที่นี้ถูกใช้ในชั้นเรียนนี้แล้ว', style: GoogleFonts.mali())),
        );
        return;
      }

      // สมัครด้วยอีเมลเงา (ผู้ใช้ไม่ต้องมีอีเมลจริง)
      final shadowEmail = _emailFromUsername(username);
      final cred = await _auth.createUserWithEmailAndPassword(
        email: shadowEmail,
        password: password,
      );
      final uid = cred.user!.uid;

      // บันทึกโปรไฟล์นักเรียน (ไม่เก็บรหัสผ่าน/แฮชใน Firestore)
      await _firestore.collection('users').doc(uid).set({
        'id': uid,
        'role': 'student',
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'student_number': studentNo,
        'class_level': classLevel,
        'created_at': FieldValue.serverTimestamp(),
        'email_shadow': shadowEmail,
      });

      // แจ้งผล + กลับหน้า Login (ตัด session ออกก่อน กันเด้งเข้า dashboard)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🥳 ลงทะเบียนนักเรียนสำเร็จแล้ว', style: GoogleFonts.mali())),
      );
      await _auth.signOut();
      if (mounted) Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String msg = 'เกิดข้อผิดพลาด';
      if (e.code == 'email-already-in-use') {
        msg = 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
      } else if (e.code == 'invalid-email') {
        msg = 'รูปแบบชื่อผู้ใช้ไม่ถูกต้อง';
      } else if (e.code == 'weak-password') {
        msg = 'รหัสผ่านอ่อนเกินไป';
      } else {
        msg = e.message ?? e.code;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $msg', style: GoogleFonts.mali())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e', style: GoogleFonts.mali())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: Text("ลงทะเบียนนักเรียน", style: GoogleFonts.mali())),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "กรุณากรอกข้อมูลเพื่อลงทะเบียน",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.mali(
                        fontSize: isWideScreen ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    // ชื่อผู้ใช้
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: "ชื่อผู้ใช้",
                        labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                      validator: _validateUsername,
                    ),

                    // รหัสผ่าน
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "รหัสผ่าน",
                        labelStyle: GoogleFonts.mali(),
                      ),
                      obscureText: true,
                      style: GoogleFonts.mali(),
                      validator: _validatePassword,
                    ),

                    // ชื่อ
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: "ชื่อ",
                        labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                      validator: (v) => _validateNotEmpty(v, 'ชื่อ'),
                    ),

                    // นามสกุล
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: "นามสกุล",
                        labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                      validator: (v) => _validateNotEmpty(v, 'นามสกุล'),
                    ),

                    // เลขที่นักเรียน
                    TextFormField(
                      controller: _studentNumberController,
                      decoration: InputDecoration(
                        labelText: "เลขที่",
                        labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                      keyboardType: TextInputType.number,
                      validator: (v) => _validateNotEmpty(v, 'เลขที่'),
                    ),

                    // ชั้นเรียน
                    DropdownButtonFormField<String>(
                      value: selectedClass,
                      hint: Text("เลือกชั้นเรียน", style: GoogleFonts.mali()),
                      items: ["1", "2", "3"].map((classLevel) {
                        return DropdownMenuItem(
                          value: classLevel,
                          child: Text(classLevel, style: GoogleFonts.mali()),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedClass = value),
                      validator: (value) => value == null ? 'กรุณาเลือกชั้นเรียน' : null,
                    ),

                    SizedBox(height: 20),

                    // ปุ่มลงทะเบียน
                    ElevatedButton(
                      onPressed: _registerStudent,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isWideScreen ? 16 : 12),
                        textStyle: GoogleFonts.mali(fontSize: isWideScreen ? 20 : 16),
                      ),
                      child: Text("ลงทะเบียนนักเรียน", style: GoogleFonts.mali()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
