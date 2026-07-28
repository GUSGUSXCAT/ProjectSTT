import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterTeacher extends StatefulWidget {
  const RegisterTeacher({super.key});

  @override
  _RegisterTeacherState createState() => _RegisterTeacherState();
}

class _RegisterTeacherState extends State<RegisterTeacher> {
  final _formKey = GlobalKey<FormState>();
  

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // แปลงอีเมลสมมติ เพื่อใช้กับ FA
  String _emailFromUsername(String username) {
    final sanitized = username
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), ''); 
    return '$sanitized@teacher.local';
  }

  String? _validateUsername(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
    if (value.length < 3) return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(value)) {
      return 'ใช้ได้เฉพาะตัวอักษร/ตัวเลข/._-';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '');
    if (value.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    return null;
  }

  Future<void> _registerTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _submitting = true);

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // ตรวจชื่อซ้ำใน users และ pending_teachers
      final existingUsers = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      final existingPending = await _firestore
          .collection('pending_teachers')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty || existingPending.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('😣 Username นี้ถูกใช้แล้ว', style: GoogleFonts.mali())),
        );
        return;
      }

      // สร้างบัญชีด้วยอีเมลสมมติจาก username
      final shadowEmail = _emailFromUsername(username);
      final cred = await _auth.createUserWithEmailAndPassword(
        email: shadowEmail,
        password: password,
      );

      final uid = cred.user!.uid;

      // บันทึกลง pending_teachers รอแอดมินอนุมัติ
      await _firestore.collection('pending_teachers').doc(uid).set({
        'id': uid,
        'role': 'teacher',
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email_shadow': shadowEmail, 
        'approved': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ลงทะเบียนสำเร็จ! กรุณารอการอนุมัติจากแอดมิน', style: GoogleFonts.mali())),
      );

      if (mounted) Navigator.pop(context); // กลับหน้า Login
    } on FirebaseAuthException catch (e) {
      // แปลง error ให้เข้าใจง่ายในบริบท username
      String msg = 'เกิดข้อผิดพลาด';
      if (e.code == 'email-already-in-use') {
        msg = 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
      } else if (e.code == 'invalid-email') {
        msg = 'รูปแบบชื่อผู้ใช้ไม่ถูกต้อง (โปรดใช้ a-z 0-9 . _ -)';
      
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mali = GoogleFonts.mali();
    final isWideScreen = MediaQuery.of(context).size.width > 600;

   return Scaffold(
      appBar: AppBar(
        title: Text("ลงทะเบียนคุณครู", style: mali),
        backgroundColor: Colors.pink.shade100,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "กรุณากรอกข้อมูลเพื่อลงทะเบียน",
                      textAlign: TextAlign.center,
                      style: mali.copyWith(
                        fontSize: isWideScreen ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: "ชื่อ"
                ,labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
              ),
              // Last name
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: "นามสกุล" 
                ,labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกนามสกุล' : null,
              ),
              // Username 
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: "ชื่อผู้ใช้ (สำหรับเข้าสู่ระบบ)",labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                validator: _validateUsername,
              ),
              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "รหัสผ่าน",labelStyle: GoogleFonts.mali(),
                      ),
                      style: GoogleFonts.mali(),
                obscureText: true,
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _registerTeacher,
                  style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: isWideScreen ? 16 : 12),
                          textStyle: mali.copyWith(
                              fontSize: isWideScreen ? 20 : 16),
                        ),
                  child: Text(_submitting ? "กำลังบันทึก..." : "ลงทะเบียนครู", style: mali),
                ),
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
