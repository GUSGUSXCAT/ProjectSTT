// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:myproject/screen/Quiz.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:audioplayers/audioplayers.dart';

// class QuizSetListScreen extends StatefulWidget {
//   const QuizSetListScreen({super.key});

//   @override
//   State<QuizSetListScreen> createState() => _QuizSetListScreenState();
// }

// class _QuizSetListScreenState extends State<QuizSetListScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final AudioPlayer _audioPlayer = AudioPlayer();

//   List<String> sets = [];
//   bool isLoading = true;
//   String? classLevel;

//   @override
//   void initState() {
//     super.initState();
//     fetchUserClassLevel();
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     super.dispose();
//   }

//   Future<void> _playSound() async {
//     await _audioPlayer.play(AssetSource('sounds/mixkit-game-click-1114.mp3'));
//   }

//   Future<void> fetchUserClassLevel() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final username = prefs.getString('username');

//       if (username == null) {
//         _showError('กรุณาเข้าสู่ระบบใหม่');
//         return;
//       }

//       final userDoc = await _firestore
//           .collection('users')
//           .where('username', isEqualTo: username)
//           .limit(1)
//           .get();

//       if (userDoc.docs.isEmpty) {
//         _showError('ไม่พบข้อมูลผู้ใช้');
//         return;
//       }

//       final userData = userDoc.docs.first.data();
//       classLevel = userData['class_level'] as String?;

//       if (classLevel != null) {
//         fetchQuizSets(classLevel!);
//       } else {
//         _showError('ไม่พบระดับชั้นเรียน');
//       }
//     } catch (e) {
//       debugPrint('Error: $e');
//       _showError('เกิดข้อผิดพลาด');
//     }
//   }

//   Future<void> fetchQuizSets(String level) async {
//     try {
//       debugPrint('🔍 Fetching quiz sets for g_$level');

//       final snapshot = await _firestore
//           .collection('questions')
//           .doc('g_$level')
//           .collection('quiz')
//           .get();

//       // ดึง set ที่ไม่ซ้ำกัน
//       final setList = <String>{};
//       for (var doc in snapshot.docs) {
//         final data = doc.data();
//         final set = data['set'] as String?;
//         if (set != null && set.isNotEmpty) {
//           setList.add(set);
//         }
//       }

//       // เรียงลำดับ set
//       final sortedSets = setList.toList()
//         ..sort((a, b) {
//           final aNum = int.tryParse(a) ?? 0;
//           final bNum = int.tryParse(b) ?? 0;
//           return aNum.compareTo(bNum);
//         });

//       debugPrint('✅ Found ${sortedSets.length} sets: $sortedSets');

//       setState(() {
//         sets = sortedSets;
//         isLoading = false;
//       });
//     } catch (e) {
//       debugPrint('❌ Error: $e');
//       _showError('ไม่สามารถโหลดชุดแบบทดสอบได้');
//     }
//   }

//   void _showError(String message) {
//     setState(() => isLoading = false);
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text('เกิดข้อผิดพลาด', style: GoogleFonts.mali()),
//         content: Text(message, style: GoogleFonts.mali()),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(ctx);
//               Navigator.pop(context);
//             },
//             child: Text('ตกลง', style: GoogleFonts.mali()),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return Scaffold(
//         backgroundColor: const Color(0xFFFFFAF0),
//         body: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const CircularProgressIndicator(),
//               const SizedBox(height: 12),
//               Text('กำลังโหลด...', style: GoogleFonts.mali()),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           '📚 เลือกชุดแบบทดสอบ',
//           style: GoogleFonts.mali(fontSize: 18),
//         ),
//         backgroundColor: Colors.pink.shade100,
//       ),
//       backgroundColor: const Color(0xFFFFFAF0),
//       body: sets.isEmpty
//           ? Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.quiz_outlined,
//                       size: 80, color: Colors.grey.shade400),
//                   const SizedBox(height: 16),
//                   Text(
//                     'ยังไม่มีแบบทดสอบ',
//                     style: GoogleFonts.mali(
//                       fontSize: 18,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(20),
//               itemCount: sets.length,
//               itemBuilder: (context, index) {
//                 final set = sets[index];

//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   elevation: 3,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(15),
//                   ),
//                   child: InkWell(
//                     onTap: () async {
//                       await _playSound();
//                       if (context.mounted) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => QuizScreen(
//                               set: set,
//                               classLevel: classLevel!,
//                             ),
//                           ),
//                         );
//                       }
//                     },
//                     borderRadius: BorderRadius.circular(15),
//                     child: Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(15),
//                         gradient: LinearGradient(
//                           colors: [
//                             Colors.pink.shade50,
//                             Colors.white,
//                           ],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                       ),
//                       child: Row(
//                         children: [
                     
//                           Container(
//                             width: 60,
//                             height: 60,
//                             decoration: BoxDecoration(
//                               color: Colors.pink.shade600,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Center(
//                               child: Text(
//                                 set,
//                                 style: GoogleFonts.mali(
//                                   fontSize: 28,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 20),

                     
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'ชุดที่ $set',
//                                   style: GoogleFonts.mali(
//                                     fontSize: 22,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.pink.shade900,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   'แบบทดสอบอ่านรู้เรื่อง',
//                                   style: GoogleFonts.mali(
//                                     fontSize: 16,
//                                     color: Colors.grey.shade700,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           ElevatedButton(
//                             onPressed: () async {
//                               await _playSound();
//                               if (context.mounted) {
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (_) => QuizScreen(
//                                       set: set,
//                                       classLevel: classLevel!,
//                                     ),
//                                   ),
//                                 );
//                               }
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.pink.shade600,
//                               foregroundColor: Colors.white,
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 12,
//                               ),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                             ),
//                             child: Text(
//                               'เริ่มทำ',
//                               style: GoogleFonts.mali(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }