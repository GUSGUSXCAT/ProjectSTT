import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:LumoRead/screen/MaeKobSetScreen.dart';

class MaeKobMainScreen extends StatelessWidget {
  const MaeKobMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'มาตราตัวสะกด 8 แม่',
          style: GoogleFonts.mali(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink.shade100,
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
              '🎯 เลือกแม่ที่ต้องการฝึก',
              style: GoogleFonts.mali(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMaeButton(
                  context,
                  'แม่กบ',
                  Colors.green.shade100,
                  '🐸', 
                ),
                _buildMaeButton(
                  context,
                  'แม่กด',
                  Colors.blue.shade100,
                  '🌽', 
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMaeButton(
                  context,
                  'แม่เกอว',
                  Colors.orange.shade100,
                  '🥥', 
                ),
                _buildMaeButton(
                  context,
                  'แม่เกย',
                  Colors.purple.shade100,
                  '🍌', 
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMaeButton(
                  context,
                  'แม่กม',
                  Colors.pink.shade100,
                  '🍊', 
                ),
                _buildMaeButton(
                  context,
                  'แม่กน',
                  Colors.yellow.shade100,
                  '🍋', 
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMaeButton(
                  context,
                  'แม่กง',
                  Colors.teal.shade100,
                  '🥭', 
                ),
                _buildMaeButton(
                  context,
                  'แม่กก',
                  Colors.brown.shade100,
                  '🥬', 
                ),
              ],
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

  Widget _buildMaeButton(
    BuildContext context,
    String maeName,
    Color color,
    String emoji, 
  ) {
    return Expanded(
      child: Padding(
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
                  builder: (_) => MaeKobSetScreen(type: maeName),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 140,
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
                    style: const TextStyle(fontSize: 50),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    maeName,
                    style: GoogleFonts.mali(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}