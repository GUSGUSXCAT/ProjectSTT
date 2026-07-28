import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screen/login.dart';
import 'screen/admin_dashboard.dart';
import 'screen/teacher_dashboard.dart';
import 'screen/student_dashboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  ///await initAllExerciseTopics();
   
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ เพิ่ม theme ตรงนี้
      theme: ThemeData(
        fontFamily: 'Mali',
        primarySwatch: Colors.pink,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),

      home: const RootGate(),

      routes: {
        '/login': (context) => LoginScreen(),
      },
    );
  }
}

// ... ส่วน RootGate เหมือนเดิม
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnap.data;
        if (user == null) return LoginScreen();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!docSnap.hasData || !docSnap.data!.exists) {
              return LoginScreen();
            }

            final data = docSnap.data!.data() as Map<String, dynamic>;
            final role = (data['role'] ?? '').toString().trim().toLowerCase();
            final classLevel = (data['class_level'] ?? '').toString();

            switch (role) {
              case 'admin':
                return AdminDashboard();
              case 'teacher':
                return TeacherDashboard();
              case 'student':
                return StudentDashboard(classLevel: classLevel);
              default:
                return LoginScreen();
            }
          },
        );
      },
    );
  }
}