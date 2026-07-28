import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _guides = <String, Map<String, dynamic>>{
  'reading': {
    'emoji': '🎤',
    'title': 'ฝึกอ่านออกเสียง',
    'color': Color(0xFFE05C7A),
    'steps': [
      '👁️  ดูคำที่แสดงบนหน้าจอ',
      '🎤  กดปุ่มไมค์แล้วพูดออกมา',
      '✅  ถูก → กดถัดไป',
      '🔄  ผิด → ลองใหม่ได้เลย',
    ],
  },
  'quiz': {
    'emoji': '✏️',
    'title': 'ทำแบบทดสอบ',
    'color': Color(0xFF3DAA6B),
    'steps': [
      '📋  อ่านคำถามให้ครบก่อนเลือก',
      '👆  กดตัวเลือกที่ถูกต้อง',
      '📨  กด "ยืนยัน" เพื่อส่งคำตอบ',
      '➡️  ดูผลแล้วกดไปข้อถัดไป',
    ],
  },
  'drag_drop': {
    'emoji': '🧩',
    'title': 'เติมคำในช่องว่าง',
    'color': Color(0xFFE07B3D),
    'steps': [
      '📖  อ่านประโยคและดูช่องว่าง',
      '✋  ลากคำจากคลังมาวางในช่อง',
      '↩️  แตะคำในช่องเพื่อนำคืนคลัง',
      '📝  กดตรวจคำตอบเมื่อเติมครบ',
    ],
  },
  'article': {
    'emoji': '📖',
    'title': 'อ่านบทความ',
    'color': Color(0xFF8A63D2),
    'steps': [
      '🟠  อ่านบรรทัดที่ไฮไลต์สีส้ม',
      '🎤  กดปุ่มไมค์แล้วอ่านออกเสียง',
      '⏹️  กด "หยุด" เพื่อส่งเสียง',
      '🟢 ถูก / 🔴 ผิด (อ่านได้ 3 ครั้ง)',
    ],
  },
  'classify': {
    'emoji': '🗂️',
    'title': 'จัดหมวดหมู่คำ',
    'color': Color(0xFF7B52D4),
    'steps': [
      '👀  ดูคำศัพท์ทั้งหมดด้านบน',
      '✋  ลากคำไปวางในหมวดหมู่',
      '↩️  แตะคำในหมวดเพื่อย้ายกลับ',
      '📝  กดตรวจคำตอบเมื่อจัดครบ',
    ],
  },
};

class ExerciseGuideDialog extends StatelessWidget {
  final String mode;
  final VoidCallback onStart;

  const ExerciseGuideDialog({
    super.key,
    required this.mode,
    required this.onStart,
  });

  static Future<void> show(
    BuildContext context, {
    required String mode,
    bool alwaysShow = true,
    String prefKey = '',
  }) async {
    if (!alwaysShow && prefKey.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('guide_$prefKey') == true) return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExerciseGuideDialog(
        mode: mode,
        onStart: () {
          Navigator.of(context).pop();
          if (!alwaysShow && prefKey.isNotEmpty) {
            SharedPreferences.getInstance()
                .then((p) => p.setBool('guide_$prefKey', true));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _guides[mode] ?? _guides['reading']!;
    final color = g['color'] as Color;
    final steps = g['steps'] as List<String>;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // header
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    g['emoji'] as String,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                g['title'] as String,
                style: GoogleFonts.mali(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              // Text(
              //   'วิธีเล่น',
              //   style: GoogleFonts.mali(fontSize: 12, color: Colors.grey),
              // ),
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // steps 2x2
              ...List.generate((steps.length / 2).ceil(), (row) {
                final left = steps[row * 2];
                final right = (row * 2 + 1 < steps.length)
                    ? steps[row * 2 + 1]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: _StepTile(text: left, color: color)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: right != null
                            ? _StepTile(text: right, color: color)
                            : const SizedBox(),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 6),

              if(mode =='speech'|| mode == 'main_screen')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💡 อยู่ในที่เงียบ พูดชัดๆ ใกล้ไมค์',
                  style: GoogleFonts.mali(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 14),

              // button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'เริ่มกันเลย!',
                    style: GoogleFonts.mali(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String text;
  final Color color;

  const _StepTile({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.mali(
          fontSize: 12,
          color: const Color(0xFF333333),
          height: 1.4,
        ),
      ),
    );
  }
}