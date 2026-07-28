import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:LumoRead/screen/ReadingArticle.dart';
import 'dart:convert'; 

class ReadingArticleListScreen extends StatefulWidget {
  final String grade;
  final String topicId;
  final String topicName;

  const ReadingArticleListScreen({
    super.key,
    required this.grade,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<ReadingArticleListScreen> createState() =>
      _ReadingArticleListScreenState();
}

class _ReadingArticleListScreenState extends State<ReadingArticleListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<DocumentSnapshot> articles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchArticles();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('sounds/mixkit-game-click-1114.mp3'));
  }

  // ✅ เพิ่ม helper function สำหรับ parse lines
  List<dynamic> _parseLines(dynamic data) {
    if (data == null) return [];
    
    // ถ้าเป็น List อยู่แล้ว
    if (data is List) {
      return data;
    }
    
    // ถ้าเป็น String (JSON)
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded;
        }
      } catch (e) {
        debugPrint('Error parsing lines: $e');
      }
    }
    
    return [];
  }

  Future<void> fetchArticles() async {
    try {
      final snapshot = await _firestore
          .collection('questions')
          .doc('g_${widget.grade}')
          .collection(widget.topicId)
          .get();

      final activeArticles = snapshot.docs.where((doc) {
        final data = doc.data();
        return (data['is_deleted'] ?? false) == false;
      }).toList();

      setState(() {
        articles = activeArticles;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 5, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                '⏳ รอสักครู่นะ...',
                style: GoogleFonts.mali(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📚 ${widget.topicName.isEmpty ? 'เลือกเรื่องที่อยากอ่าน' : widget.topicName}',
          style: GoogleFonts.mali(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade300,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFFF9E6),
      body: articles.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📖', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีเรื่องให้อ่าน',
                    style: GoogleFonts.mali(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final data = articles[index].data() as Map<String, dynamic>;
                final title = data['title'] ?? 'ไม่มีชื่อ';
                final docId = articles[index].id;
                
                // ✅ ใช้ _parseLines แทนการ cast โดยตรง
                final lines = _parseLines(data['lines']);

                final colorPairs = [
                  [Colors.pink.shade100, Colors.pink.shade50],
                  [Colors.blue.shade100, Colors.blue.shade50],
                  [Colors.green.shade100, Colors.green.shade50],
                  [Colors.purple.shade100, Colors.purple.shade50],
                  [Colors.orange.shade100, Colors.orange.shade50],
                ];
                final colorSet = colorPairs[index % colorPairs.length];

                return GestureDetector(
                  onTap: () async {
                    await _playSound();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReadingArticleScreen(
                            articleId: docId,
                            title: title,
                            grade: widget.grade, 
                            topicId: widget.topicId, 
                            set: docId, 
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colorSet,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorSet[0], width: 4),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.mali(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colorSet[0],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.mali(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('📝', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${lines.length} บรรทัด',
                                      style: GoogleFonts.mali(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: colorSet[0],
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}