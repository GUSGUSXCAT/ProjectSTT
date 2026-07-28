import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});
  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
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
          'คู่มือการใช้งาน',
          style: GoogleFonts.mali(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // ── Intro ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วิธีเล่น',
                      style: GoogleFonts.mali(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D2D2D),
                      ),
                    ),
                    Text(
                      'กดปุ่ม 🔊 เพื่อฟังคำอธิบาย',
                      style: GoogleFonts.mali(
                        fontSize: 13,
                        color: const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildCard(
            id: 'start',
            emoji: '🚀',
            title: 'เริ่มต้นใช้งาน',
            accentColor: const Color(0xFF4A90D9),
            steps: const [
              'เข้าสู่ระบบด้วยชื่อผู้ใช้',
              'เลือกหัวข้อที่อยากฝึก',
              'เลือกชุดที่ต้องการทำ',
              'กดเริ่มทำแบบฝึกหัด',
            ],
            speakText:
                'เริ่มต้นใช้งาน หนึ่ง เข้าสู่ระบบ สอง เลือกหัวข้อ สาม เลือกชุด สี่ เริ่มทำแบบฝึกหัด',
          ),

          _buildCard(
            id: 'speech',
            emoji: '🎤',
            title: 'ฝึกอ่านออกเสียง',
            accentColor: const Color(0xFFE05C7A),
            steps: const [
              'ดูคำบนหน้าจอ',
              'กดปุ่มไมค์แล้วพูด',
              'ถูก → กดถัดไป',
              'ผิด → ลองใหม่ได้เลย',
            ],
            speakText: 'ฝึกอ่านออกเสียง ดูคำบนหน้าจอ กดปุ่มไมค์แล้วพูด ถูกกดถัดไป ผิดลองใหม่',
          ),

          _buildCard(
            id: 'quiz',
            emoji: '✏️',
            title: 'ทำข้อสอบ',
            accentColor: const Color(0xFF3DAA6B),
            steps: const [
              'อ่านคำถาม',
              'เลือกคำตอบ 1 ใน 4',
              'กดยืนยัน',
              'ดูผลและกดถัดไป',
            ],
            speakText: 'ทำข้อสอบ อ่านคำถาม เลือกคำตอบ กดยืนยัน แล้วดูผล',
          ),

          _buildCard(
            id: 'dragdrop',
            emoji: '🧩',
            title: 'เติมคำในช่องว่าง',
            accentColor: const Color(0xFFE07B3D),
            steps: const [
              'อ่านประโยคและดูช่องว่าง',
              'ลากคำจากคลังมาวางในช่อง',
              'แตะคำในช่องเพื่อนำคืน',
              'กดตรวจคำตอบเมื่อเติมครบ',
            ],
            speakText: 'เติมคำในช่องว่าง อ่านประโยค ลากคำมาวาง กดตรวจ',
          ),

          _buildCard(
            id: 'article',
            emoji: '📖',
            title: 'อ่านบทความ',
            accentColor: const Color(0xFF8A63D2),
            steps: const [
              'กดเมนูอ่านบทความ',
              'เลือกบทความที่ชอบ',
              'กด 🎤 แล้วอ่านทีละบรรทัด',
              '🟢 = ถูก  🔴 = ผิด',
            ],
            speakText: 'อ่านบทความ กดเมนู เลือกบทความ อ่านทีละบรรทัด สีเขียวคือถูก สีแดงคือผิด',
          ),

          _buildCard(
            id: 'classify',
            emoji: '🗂️',
            title: 'จัดหมวดหมู่คำ',
            accentColor: const Color(0xFF7B52D4),
            steps: const [
              'ดูคำศัพท์ทั้งหมดด้านบน',
              'ลากคำไปวางในหมวดหมู่',
              'แตะคำในหมวดเพื่อย้ายกลับ',
              'กดตรวจคำตอบเมื่อจัดครบ',
            ],
            speakText: 'จัดหมวดหมู่คำ ดูคำศัพท์ ลากคำไปวาง กดตรวจ',
          ),

          // ── Tips ──
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'เคล็ดลับ',
                      style: GoogleFonts.mali(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7A5C00),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTipRow('🔇', 'อยู่ในที่เงียบ พูดชัดๆ'),
                _buildTipRow('🎙️', 'อยู่ใกล้ไมค์พอดี'),
                _buildTipRow('⭐', 'ฝึกบ่อยๆ จะเก่งขึ้น'),
                _buildTipRow('💪', 'ผิดก็ไม่เป็นไร ลองใหม่!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String id,
    required String emoji,
    required String title,
    required Color accentColor,
    required List<String> steps,
    required String speakText,
  }) {
    final isSpeaking = _speakingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title row ──
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.mali(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _speak(id, speakText),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSpeaking
                          ? accentColor
                          : accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: isSpeaking ? Colors.white : accentColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Steps — 2 columns 
            _buildStepsGrid(steps, accentColor),
          ],
        ),
      ),
    );
  }

  /// แสดง steps แบบ 2 คอลัมน์ ลดพื้นที่สูญเปล่า
  Widget _buildStepsGrid(List<String> steps, Color accent) {
    final rows = <Widget>[];
    for (int i = 0; i < steps.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _buildStep(i + 1, steps[i], accent)),
            if (i + 1 < steps.length)
              Expanded(child: _buildStep(i + 2, steps[i + 1], accent))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < steps.length) const SizedBox(height: 4);
    }
    return Column(
      children: rows
          .expand((w) => [w, const SizedBox(height: 4)])
          .toList()
          ..removeLast(),
    );
  }

  Widget _buildStep(int num, String text, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Text(
              '$num',
              style: GoogleFonts.mali(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.mali(
              fontSize: 16,
              color: const Color(0xFF444444),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.mali(
              fontSize: 13,
              color: const Color(0xFF5C4A00),
            ),
          ),
        ],
      ),
    );
  }
}