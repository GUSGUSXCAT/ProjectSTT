import 'package:cloud_firestore/cloud_firestore.dart';

/// Model สำหรับหัวข้อแบบฝึกหัด
class ExerciseTopic {
  final String id;
  final String nameTh;
  final String nameEn;
  final String grade;
  final String icon;
  final String color;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExerciseTopic({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.grade,
    required this.icon,
    required this.color,
    required this.order,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// สร้าง ExerciseTopic จาก Firestore Document
  factory ExerciseTopic.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return ExerciseTopic(
      id: snapshot.id,
      nameTh: data['name_th'] ?? '',
      nameEn: data['name_en'] ?? '',
      grade: data['grade'] ?? '',
      icon: data['icon'] ?? '📚',
      color: data['color'] ?? '#90CAF9',
      order: data['order'] ?? 0,
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  /// แปลง ExerciseTopic เป็น Map สำหรับบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'name_th': nameTh,
      'name_en': nameEn,
      'grade': grade,
      'icon': icon,
      'color': color,
      'order': order,
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// คัดลอก ExerciseTopic พร้อมแก้ไขบางฟิลด์
  ExerciseTopic copyWith({
    String? id,
    String? nameTh,
    String? nameEn,
    String? grade,
    String? icon,
    String? color,
    int? order,
    bool? isActive,
  }) {
    return ExerciseTopic(
      id: id ?? this.id,
      nameTh: nameTh ?? this.nameTh,
      nameEn: nameEn ?? this.nameEn,
      grade: grade ?? this.grade,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}