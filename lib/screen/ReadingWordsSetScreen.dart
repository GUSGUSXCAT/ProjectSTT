import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/ReadingWordsScreen.dart';

class ReadingWordsSetScreen extends StatelessWidget {
  const ReadingWordsSetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "เลือกชุดแบบฝึก",
          style: GoogleFonts.mali(fontSize: 18),
        ),
        backgroundColor: Colors.green.shade100,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            Text(
              '📝 เลือกชุดแบบฝึก',
              style: GoogleFonts.mali(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // ปุ่มชุดต่างๆ
            _buildSetBtn(
              context,
              "แบบฝึกหัด ชุดที่ 1",
              Colors.green.shade100,
              "1",
              '1️⃣',
            ),
            _buildSetBtn(
              context,
              "แบบฝึกหัด ชุดที่ 2",
              Colors.green.shade200,
              "2",
              '2️⃣',
            ),
            _buildSetBtn(
              context,
              "แบบฝึกหัด ชุดที่ 3",
              Colors.green.shade300,
              "3",
              '3️⃣',
            ),

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReadingWordsScreen(set: set),
                ),
              );
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