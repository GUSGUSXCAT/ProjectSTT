import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';
import 'Login.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มีผู้ใช้ล็อกอิน → ไปหน้า Login
    if (FirebaseAuth.instance.currentUser == null) {
      return LoginScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "❌ ไม่พบข้อมูลผู้ใช้",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
                  },
                  child: Text("กลับไปหน้าเข้าสู่ระบบ"),
                ),
              ],
            ),
          );
        }

        String role = snapshot.data!['role'];
        return role == "teacher" ? TeacherDashboard() : StudentDashboard(classLevel: '',);
      },
    );
  }
}
