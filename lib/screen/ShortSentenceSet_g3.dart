import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/ShortSentencePracticeScreen.dart';

class ShortSentenceSetG3Screen extends StatefulWidget {
  const ShortSentenceSetG3Screen({super.key});

  @override
  State<ShortSentenceSetG3Screen> createState() => _ShortSentenceSetG3ScreenState();
}

class _ShortSentenceSetG3ScreenState extends State<ShortSentenceSetG3Screen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "เลือกชุดฝึกอ่านประโยคสั้น ๆ",
          style: GoogleFonts.mali(fontSize: 18),
        ),
        backgroundColor: Colors.deepOrange.shade100,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // // Header Card
            // Card(
            //   elevation: 3,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(15),
            //   ),
            //   child: Container(
            //     width: double.infinity,
            //     padding: const EdgeInsets.all(20),
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(
            //         colors: [
            //           Colors.deepOrange.shade50,
            //           Colors.orange.shade50,
            //         ],
            //         begin: Alignment.topLeft,
            //         end: Alignment.bottomRight,
            //       ),
            //       borderRadius: BorderRadius.circular(15),
            //     ),
            //     child: Column(
            //       children: [
            //         Icon(
            //           Icons.auto_stories,
            //           size: 50,
            //           color: Colors.deepOrange.shade700,
            //         ),
            //         const SizedBox(height: 12),
            //         Text(
            //           'ฝึกอ่านประโยคสั้น ๆ',
            //           style: GoogleFonts.mali(
            //             fontSize: 22,
            //             fontWeight: FontWeight.bold,
            //             color: Colors.deepOrange.shade900,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           'สำหรับนักเรียนชั้นประถมศึกษาปีที่ 3',
            //           style: GoogleFonts.mali(
            //             fontSize: 16,
            //             color: Colors.grey.shade700,
            //           ),
            //           textAlign: TextAlign.center,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            const SizedBox(height: 24),

            Text(
              '📝 เลือกชุดแบบฝึก',
              style: GoogleFonts.mali(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 16),

         
            _buildSetBtn(
              context,
              "แบบฝึกหัดอ่านประโยค ชุดที่ 1",
              Colors.deepOrange.shade100,
              "1",
              '1️⃣',
            ),
            _buildSetBtn(
              context,
              "แบบฝึกหัดอ่านประโยค ชุดที่ 2",
              Colors.orange.shade100,
              "2",
              '2️⃣',
            ),
            _buildSetBtn(
              context,
              "แบบฝึกหัดอ่านประโยค ชุดที่ 3",
              Colors.deepOrange.shade200,
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
                  builder: (_) => ShortSentencePracticeScreen(set: set),
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