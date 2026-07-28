import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:LumoRead/screen/RegisterStudent.dart';
import 'package:LumoRead/screen/RegisterTeacher.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  String? selectedRole; // บทบาทที่เลือก

  void navigateToRegister() {
    if (selectedRole == "teacher") {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => RegisterTeacher()));
    } else if (selectedRole == "student") {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => RegisterStudent()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🖌️ กรุณาเลือกบทบาทก่อนดำเนินการต่อ")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "เลือกบทบาทลงทะเบียน",
          style: GoogleFonts.mali(), 
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth > 600; // แยกเป็นโหมด

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400), // จำกัดความกว้าง
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "กรุณาเลือกบทบาทของคุณ",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.mali( 
                        fontSize: isWideScreen ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      hint: Text(
                        "เลือกบทบาท",
                        style: GoogleFonts.mali(), 
                      ),
                      items: [
                        DropdownMenuItem(value: "teacher", child: Text("👩‍🏫 ครู", style: GoogleFonts.mali())),
                        DropdownMenuItem(value: "student", child: Text("👦 นักเรียน", style: GoogleFonts.mali())),
                      ],
                      onChanged: (value) => setState(() => selectedRole = value),
                    ),
                    SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: navigateToRegister,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isWideScreen ? 16 : 12),
                        textStyle: TextStyle(fontSize: isWideScreen ? 20 : 16),
                      ),
                      child: Text(
                        "ไปหน้าลงทะเบียน",
                        style: GoogleFonts.mali(), 
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
