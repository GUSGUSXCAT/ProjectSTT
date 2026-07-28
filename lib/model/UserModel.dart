import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String role;
  final String? email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? studentNumber;
  final String? classLevel;
  final bool approved;
  final Timestamp? createdAt;

  UserModel({
    required this.id,
    required this.role,
    this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.studentNumber,
    this.classLevel,
    this.approved = false, //  ตั้งค่าเริ่มต้นเป็น false
    this.createdAt,
  });

  //  ดึงข้อมูลจาก Firestore และป้องกันค่าที่อาจเป็น null
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      id: doc.id,
      role: data['role'] ?? "student",
      email: data['email'] as String?,
      username: data['username'] as String?,
      firstName: data['first_name'] as String?,
      lastName: data['last_name'] as String?,
      studentNumber: data['student_number'] as String?,
      classLevel: data['class_level'] as String?,
      approved: data['approved'] as bool? ?? false, // ✅ ป้องกัน null
    );
  }

  //  แปลงเป็น JSON สำหรับบันทึก Firestore
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'student_number': studentNumber,
      'class_level': classLevel,
      'approved': approved,
    };
  }
}