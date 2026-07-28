import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:LumoRead/screen/admin_dashboard.dart';
import 'package:LumoRead/screen/teacher_dashboard.dart';
import 'package:LumoRead/screen/student_dashboard.dart';
import 'package:LumoRead/screen/register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();   // อีเมลหรือชื่อผู้ใช้
  final _pwd = TextEditingController();  // รหัสผ่าน

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _pwd.dispose();
    super.dispose();
  }


  String _sanitize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');

  String _normalizeLevel(String s) =>
      s.replaceAll(RegExp(r'[^0-9]'), ''); 

  Future<UserCredential?> _trySignIn(String email, String pw) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: pw);
    } on FirebaseAuthException {
      return null;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.mali())),
    );
  }
 

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final id = _id.text.trim();
    final pw = _pwd.text.trim();

    try {
      // ลองล็อกอิน
      UserCredential? cred;
      if (id.contains('@')) {
        // กรอกเป็นอีเมลจริง
        cred = await _trySignIn(id, pw);
      } else {
        // กรอกเป็น username 
        final u = _sanitize(id);
        cred = await _trySignIn('$u@teacher.local', pw)
            ?? await _trySignIn('$u@student.local', pw);
      }

      if (cred == null) {
        _toast('รหัสผ่านไม่ถูกต้อง หรือไม่มีผู้ใช้นี้');
        setState(() => _loading = false);
        return;
      }

      // ดึงโปรไฟล์ user
      final uid = cred.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        _toast('ไม่พบโปรไฟล์ผู้ใช้');
        await _auth.signOut();
        setState(() => _loading = false);
        return;
      }

      final data = doc.data()!;
      final role = (data['role'] ?? '').toString();
      final username = (data['username'] ?? '').toString();
      final classRaw = (data['class_level'] ?? '').toString();
      final classLevel = _normalizeLevel(classRaw); // <<< ส่งตรง

      final approved = (data['approved'] ?? true) as bool;
      if (role == 'teacher' && !approved) {
        _toast('บัญชีครูรอการอนุมัติจากผู้ดูแลระบบ');
        await _auth.signOut();
        setState(() => _loading = false);
        return;
      }

      // เก็บค่าไว้ใช้ต่อ
      final sp = await SharedPreferences.getInstance();
      await sp.setString('loggedInUsername', username);
      await sp.setString('username', username);
      await sp.setString('userRole', role);
      await sp.setString('uid', uid);
      await sp.setString('class_level', classLevel);

      // ไปหน้า dashboard 
      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboard()),
        );
      } else if (role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TeacherDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentDashboard(classLevel: classLevel)),
        );
      }
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mali = GoogleFonts.mali();

    return Scaffold(
      appBar: AppBar(
        title: Text('เข้าสู่ระบบ', style: mali),
        backgroundColor: Colors.pink.shade100,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('กรอกข้อมูลผู้ใช้เพื่อเข้าสู่ระบบ', style: mali),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _id,
                    decoration: InputDecoration(
                      labelText: 'อีเมลหรือชื่อผู้ใช้',
                      labelStyle: mali,
                    ),
                    style: mali,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรุณากรอกอีเมลหรือชื่อผู้ใช้' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pwd,
                    decoration: InputDecoration(labelText: 'รหัสผ่าน', labelStyle: mali),
                    style: mali,
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('เข้าสู่ระบบ', style: mali),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Register()),
                    ),
                    child: Text('ยังไม่มีบัญชี? ลงทะเบียนที่นี่!', style: mali),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}