import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/ConsonantBlendSetScreen.dart';

class ConsonantBlendMainScreen extends StatelessWidget {
  const ConsonantBlendMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'คำควบกล้ำ',
          style: GoogleFonts.mali(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple.shade100,
        centerTitle: true,
        elevation: 2,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Text(
              '🎯 เลือกประเภทที่ต้องการฝึก',
              style: GoogleFonts.mali(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 30),

            
            _buildTypeButton(
              context,
              'คำควบแท้',
              '1',
              Colors.blue.shade100,
              '🎒', 
            ),
            const SizedBox(height: 20),

            _buildTypeButton(
              context,
              'คำควบไม่แท้',
              '2',
              Colors.orange.shade100,
              '🦅', 
            ),

            const SizedBox(height: 40),

            // รูปประกอบด้านล่าง
            const Image(
              image: AssetImage('images/nani.png'),
              width: 200,
              errorBuilder: null,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

 
  Widget _buildTypeButton(
    BuildContext context,
    String typeName,
    String typeId,
    Color color,
    String emoji, 
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsonantBlendSetScreen(type: typeId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ⭐ เปลี่ยนจาก Icon เป็น Text สำหรับแสดง emoji
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 80), // ขนาดใหญ่เท่ากับ icon เดิม
                ),
                const SizedBox(height: 12),
                Text(
                  typeName,
                  style: GoogleFonts.mali(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                // ⭐ เอาส่วน example ออก
              ],
            ),
          ),
        ),
      ),
    );
  }
}