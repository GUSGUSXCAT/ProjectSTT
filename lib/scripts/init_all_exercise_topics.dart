import 'package:cloud_firestore/cloud_firestore.dart';

/// สคริปต์เพิ่มข้อมูลหัวข้อทั้งหมด (29 หัวข้อ) ลง Firebase
Future<void> initAllExerciseTopics() async {
  final firestore = FirebaseFirestore.instance;

  // ข้อมูลหัวข้อทั้งหมด 29 หัวข้อ
  final topics = [
    // ==================== ป.1 (9 หัวข้อ) ====================
    {
      'id': 'toneplacement',
      'name_th': 'การวางวรรณยุกต์',
      'name_en': 'Tone Placement',
      'grade': 'ป.1',
      'icon': '🎵',
      'color': '#FFB74D',
      'order': 1,
      'is_active': true,
    },
    {
      'id': 'tonemarks',
      'name_th': 'เครื่องหมายวรรณยุกต์',
      'name_en': 'Tone Marks',
      'grade': 'ป.1',
      'icon': '✍️',
      'color': '#64B5F6',
      'order': 2,
      'is_active': true,
    },
    {
      'id': 'spellingaccstandard',
      'name_th': 'การสะกดคำมาตรฐาน',
      'name_en': 'Standard Spelling',
      'grade': 'ป.1',
      'icon': '📝',
      'color': '#81C784',
      'order': 3,
      'is_active': true,
    },
    {
      'id': 'singlevowel',
      'name_th': 'สระเดี่ยว',
      'name_en': 'Single Vowel',
      'grade': 'ป.1',
      'icon': '🔤',
      'color': '#FFD54F',
      'order': 4,
      'is_active': true,
    },
    {
      'id': 'consonants',
      'name_th': 'พยัญชนะ',
      'name_en': 'Consonants',
      'grade': 'ป.1',
      'icon': '🅰️',
      'color': '#E57373',
      'order': 5,
      'is_active': true,
    },
    {
      'id': 'blendedvowels',
      'name_th': 'สระประสม',
      'name_en': 'Blended Vowels',
      'grade': 'ป.1',
      'icon': '🎨',
      'color': '#BA68C8',
      'order': 6,
      'is_active': true,
    },
    {
      'id': 'quiz',
      'name_th': 'แบบทดสอบ',
      'name_en': 'Quiz',
      'grade': 'ป.1',
      'icon': '✅',
      'color': '#4DB6AC',
      'order': 7,
      'is_active': true,
    },
    {
      'id': 'reading_spell',
      'name_th': 'อ่าน-สะกดคำ',
      'name_en': 'Reading & Spelling',
      'grade': 'ป.1',
      'icon': '📖',
      'color': '#90A4AE',
      'order': 8,
      'is_active': true,
    },
    {
      'id': 'readingwords',
      'name_th': 'อ่านคำ',
      'name_en': 'Reading Words',
      'grade': 'ป.1',
      'icon': '📚',
      'color': '#AED581',
      'order': 9,
      'is_active': true,
    },

    // ==================== ป.2 (17 หัวข้อ) ====================
    {
      'id': 'leading_consonant',
      'name_th': 'อักษรนำ',
      'name_en': 'Leading Consonant',
      'grade': 'ป.2',
      'icon': '✏️',
      'color': '#B39DDB',
      'order': 1,
      'is_active': true,
    },
    {
      'id': 'consonant_blends',
      'name_th': 'คำควบกล้ำ',
      'name_en': 'Consonant Blends',
      'grade': 'ป.2',
      'icon': '🔤',
      'color': '#81C784',
      'order': 2,
      'is_active': true,
    },
    {
      'id': 'drag_drop',
      'name_th': 'ลากคำให้เติมให้ครบ',
      'name_en': 'Drag and Drop',
      'grade': 'ป.2',
      'icon': '🎯',
      'color': '#80CBC4',
      'order': 3,
      'is_active': true,
    },
    {
      'id': 'longvowels',
      'name_th': 'สระเสียงยาว',
      'name_en': 'Long Vowels',
      'grade': 'ป.2',
      'icon': '🎵',
      'color': '#FF8A65',
      'order': 4,
      'is_active': true,
    },
    {
      'id': 'mae_ka',
      'name_th': 'แม่ ก กา',
      'name_en': 'Mae Ka',
      'grade': 'ป.2',
      'icon': '📝',
      'color': '#FFE082',
      'order': 5,
      'is_active': true,
    },
    
    // 8 แม่
    {
      'id': 'mae_kob',
      'name_th': 'มาตราตัวสะกด แม่กบ',
      'name_en': 'Mae Kob',
      'grade': 'ป.2',
      'icon': '🐸',
      'color': '#A5D6A7',
      'order': 6,
      'is_active': true,
    },
    {
      'id': 'mae_kod',
      'name_th': 'มาตราตัวสะกด แม่กด',
      'name_en': 'Mae Kod',
      'grade': 'ป.2',
      'icon': '🌽',
      'color': '#90CAF9',
      'order': 7,
      'is_active': true,
    },
    {
      'id': 'mae_koew',
      'name_th': 'มาตราตัวสะกด แม่เกอว',
      'name_en': 'Mae Koew',
      'grade': 'ป.2',
      'icon': '🥥',
      'color': '#FFCC80',
      'order': 8,
      'is_active': true,
    },
    {
      'id': 'mae_koey',
      'name_th': 'มาตราตัวสะกด แม่เกย',
      'name_en': 'Mae Koey',
      'grade': 'ป.2',
      'icon': '🍌',
      'color': '#CE93D8',
      'order': 9,
      'is_active': true,
    },
    {
      'id': 'mae_kom',
      'name_th': 'มาตราตัวสะกด แม่กม',
      'name_en': 'Mae Kom',
      'grade': 'ป.2',
      'icon': '🍊',
      'color': '#F48FB1',
      'order': 10,
      'is_active': true,
    },
    {
      'id': 'mae_kon',
      'name_th': 'มาตราตัวสะกด แม่กน',
      'name_en': 'Mae Kon',
      'grade': 'ป.2',
      'icon': '🍋',
      'color': '#FFF59D',
      'order': 11,
      'is_active': true,
    },
    {
      'id': 'mae_kong',
      'name_th': 'มาตราตัวสะกด แม่กง',
      'name_en': 'Mae Kong',
      'grade': 'ป.2',
      'icon': '🥭',
      'color': '#80DEEA',
      'order': 12,
      'is_active': true,
    },
    {
      'id': 'mae_kk',
      'name_th': 'มาตราตัวสะกด แม่กก',
      'name_en': 'Mae Kk',
      'grade': 'ป.2',
      'icon': '🥬',
      'color': '#A1887F',
      'order': 13,
      'is_active': true,
    },
    
    {
      'id': 'quiz_g2',
      'name_th': 'แบบทดสอบ',
      'name_en': 'Quiz',
      'grade': 'ป.2',
      'icon': '✅',
      'color': '#BCAAA4',
      'order': 14,
      'is_active': true,
    },
    {
      'id': 'reading_practice',
      'name_th': 'การอ่านคำ',
      'name_en': 'Reading Practice',
      'grade': 'ป.2',
      'icon': '📖',
      'color': '#90A4AE',
      'order': 15,
      'is_active': true,
    },
    {
      'id': 'short_sentences',
      'name_th': 'ประโยคสั้น',
      'name_en': 'Short Sentences',
      'grade': 'ป.2',
      'icon': '💬',
      'color': '#EF9A9A',
      'order': 16,
      'is_active': true,
    },

    // ==================== ป.3 (3 หัวข้อ) ====================
    {
      'id': 'not_pavit',
      'name_th': 'คำไม่มีการันต์',
      'name_en': 'Words without Karan',
      'grade': 'ป.3',
      'icon': '📄',
      'color': '#9FA8DA',
      'order': 1,
      'is_active': true,
    },
    {
      'id': 'pavit',
      'name_th': 'คำมีการันต์',
      'name_en': 'Words with Karan',
      'grade': 'ป.3',
      'icon': '📃',
      'color': '#80CBC4',
      'order': 2,
      'is_active': true,
    },
    {
      'id': 'reding_long',
      'name_th': 'อ่านยาว',
      'name_en': 'Long Reading',
      'grade': 'ป.3',
      'icon': '📚',
      'color': '#A5D6A7',
      'order': 3,
      'is_active': true,
    },
  ];

  print('🔧 เริ่มเพิ่มข้อมูลหัวข้อทั้งหมด (${topics.length} หัวข้อ)...');
  print('📊 ป.1: 9 หัวข้อ | ป.2: 17 หัวข้อ | ป.3: 3 หัวข้อ\n');

  int successCount = 0;
  int failCount = 0;

  for (final topic in topics) {
    try {
      final id = topic['id'] as String;
      final payload = Map<String, dynamic>.from(topic);
      payload.remove('id');
      payload['created_at'] = FieldValue.serverTimestamp();
      payload['updated_at'] = FieldValue.serverTimestamp();

      await firestore.collection('exercise_topics').doc(id).set(
        payload,
        SetOptions(merge: true),
      );

      print('✅ ${topic['grade']} | ${topic['name_th']} (${topic['id']})');
      successCount++;
    } catch (e) {
      print('❌ ผิดพลาด: ${topic['name_th']} - $e');
      failCount++;
    }
  }

  print('\n🎉 เสร็จสิ้น!');
  print('✅ สำเร็จ: $successCount หัวข้อ');
  print('❌ ผิดพลาด: $failCount หัวข้อ');
}