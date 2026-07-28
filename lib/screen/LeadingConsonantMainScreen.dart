import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/LeadingConsonantSetScreen.dart';

class LeadingConsonantMainScreen extends StatelessWidget {
  const LeadingConsonantMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'อักษรนำ',
          style: GoogleFonts.mali(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal.shade100,
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
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 30),

            // อักษร ห นำ
            _buildTypeButton(
              context,
              'อักษร ห นำ',
              '1',
              Colors.teal.shade100,
              'ห',
            ),
            const SizedBox(height: 20),

            // ไม่มี ห นำ
            _buildTypeButton(
              context,
              'ไม่มี ห นำ',
              '2',
              Colors.cyan.shade100,
              '🚫',
            ),
            const SizedBox(height: 20),

            // อักษร อ นำ ย
            _buildTypeButton(
              context,
              'อักษร อ นำ ย',
              '3',
              Colors.lightBlue.shade100,
              'อ',
            ),

            const SizedBox(height: 40),

          
            const Image(
              image: AssetImage('images/reading.png'),
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
                builder: (_) => LeadingConsonantSetScreen(type: typeId, set: '',),
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
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 80),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}