import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/LeadingConsonantscreen.dart';
import 'package:LumoRead/screen/LeadingConsonantDragDropScreen.dart';

class LeadingConsonantSetScreen extends StatefulWidget {
  final String type;

  const LeadingConsonantSetScreen({super.key, required this.type, required String set});

  @override
  State<LeadingConsonantSetScreen> createState() => _LeadingConsonantSetScreenState();
}

class _LeadingConsonantSetScreenState extends State<LeadingConsonantSetScreen> {
  String selectedMode = 'reading';

  String getTypeName() {
    switch (widget.type) {
      case "1":
        return "อักษร ห นำ";
      case "2":
        return "ไม่มี ห นำ";
      case "3":
        return "อักษร อ นำ ย";
      default:
        return "ประเภทไม่ทราบ";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "เลือกชุดแบบฝึก (${getTypeName()})",
          style: GoogleFonts.mali(fontSize: 18),
        ),
        backgroundColor: Colors.teal.shade100,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Card เลือก Mode
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade50,
                      Colors.cyan.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          '📚 เลือกรูปแบบการฝึก',
                          style: GoogleFonts.mali(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // ปุ่มเลือก Mode
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeChip(
                            label: '🎤 อ่านออกเสียง',
                            mode: 'reading',
                            color: Colors.blue.shade100,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModeChip(
                            label: '🎯 ลากวาง',
                            mode: 'drag_drop',
                            color: Colors.green.shade100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              '📝 เลือกชุดแบบฝึก',
              style: GoogleFonts.mali(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 16),

            
            if (widget.type == "3")
              _buildSetBtn(
                context,
                "แบบฝึกหัด ชุดที่ 1",
                Colors.teal.shade100,
                "1",
                '1️⃣',
              )
            else ...[
              _buildSetBtn(
                context,
                "แบบฝึกหัด ชุดที่ 1",
                Colors.teal.shade100,
                "1",
                '1️⃣',
              ),
              _buildSetBtn(
                context,
                "แบบฝึกหัด ชุดที่ 2",
                Colors.teal.shade200,
                "2",
                '2️⃣',
              ),
              _buildSetBtn(
                context,
                "แบบฝึกหัด ชุดที่ 3",
                Colors.teal.shade300,
                "3",
                '3️⃣',
              ),
            ],

            const SizedBox(height: 30),
            
            const Image(
              image: AssetImage('images/reading.png'),
              width: 180,
              errorBuilder: null,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required String mode,
    required Color color,
  }) {
    final isSelected = selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          selectedMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black54 : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.mali(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black87 : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSetBtn(
    BuildContext context,
    String title,
    Color color,
    String set,
    String emoji,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 70),
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
              shadowColor: Colors.black26,
            ),
            onPressed: () {
              if (selectedMode == 'reading') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadingConsonantscreen(
                      type: widget.type,
                      set: set,
                    ),
                  ),
                );
              } else if (selectedMode == 'drag_drop') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadingConsonantDragDropScreen(
                      type: widget.type,
                      set: set,
                    ),
                  ),
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.mali(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}