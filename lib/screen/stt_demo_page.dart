import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart'; // ✅ เพิ่ม
import 'dart:io'; // สำหรับ Mobile/Desktop
import 'package:LumoRead/services/stt_service.dart';

// ✅ เปลี่ยนการ import path_provider
// import 'package:path_provider/path_provider.dart'; // ❌ ลบบรรทัดนี้

class SttDemoPage extends StatefulWidget {
  final String expectedText;

  const SttDemoPage({super.key, required this.expectedText});

  @override
  State<SttDemoPage> createState() => _SttDemoPageState();
}

class _SttDemoPageState extends State<SttDemoPage> {
  final AudioRecorder _recorder = AudioRecorder();
  final SttService _sttService = SttService();

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _audioPath;

  String _transcribedText = '';
  double _accuracy = 0.0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkServerHealth();
    
    // ✅ เช็คว่าเป็น Web หรือไม่
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'Web ยังไม่รองรับการบันทึกเสียง กรุณาใช้ Desktop หรือ Mobile';
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkServerHealth() async {
    try {
      final health = await _sttService.health();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ เชื่อมต่อ Server สำเร็จ!\nอุปกรณ์: ${health['device']}\nBeam: ${health['beam']}',
            style: GoogleFonts.mali(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ไม่สามารถเชื่อมต่อ Server\n\nError: $e',
            style: GoogleFonts.mali(fontSize: 12),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  /// ✅ แก้ไขเพื่อรองรับทั้ง Web และ Native
  Future<void> _startRecording() async {
    // ✅ ป้องกันการใช้งานบน Web
    if (kIsWeb) {
      _showError('Web ยังไม่รองรับการบันทึกเสียง กรุณาใช้ Desktop/Mobile');
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showError('กรุณาอนุญาตใช้ไมโครโฟน');
      return;
    }

    try {
      // ✅ ใช้ temporary path ที่ทำงานได้ทุกแพลตฟอร์ม
      final path = await _getRecordingPath();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _audioPath = null;
        _transcribedText = '';
        _accuracy = 0.0;
        _errorMessage = '';
      });
    } catch (e) {
      _showError('เริ่มบันทึกไม่สำเร็จ: $e');
    }
  }

  /// ✅ สร้าง path สำหรับบันทึกเสียง (รองรับทุก platform)
  Future<String> _getRecordingPath() async {
    if (kIsWeb) {
      throw UnsupportedError('Web does not support file recording');
    }

    // Desktop/Mobile: ใช้ Directory.systemTemp
    final tempDir = Directory.systemTemp;
    return '${tempDir.path}/test_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (path == null) {
        _showError('ไม่พบไฟล์เสียง');
        return;
      }

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });

      await _processAudio(path);
    } catch (e) {
      _showError('หยุดบันทึกไม่สำเร็จ: $e');
    }
  }

  Future<void> _processAudio(String path) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      final result = await _sttService.score(path, widget.expectedText);

      setState(() {
        _transcribedText = result['text'] ?? '';
        _accuracy = result['char_accuracy'] ?? 0.0;
        _isProcessing = false;
      });

      _showResultDialog();
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isProcessing = false;
      });
    }
  }

  void _showResultDialog() {
    final percent = (_accuracy * 100).toStringAsFixed(1);
    final emoji = _accuracy >= 0.9 ? '🎉' : _accuracy >= 0.7 ? '😊' : '💪';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'คะแนน: $percent% $emoji',
          style: GoogleFonts.mali(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ควรอ่าน: ${widget.expectedText}',
              style: GoogleFonts.mali(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'คุณอ่านว่า: $_transcribedText',
              style: GoogleFonts.mali(
                color: _accuracy >= 0.9 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(_getFeedback(_accuracy), style: GoogleFonts.mali()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ลองใหม่', style: GoogleFonts.mali()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('ตกลง', style: GoogleFonts.mali(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getFeedback(double accuracy) {
    if (accuracy >= 0.95) return '🌟 ยอดเยี่ยม! อ่านถูกต้องมาก';
    if (accuracy >= 0.85) return '👍 ดีมาก! อ่านได้ชัดเจน';
    if (accuracy >= 0.7) return '😊 ดีแล้ว แต่ยังพัฒนาได้';
    return '💪 ลองอีกครั้งนะ อ่านช้าๆ ชัดๆ';
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.mali()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ทดสอบการอ่านด้วย AI', style: GoogleFonts.mali()),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'ทดสอบการเชื่อมต่อใหม่',
            onPressed: _checkServerHealth,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ แสดงคำเตือนถ้าเป็น Web
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Web ยังไม่รองรับการบันทึกเสียง',
                      style: GoogleFonts.mali(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'กรุณาใช้ Desktop (Windows/Mac) หรือ Mobile',
                      style: GoogleFonts.mali(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'อ่านออกเสียง:',
                    style: GoogleFonts.mali(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.expectedText,
                    style: GoogleFonts.mali(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            if (_isProcessing)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'กำลังประมวลผลด้วย AI...\nอาจใช้เวลา 5-10 วินาที',
                    style: GoogleFonts.mali(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              Opacity(
                opacity: kIsWeb ? 0.3 : 1.0, // ✅ ทำให้เบาบน Web
                child: GestureDetector(
                  onTapDown: kIsWeb ? null : (_) => _startRecording(),
                  onTapUp: kIsWeb ? null : (_) => _stopRecording(),
                  onTapCancel: kIsWeb ? null : () => _stopRecording(),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : Colors.blue)
                              .withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Text(
              kIsWeb
                  ? 'ไม่รองรับบน Web'
                  : (_isRecording
                      ? 'กำลังบันทึก... (ปล่อยเมื่อพูดเสร็จ)'
                      : 'กดค้างเพื่อบันทึกเสียง'),
              style: GoogleFonts.mali(
                fontSize: 16,
                color: _isRecording ? Colors.red : Colors.grey,
                fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            const SizedBox(height: 40),

            if (_transcribedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'คะแนนครั้งล่าสุด: ${(_accuracy * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.mali(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'คุณอ่าน: $_transcribedText',
                      style: GoogleFonts.mali(fontSize: 14),
                    ),
                  ],
                ),
              ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.mali(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}