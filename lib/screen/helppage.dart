import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQ {
  final String question;
  final String answer;
  final String? imagePath;
  FAQ(this.question, this.answer, {this.imagePath});
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});
  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final FlutterTts _tts = FlutterTts();
  String? _speakingId;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("th-TH");
    _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() => setState(() => _speakingId = null));
    _tts.setCancelHandler(() => setState(() => _speakingId = null));
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String id, String text) async {
    if (_speakingId == id) {
      await _tts.stop();
      setState(() => _speakingId = null);
    } else {
      await _tts.stop();
      setState(() => _speakingId = id);
      await _tts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        title: Text(
          'ช่วยเหลือ',
          style: GoogleFonts.mali(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'มีปัญหาอะไรหรือเปล่า?',
                  style: GoogleFonts.mali(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'กดปุ่ม 🔊 เพื่อฟังคำอธิบาย',
                  style: GoogleFonts.mali(
                    fontSize: 14,
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),

          _buildSection(
            id: 'mic',
            emoji: '🎤',
            title: 'ปัญหาเกี่ยวกับไมค์',
            accentColor: const Color(0xFF4A90D9),
            faqs: [
              FAQ('ไมค์ไม่ทำงาน',
                  imagePath:'assets/images/premit.jpg',
                  'ตรวจสอบว่าอนุญาตให้แอปใช้ไมค์แล้ว ปิดแอปแล้วเปิดใหม่ และเช็คว่าไมค์เสียบดี'),
              FAQ('พูดแล้วไมค์จับเสียงไม่ได้',
                  'พูดดังขึ้นนิดหน่อย อยู่ใกล้ไมค์มากขึ้น อยู่ในที่เงียบๆ และพูดช้าๆ ชัดๆ'),
            ],
            speakText:
                'ปัญหาไมค์ ไมค์ไม่ทำงาน ตรวจสอบการอนุญาต ปิดแล้วเปิดใหม่ พูดแล้วไมค์จับไม่ได้ ให้พูดดังขึ้น อยู่ใกล้ไมค์ และอยู่ในที่เงียบ',
          ),

          _buildSection(
            id: 'sound',
            emoji: '🔊',
            title: 'ปัญหาเกี่ยวกับเสียง',
            accentColor: const Color(0xFFE09A3D),
            faqs: [
              FAQ('ไม่มีเสียงออกมา',
                  imagePath:'assets/images/soud.jpg',
                  'เช็คว่าปุ่มเสียงเปิดอยู่ เพิ่มระดับเสียง ถ้าใช้หูฟังตรวจสอบว่าเสียบดี'),
            ],
            speakText:
                'ปัญหาเสียง ไม่มีเสียงออกมา เช็คว่าปุ่มเสียงเปิดอยู่ เพิ่มระดับเสียง ตรวจสอบหูฟัง',
          ),

          _buildSection(
            id: 'score',
            emoji: '🏆',
            title: 'ปัญหาเกี่ยวกับคะแนน',
            accentColor: const Color(0xFF3DAA6B),
            faqs: [
              FAQ('ทำแบบฝึกหัดแล้วไม่เห็นคะแนน',
                  imagePath:'assets/images/submit.jpg',
                  'ต้องกดปุ่ม เสร็จสิ้นหรือตรวจคำตอบ ก่อน ตรวจสอบว่าทำครบทุกข้อ ถ้ายังไม่เห็นให้รีเฟรชหน้าจอ'),
              FAQ('คะแนนหาย',
                  imagePath:'assets/images/sub.jpg',
                  'คะแนนบันทึกเมื่อทำเสร็จ ถ้าออกก่อนทำเสร็จคะแนนจะไม่ถูกบันทึก ให้ทำจนกดปุ่มเสร็จสิ้นก่อนออก'),
            ],
            speakText:
                'ปัญหาคะแนน ไม่เห็นคะแนนต้องกดเสร็จสิ้นหรือตรวจคำตอบก่อน คะแนนหายเพราะออกก่อนกดเสร็จสิ้น',
          ),

          _buildSection(
            id: 'account',
            emoji: '🔐',
            title: 'ปัญหาเกี่ยวกับบัญชี',
            accentColor: const Color(0xFF8A63D2),
            faqs: [
              FAQ('ลืมรหัสผ่าน',
                  imagePath:'assets/images/wrongpass.jpg',
                  'แจ้งครูทันที ครูจะช่วยรีเซ็ตรหัสผ่านให้ อย่าแชร์รหัสผ่านให้เพื่อน'),
              FAQ('เข้าสู่ระบบไม่ได้',
                  imagePath:'assets/images/CapsLock.jpg',
                  'เช็คว่าพิมพ์ชื่อผู้ใช้และรหัสผ่านถูกต้อง เช็คว่าไม่ได้เผลอเปิดปุ่ม Caps Lockอยู่ ถ้ายังไม่ได้ให้แจ้งครู'),
            ],
            speakText:
                'ปัญหาบัญชี ลืมรหัสผ่านแจ้งครูได้เลย เข้าระบบไม่ได้ให้เช็คการพิมพ์และแจ้งครู',
          ),

          const SizedBox(height: 8),

          // ติดต่อครู
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: const Color(0xFF4A90D9), width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ยังหาคำตอบไม่เจอ?',
                        style: GoogleFonts.mali(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ถามครูได้เลย!',
                        style: GoogleFonts.mali(
                          fontSize: 14,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String id,
    required String emoji,
    required String title,
    required Color accentColor,
    required List<FAQ> faqs,
    required String speakText,
  }) {
    final isSpeaking = _speakingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // หัวข้อ
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.mali(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _speak(id, speakText),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSpeaking
                          ? accentColor
                          : accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: isSpeaking ? Colors.white : accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // FAQ
            ...faqs.asMap().entries.map((e) {
              final isLast = e.key == faqs.length - 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '?',
                            style: GoogleFonts.mali(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value.question,
                          style: GoogleFonts.mali(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      e.value.answer,
                      style: GoogleFonts.mali(
                        fontSize: 13,
                        color: const Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (e.value.imagePath != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          e.value.imagePath!,
                          width: 300,
                          height: 80,
                          fit: BoxFit.fitWidth ,
                        ),
                      ),
                    ),
                  ],
                  if (!isLast) ...[
                    const SizedBox(height: 10),
                    Divider(
                      color: const Color(0xFFEEEEEE),
                      height: 1,
                      indent: 32,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}