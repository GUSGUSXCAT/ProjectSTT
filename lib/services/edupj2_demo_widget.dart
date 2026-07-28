// lib/services/edupj2_demo_widget.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:LumoRead/services/edupj2_api.dart';

class Edupj2DemoPage extends StatefulWidget {
  final String? expectedText;
  final String? serverUrl;

  const Edupj2DemoPage({
    super.key,
    this.expectedText,
    this.serverUrl,
  });

  @override
  State<Edupj2DemoPage> createState() => _Edupj2DemoPageState();
}

class _Edupj2DemoPageState extends State<Edupj2DemoPage> {
  final AudioRecorder _recorder = AudioRecorder();
  late final Edupj2Api _edupj2;

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordingPath;

  String _transcribedText = '';
  double _accuracy = 0.0;
  String _errorMessage = '';
  bool _serverHealthy = false;

  @override
  void initState() {
    super.initState();
    _edupj2 = Edupj2Api(
      // 👇 เปลี่ยนแค่ตรงนี้ให้ตรง IP/พอร์ต ของ server พี่
      baseUrl: widget.serverUrl ?? 'http://192.168.0.104:5000',
    );
    _checkServerHealth();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkServerHealth() async {
    try {
      final health = await _edupj2.checkHealth();

      if (!mounted) return;

      setState(() {
        _serverHealthy = true;
        _errorMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ เชื่อมต่อ EDUPJ2 Server สำเร็จ!\n'
            'Model: ${health['model']}\n'
            'Device: ${health['device']}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _serverHealthy = false;
        _errorMessage = 'ไม่สามารถเชื่อมต่อ server: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ไม่สามารถเชื่อมต่อ EDUPJ2 Server\n$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showError('กรุณาอนุญาตไมโครโฟน');
        return;
      }

      // ใช้โฟลเดอร์ชั่วคราวของแอป
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _transcribedText = '';
        _accuracy = 0.0;
        _errorMessage = '';
      });
    } catch (e) {
      _showError('ไม่สามารถเริ่มบันทึกเสียงได้: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null && File(path).existsSync()) {
        await _processAudio(path);
      } else {
        _showError('ไม่พบบันทึกเสียง');
      }
    } catch (e) {
      _showError('ไม่สามารถหยุดบันทึกเสียงได้: $e');
    }
  }

  Future<void> _processAudio(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      // ถ้ามี expectedText ให้ไป /transcribe-score
      if (widget.expectedText != null &&
          widget.expectedText!.trim().isNotEmpty) {
        final result = await _edupj2.transcribeAndScoreFile(
          audioPath,
          widget.expectedText!.trim(),
        );

        setState(() {
          _transcribedText = result['text'] ?? '';
          _accuracy = _edupj2.getAccuracyPercent(result);
          _isProcessing = false;
        });

        _showSuccess('แปลงเสียงสำเร็จ!');
      } else {
        // ไม่ได้ส่ง expected  ไป /transcribe ปกติ
        final text = await _edupj2.transcribeFile(audioPath);
        setState(() {
          _transcribedText = text;
          _isProcessing = false;
        });
        _showSuccess('แปลงเสียงสำเร็จ!');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
      });
      _showError('ไม่สามารถแปลงเสียงได้: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDUPJ2 Speech-to-Text'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _serverHealthy ? Icons.check_circle : Icons.error,
              color: _serverHealthy ? Colors.green : Colors.red,
            ),
            onPressed: _checkServerHealth,
            tooltip: _serverHealthy ? 'Server: OK' : 'Server: Error',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.expectedText != null &&
                  widget.expectedText!.trim().isNotEmpty) ...[
                const Text(
                  'ข้อความที่ต้องการให้พูด:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    widget.expectedText!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
              ],

              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 100,
                color: _isRecording ? Colors.red : Colors.blue,
              ),
              const SizedBox(height: 20),

              Text(
                _isRecording
                    ? 'กำลังบันทึกเสียง...'
                    : _isProcessing
                        ? 'กำลังประมวลผล...'
                        : 'กดปุ่มเพื่อเริ่มบันทึกเสียง',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : (_isRecording ? _stopRecording : _startRecording),
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(
                  _isRecording ? 'หยุดบันทึก' : 'เริ่มบันทึกเสียง',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              if (_isProcessing) const Center(child: CircularProgressIndicator()),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],

              if (_transcribedText.isNotEmpty) ...[
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ผลลัพธ์:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _transcribedText,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (widget.expectedText != null &&
                          widget.expectedText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 15),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'ความแม่นยำ: ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_accuracy.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _accuracy >= 80
                                    ? Colors.green
                                    : _accuracy >= 60
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
