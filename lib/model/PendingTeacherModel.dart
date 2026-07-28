import 'package:cloud_firestore/cloud_firestore.dart';

class PendingTeacher {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final bool approved;
  final Timestamp createdAt;

  // ✅ Constructor
  PendingTeacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.approved = false, // ค่าเริ่มต้น = รออนุมัติ
    required this.createdAt,
  });

  // ✅ แปลงข้อมูลจาก Firestore เป็น Object
  factory PendingTeacher.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PendingTeacher(
      id: doc.id,
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      email: data['email'] ?? '',
      approved: data['approved'] ?? false,
      createdAt: data['created_at'] ?? Timestamp.now(),
    );
  }

  // ✅ แปลง Object เป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id, // ✅ เพิ่ม id ลงไปใน Firestore
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'approved': approved,
      'created_at': createdAt,
    };
  }
}

// ✅ เชื่อม Firestore
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// ✅ ดึงข้อมูลครูที่รออนุมัติ
Future<List<PendingTeacher>> getPendingTeachers() async {
  QuerySnapshot querySnapshot = await _firestore.collection('pending_teachers').get();
  return querySnapshot.docs.map((doc) => PendingTeacher.fromFirestore(doc)).toList();
}

// ✅ เพิ่มครูไปที่ pending_teachers
Future<void> addPendingTeacher(PendingTeacher teacher) async {
  await _firestore.collection('pending_teachers').doc(teacher.id).set({
    ...teacher.toMap(),
    'created_at': FieldValue.serverTimestamp(), // ✅ ใช้เวลาของเซิร์ฟเวอร์
  });
}

// ✅ อนุมัติครู
Future<void> approveTeacher(String teacherId) async {
  DocumentSnapshot teacherDoc = await _firestore.collection('pending_teachers').doc(teacherId).get();

  if (teacherDoc.exists) {
    PendingTeacher teacher = PendingTeacher.fromFirestore(teacherDoc);

    // ✅ ย้ายข้อมูลไปที่ `users`
    await _firestore.collection('users').doc(teacher.id).set({
      'id': teacher.id,
      'first_name': teacher.firstName,
      'last_name': teacher.lastName,
      'email': teacher.email,
      'role': 'teacher', // ✅ ตั้งค่า role เป็น teacher
      'created_at': FieldValue.serverTimestamp(),
    });

    // ✅ ลบออกจาก `pending_teachers`
    await _firestore.collection('pending_teachers').doc(teacherId).delete();
  }
}
