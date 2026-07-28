import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingArticleP3 extends StatefulWidget {
  const ReadingArticleP3({super.key});
  @override
  State<ReadingArticleP3> createState() => _ReadingArticleP3State();
}

class _ReadingArticleP3State extends State<ReadingArticleP3> {
  // ---------- เนื้อหาบทความ (5–6 บรรทัด) ----------
  final List<String> lines = const [
    'ความจริงใจคือการแสดงความคิดเห็นหรือความรู้สึกออกมาอย่างซื่อสัตย์ไม่เสแสร้ง',
    'ความซื่อสัตย์คือการพูดแสดงความประสงค์ว่าจะไม่พูดเท็จหรือโกหก ถือเป็นความบริสุทธิ์ใจ',
    'คนเรามักจะพูดโกหกหลอกลวงเสแสร้งจนกลายเป็นนิสัย ความจริงใจช่วยลดโอกาสในการทำผิดพลาด',
    'มีคนกล่าวว่า ความผิดพลาดแอบอยู่ข้าง ๆ ความจริง จึงทำให้เราตกหลุมพรางบ่อย ๆ',
    'ความหมายคือ ความรู้แจ้งเห็นจริงเท่านั้นที่แยกแยะระหว่างความผิดพลาดกับความจริงได้',
    'ดังนั้นเราต้องมีความจริงใจ ซื่อสัตย์ และเชื่อถือได้ เพื่ออยู่ร่วมกับผู้อื่นอย่างมีความสุข',
  ];

  // ---------- เกณฑ์/พารามิเตอร์ ----------
  static const int maxAttemptsPerLine = 3;
  static const double cerGreat = 0.10; // ดีมาก
  static const double cerPass  = 0.25; // ผ่าน
  static const double cerRetry = 0.35; // ให้ลองใหม่
  static const Duration listenFor = Duration(seconds: 20); // เวลาสูงสุดต่อบรรทัด
  static const Duration pauseFor = Duration(seconds: 5);   // เงียบ ≥ 5s → OS ตัดเอง
  static const Duration silenceCut = Duration(seconds: 5); // สำรอง: เราตัดเองเมื่อเงียบ 5s
  static const double dbSilenceThresh = -45.0; // dB (ยิ่งติดลบมากยิ่งเงียบ) ปรับได้ -50..-40

  // ---------- สถานะ ----------
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;

  int _lineIndex = 0;
  int _attempt = 1;
  String _hypText = '';

  final List<double> _cerPerLine = [];
  final List<Map<String, dynamic>> _wrongs = [];

  DateTime? _startedAt;
  int _attemptsTotal = 0;

  DateTime _lastSoundAt = DateTime.now();
  Timer? _silenceWatch; // timer เช็คความเงียบ

  @override
  void initState() {
    super.initState();
    _initSTT();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _silenceWatch?.cancel();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSTT() async {
    _available = await _speech.initialize(
      onStatus: (s) => debugPrint('STT status: $s'),
      onError: (e) => debugPrint('STT error: $e'),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListen() async {
    if (!_available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถใช้การรู้จำเสียงได้')),
      );
      return;
    }
    _attemptsTotal += 1;         // นับจำนวนครั้งพยายามรวม
    _hypText = '';
    _lastSoundAt = DateTime.now();

    setState(() => _listening = true);

    // เริ่มจับเวลา "ความเงียบ 5s" ด้วยตัวเอง (สำรอง)
    _silenceWatch?.cancel();
    _silenceWatch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_listening) {
        final gap = DateTime.now().difference(_lastSoundAt);
        if (gap >= silenceCut) {
          _stopAndEvaluate();
        }
      }
    });

