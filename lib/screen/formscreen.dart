import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; //  นำเข้า Firestore

class Formscreen extends StatefulWidget {
  const Formscreen({super.key});

  @override
  _FormscreenState createState() => _FormscreenState();
}

class _FormscreenState extends State<Formscreen> {
  final formkey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; //  เชื่อม Firestore

  String fname = '';
  String lname = '';
  int id = 0;
  int year = 0;
  String score = '';

  void saveToFirestore() async {
    if (formkey.currentState!.validate()) {
      formkey.currentState!.save();
      
     
      await _firestore.collection('students').add({
        'fname': fname,
        'lname': lname,
        'id': id,
        'year': year,
        'score': score,
        'created_at': FieldValue.serverTimestamp(),
      });

      // ✅ แสดง Alert เมื่อบันทึกเสร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูลสำเร็จ!')),
      );

      // ✅ ล้างค่าฟอร์ม
      formkey.currentState!.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แบบฟอร์มบันทึกข้อมูลนักเรียน')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formkey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                context,
                'ชื่อ',
                onSaved: (value) => fname = value ?? '',
              ),
              _buildTextField(
                context,
                'นามสกุล',
                onSaved: (value) => lname = value ?? '',
              ),
              _buildTextField(
                context,
                'เลขที่',
                keyboardType: TextInputType.number,
                onSaved: (value) => id = int.tryParse(value ?? '0') ?? 0,
              ),
              _buildTextField(
                context,
                'ชั้นปี',
                keyboardType: TextInputType.number,
                onSaved: (value) => year = int.tryParse(value ?? '0') ?? 0,
              ),
              _buildTextField(
                context,
                'คะแนน',
                onSaved: (value) => score = value ?? '',
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: saveToFirestore, //  บันทึกลง Firestore
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text(
                    "บันทึกข้อมูล",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String labelText, {
    TextInputType keyboardType = TextInputType.text,
    required FormFieldSetter<String> onSaved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
          ),
          keyboardType: keyboardType,
          onSaved: onSaved,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอก $labelText';
            }
            return null;
          },
        ),
      ],
    );
  }
}