    await _speech.listen(
      localeId: 'th_TH',
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      listenFor: listenFor,
      pauseFor: pauseFor, // เงียบ ≥5s → เอนจินอาจหยุดเอง (แล้ว onResult.finalResult = true)
      onSoundLevelChange: (level) {
        // level ประมาณระดับ dB: ถ้ามากกว่า threshold แปลว่า "มีเสียง"
        if (level > dbSilenceThresh) {
          _lastSoundAt = DateTime.now();
        }
      },
      onResult: (res) {
        _hypText = res.recognizedWords;
        if (res.finalResult) {
          _stopAndEvaluate();
        }
        setState(() {});
      },
    );
  }

  Future<void> _stopAndEvaluate() async {
    if (!_listening) return;
    await _speech.stop();
    _silenceWatch?.cancel();
    setState(() => _listening = false);

    final ref = lines[_lineIndex];
    final bool ignoreDiacritics = (_attempt >= 3); // ครั้งที่ 3 ผ่อนปรน
    final score = _cer(ref, _hypText, ignoreDiacritics: ignoreDiacritics);

    String status;
    if (score <= cerGreat) {
      status = 'great';
    } else if (score <= cerPass) {
      status = 'pass';
    } else if (score <= cerRetry) {
      status = 'retry';
    } else {
      status = 'fail';
    }

    if (status == 'great' || status == 'pass') {
      _cerPerLine.add(score);
      _nextLine();
    } else if (status == 'retry' && _attempt < maxAttemptsPerLine) {
      setState(() => _attempt += 1);
      _startListen(); // ให้เริ่มลองใหม่ทันที (หรือจะให้เด็กกดเองก็ได้)
    } else {
      _cerPerLine.add(score);
      _wrongs.add({
        'line': _lineIndex + 1,
        'ref': ref,
        'hyp': _hypText,
        'cer': double.parse(score.toStringAsFixed(4)),
        'mode': ignoreDiacritics ? 'relaxed' : 'strict',
        'attempt': _attempt,
      });
      _nextLine();
    }
  }

  void _nextLine() {
    if (_lineIndex < lines.length - 1) {
      setState(() {
        _lineIndex += 1;
        _attempt = 1;
        _hypText = '';
        _lastSoundAt = DateTime.now();
      });
    } else {
      _finishAll();
    }
  }

  void _finishAll() async {
    final total = lines.length;
    final passed = _cerPerLine.where((c) => c <= cerPass).length;
    final avgCER = _cerPerLine.isEmpty
        ? 1.0
        : _cerPerLine.reduce((a, b) => a + b) / _cerPerLine.length;
    final overallPass = passed >= (total * 0.8).ceil() && avgCER <= 0.20;

    final durationSec = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    // ---- บันทึกลง Firestore: quiz_results ----
    await _saveQuizResult(
      category: 'reading_article_p3',
      articleId: 'p3_article_001',
      score: passed,
      total: total,
      avgCer: avgCER,
      cerPerLine: _cerPerLine,
      wrongLines: _wrongs,
      passed: overallPass,
      attemptsTotal: _attemptsTotal,
      durationSec: durationSec,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(overallPass ? 'ผ่านบทความ 🎉' : 'ยังไม่ผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผ่านบรรทัด: $passed / $total'),
            Text('CER เฉลี่ย: ${avgCER.toStringAsFixed(3)}'),
            const SizedBox(height: 8),
            if (_wrongs.isNotEmpty) const Text('บรรทัดที่พลาด:'),
            for (final w in _wrongs)
              Text('บรรทัด ${w['line']}: CER=${(w['cer'] as double).toStringAsFixed(3)}'
                   ' (${w['mode']}, attempt ${w['attempt']})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                // รีเซ็ตเพื่อเริ่มใหม่
                _lineIndex = 0;
                _attempt = 1;
                _hypText = '';
                _cerPerLine.clear();
                _wrongs.clear();
                _attemptsTotal = 0;
                _startedAt = DateTime.now();
              });
            },
            child: const Text('เริ่มใหม่'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        ],
      ),
    );
  }

  // ---------- Firestore helpers ----------
  Future<String?> _fetchFullNameByUsername(String username) async {
    // ปรับให้ตรงโครงสร้างของพี่: ถ้า users ใช้ docId เป็น username ก็อ่าน doc ตรง ๆ ได้
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final data = q.docs.first.data();
    return (data['full_name'] ?? data['name'] ?? '') as String;
  }

  Future<void> _saveQuizResult({
    required String category,
    required int score,
    required int total,
    required double avgCer,
    required List<double> cerPerLine,
    required List<Map<String, dynamic>> wrongLines,
    String? articleId,
    bool? passed,
    int? attemptsTotal,
    int? durationSec,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'unknown_user';
    final fullName = await _fetchFullNameByUsername(username) ?? '';

    await FirebaseFirestore.instance.collection('quiz_results').add({
      'username'      : username,
      'full_name'     : fullName,
      'category'      : category,
      'article_id'    : articleId ?? '',
      'score'         : score,
      'total'         : total,
      'avg_cer'       : double.parse(avgCer.toStringAsFixed(4)),
      'cer_per_line'  : cerPerLine.map((e) => double.parse(e.toStringAsFixed(4))).toList(),
      'wrong_lines'   : wrongLines,
      'passed'        : passed ?? (score >= (total * 0.8).ceil() && avgCer <= 0.20),
      'attempts_total': attemptsTotal ?? 0,
      'duration_sec'  : durationSec ?? 0,
      'timestamp'     : FieldValue.serverTimestamp(),
    });
  }

  String _normalizeThai(String s, {bool stripDiacritics = false}) {
    final punct = RegExp(r'''[“”"'()–—.,!?…:;•-]''');
    final diacritics = RegExp(r'[\u0E31\u0E34-\u0E3A\u0E47-\u0E4E]');
    var x = s.replaceAll(punct, ' ')
             .replaceAll(RegExp(r'\s+'), ' ')
             .trim()
             .replaceAll(' ', ''); // เทียบระดับตัวอักษร
    if (stripDiacritics) {
      x = x.replaceAll(diacritics, '');
    }
    return x;
  }

  double _cer(String ref, String hyp, {bool ignoreDiacritics = false}) {
    final r = _normalizeThai(ref, stripDiacritics: ignoreDiacritics);
    final h = _normalizeThai(hyp, stripDiacritics: ignoreDiacritics);
    if (r.isEmpty) return 1.0;
    final dist = _levenshtein(r, h);
    return dist / r.length.clamp(1, 1 << 30);
  }

  int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    if (m == 0) return n;
    if (n == 0) return m;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        final a = dp[i - 1][j] + 1;           // delete
        final b = dp[i][j - 1] + 1;           // insert
        final c = dp[i - 1][j - 1] + cost;    // substitute
        dp[i][j] = a < b ? (a < c ? a : c) : (b < c ? b : c);
      }
    }
    return dp[m][n];
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final refLine = lines[_lineIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('ฝึกอ่านบทความ ป.3')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บรรทัดที่ ${_lineIndex + 1}/${lines.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(refLine, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text('พยายาม: $_attempt / $maxAttemptsPerLine'),
            const SizedBox(height: 8),
            Text('ได้ยินว่า: ${_hypText.isEmpty ? "(ยังไม่มี)" : _hypText}'),
            const Spacer(),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _listening ? null : () {
                    _attempt = 1; // เริ่มรอบใหม่ของบรรทัดนี้
                    _startListen();
                  },
                  child: const Text('เริ่มฟัง'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _listening
                      ? () {
                          _attempt = _attempt; // คง attempt เดิม
                          _stopAndEvaluate();
                        }
                      : null,
                  child: const Text('ประเมินทันที'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
 