///ปจบ.ใช้หน้านี้
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ResultChartScreen extends StatefulWidget {
  @override
  _ResultChartScreenState createState() => _ResultChartScreenState();
}

class _ResultChartScreenState extends State<ResultChartScreen> {
  List<Map<String, dynamic>> alldata = [];
  Map<String, List<Map<String, dynamic>>> groups = {};

  String name = '';
  String cls = '';
  String pic = '';
  String search = '';

  var tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    setup();
    load();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  void setup() async {
    await tts.setLanguage("th-TH");
    await tts.setSpeechRate(0.4);
  }

  void load() async {
    var p = await SharedPreferences.getInstance();
    var user = p.getString("loggedInUsername") ?? p.getString("username");
    if (user == null) return;

    var udocs =
        await FirebaseFirestore.instance
            .collection("users")
            .where("username", isEqualTo: user)
            .limit(1)
            .get();

    if (udocs.docs.isNotEmpty) {
      var u = udocs.docs.first.data();
      name = "${u["first_name"] ?? ""} ${u["last_name"] ?? ""}";
      cls = "เลขที่ ${u["student_number"] ?? ""} ป.${u["class_level"] ?? ""}";
      pic = u["avatar_url"] ?? "";
    }

    var rdocs =
        await FirebaseFirestore.instance
            .collection("quiz_results")
            .where("username", isEqualTo: user)
            .orderBy("timestamp", descending: true)
            .get();

    alldata = rdocs.docs.map((d) => d.data()).toList();

    makegroups();
  }

  void makegroups() {
    Map<String, List<Map<String, dynamic>>> g = {};

    for (var r in alldata) {
      String cat = r['category'] ?? 'ไม่ระบุ';

      if (search.isNotEmpty) {
        if (!cat.toLowerCase().contains(search.toLowerCase())) {
          continue;
        }
      }

      if (!g.containsKey(cat)) {
        g[cat] = [];
      }
      g[cat]!.add(r);
    }

    setState(() {
      groups = g;
    });
  }

  String getdate(dynamic t) {
    DateTime d;

    if (t is Timestamp) {
      d = t.toDate();
    } else if (t is DateTime) {
      d = t;
    } else {
      return "";
    }

    var mon = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฏาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];

    var min = d.minute < 10 ? '0${d.minute}' : '${d.minute}';

    return "${d.day} ${mon[d.month - 1]} ${d.year + 543} เวลา ${d.hour}:$min น.";
  }

  void speak(String word) async {
    await tts.stop();
    await tts.speak(word);
  }

  // นับจำนวนครั้งที่ผิดแต่ละคำ
  Map<String, int> countwrong(List<dynamic> wronglist) {
    Map<String, int> count = {};

    for (var item in wronglist) {
      String correct = item['correct'] ?? item['word'] ?? '';
      if (correct.isNotEmpty) {
        count[correct] = (count[correct] ?? 0) + 1;
      }
    }

    return count;
  }

  // ดูคำผิด
  void showwrong(List<dynamic> wronglist) {
    showDialog(
      context: context,
      builder:
          (c) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 600,
              height: 600,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "คำที่ตอบผิด (${wronglist.length} คำ)",
                    style: GoogleFonts.mali(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(height: 30),
                  Expanded(
                    child: ListView.builder(
                      itemCount: wronglist.length,
                      itemBuilder: (c, i) {
                        var item = wronglist[i];

                        String qnum = "ข้อที่ ${item['index'] ?? i + 1}";
                        String ans = item['correct'] ?? item['word'] ?? '';
                        String myans =
                            item['recognized'] ??
                            item['answered'] ??
                            item['selected'] ??
                            item['selected_label'] ??
                            '';
                        String question = item['question'] ?? '';

                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  qnum,
                                  style: GoogleFonts.mali(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (question.isNotEmpty)
                                      Text(
                                        "$question",
                                        style: GoogleFonts.mali(
                                          fontSize: 14,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    Text(
                                      "❌ ตอบ: $myans",
                                      style: GoogleFonts.mali(fontSize: 16),
                                    ),
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "✅ ถูกต้อง: $ans",
                                            style: GoogleFonts.mali(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  color: Colors.indigo.shade300,
                                  size: 30,
                                ),
                                onPressed: () => speak(ans),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "ปิด",
                      style: GoogleFonts.mali(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ✅ ใหม่ — แสดงคำพูดทุกบรรทัดพร้อมชื่อเรื่อง
  void _showRecognizedLines(List recognizedLines, String title) {
    showDialog(
      context: context,
      builder:
          (c) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 650,
              height: 600,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '🎤 คำพูดของนักเรียน',
                    style: GoogleFonts.mali(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'เรื่อง: $title',
                        style: GoogleFonts.mali(
                          fontSize: 14,
                          color: Colors.indigo.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Divider(height: 25),
                  Expanded(
                    child: ListView.builder(
                      itemCount: recognizedLines.length,
                      itemBuilder: (c, i) {
                        var line = recognizedLines[i];
                        String correct = line['text'] ?? '';
                        String spoken = line['recognized'] ?? '';
                        int score = line['score'] ?? 0;

                        Color scoreColor =
                            score == 3
                                ? Colors.green
                                : score == 2
                                ? Colors.blue
                                : score == 1
                                ? Colors.orange
                                : Colors.red;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scoreColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // วงกลมหมายเลขบรรทัด + คะแนน
                              Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: scoreColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${line['number'] ?? i + 1}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '$score/3',
                                    style: GoogleFonts.mali(
                                      fontSize: 11,
                                      color: scoreColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ข้อความโจทย์
                                    Text(
                                      correct,
                                      style: GoogleFonts.mali(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    // คำพูดของนักเรียน
                                    if (spoken.isNotEmpty)
                                      Text(
                                        '💬 "$spoken"',
                                        style: GoogleFonts.mali(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else
                                      Text(
                                        '— ยังไม่ได้อ่านบรรทัดนี้',
                                        style: GoogleFonts.mali(
                                          fontSize: 13,
                                          color: Colors.grey.shade400,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // ปุ่ม TTS ฟังเสียงต้นฉบับ
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  color: Colors.indigo.shade300,
                                ),
                                onPressed: () => speak(correct),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'ปิด',
                      style: GoogleFonts.mali(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void showdetail(String cat, List<Map<String, dynamic>> list) {
    showDialog(
      context: context,
      builder:
          (c) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 700,
              height: 700,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    cat,
                    style: GoogleFonts.mali(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "ทำไปแล้ว ${list.length} ครั้ง",
                    style: GoogleFonts.mali(fontSize: 14, color: Colors.grey),
                  ),
                  Divider(height: 30),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        var orderedList = list.reversed.toList();
                        var r = orderedList[i];
                        int sc = r['score'] ?? 0;
                        int tot = r['total'] ?? 0;
                        String dt = getdate(r['timestamp']);
                        List wrongs = r['wrong_answers'] ?? [];

                        //  ดึง recognized_lines และ title
                        List recognizedLines = r['recognized_lines'] ?? [];
                        String articleTitle = r['title'] ?? '';
                        String articleSet = r['set']?.toString() ?? '';

                        String? fb = r['feedback']?.toString();
                        String? fbby = r['feedback_by']?.toString();

                        return Card(
                          margin: EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade100,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        "ครั้งที่ ${i + 1}",
                                        style: GoogleFonts.mali(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            sc == tot
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        "$sc/$tot คะแนน",
                                        style: GoogleFonts.mali(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              sc == tot
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),

                                // แสดงชื่อเรื่องที่อ่าน
                                if (articleTitle.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.menu_book,
                                        size: 15,
                                        color: Colors.indigo.shade300,
                                      ),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'เรื่อง: $articleTitle',
                                          style: GoogleFonts.mali(
                                            fontSize: 13,
                                            color: Colors.indigo.shade400,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (articleSet.isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        'ชุดที่: $articleSet',
                                        style: GoogleFonts.mali(
                                          fontSize: 13,
                                          color: Colors.blueGrey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),

                                SizedBox(height: 6),
                                Text(
                                  dt,
                                  style: GoogleFonts.mali(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                if (fb != null && fb.isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates,
                                              color: Colors.amber.shade300,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              "คำแนะนำ",
                                              style: GoogleFonts.mali(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                            if (fbby != null &&
                                                fbby.isNotEmpty) ...[
                                              SizedBox(width: 5),
                                              Text(
                                                "โดย คุณครู$fbby",
                                                style: GoogleFonts.mali(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          fb,
                                          style: GoogleFonts.mali(
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                SizedBox(height: 10),

                                // ปุ่ม  คำพูดทั้งหมด
                                Row(
                                  children: [
                                    // ปุ่มคำที่ผิด
                                    if (wrongs.isNotEmpty)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            showwrong(wrongs);
                                          },
                                          icon: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.red.shade700,
                                          ),
                                          label: Text(
                                            'คำที่ผิด (${wrongs.length})',
                                            style: GoogleFonts.mali(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade50,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (wrongs.isNotEmpty &&
                                        recognizedLines.isNotEmpty)
                                      SizedBox(width: 8),

                                    // ปุ่มดูคำพูดทั้งหมด
                                    if (recognizedLines.isNotEmpty)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showRecognizedLines(
                                              recognizedLines,
                                              articleTitle,
                                            );
                                          },
                                          icon: Icon(
                                            Icons.record_voice_over,
                                            size: 16,
                                            color: Colors.indigo.shade700,
                                          ),
                                          label: Text(
                                            'คำพูดทั้งหมด',
                                            style: GoogleFonts.mali(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo.shade700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.indigo.shade50,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "ปิด",
                      style: GoogleFonts.mali(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        title: Text(
          "ประวัติคะแนน",
          style: GoogleFonts.mali(color: Colors.white, fontSize: 20),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Card โปรไฟล์นักเรียน
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        pic.isNotEmpty
                            ? (pic.startsWith('http')
                                ? NetworkImage(pic)
                                : AssetImage(pic) as ImageProvider)
                            : null,
                    child: pic.isEmpty ? Icon(Icons.person, size: 40) : null,
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.mali(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cls,
                        style: GoogleFonts.mali(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Search bar (แสดงเมื่อมีข้อมูล > 5 รายการ)
            if (alldata.length > 5)
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: TextField(
                  style: GoogleFonts.mali(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา เช่น แม่กด',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (t) {
                    search = t;
                    makegroups();
                  },
                ),
              ),

            // รายการประวัติแยกตามหมวด
            Expanded(
              child:
                  groups.isEmpty
                      ? Center(
                        child: Text(
                          "ยังไม่มีข้อมูล",
                          style: GoogleFonts.mali(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: groups.keys.length,
                        itemBuilder: (c, i) {
                          String cat = groups.keys.elementAt(i);
                          List<Map<String, dynamic>> items = groups[cat]!;

                          String latestTitle = items.first['title'] ?? '';
                          String latestSet =
                              items.first['set']?.toString() ?? '';
                          return Card(
                            margin: EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              onTap: () => showdetail(cat, items),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade200,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        color: Colors.purple.shade50,
                                        size: 35,
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat,
                                            style: GoogleFonts.mali(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.pink.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            "ทำแล้ว ${items.length} ครั้ง ${latestSet.isNotEmpty ? 'ชุดที่: $latestSet' : ''}",
                                            style: GoogleFonts.mali(
                                              fontSize: 15,
                                              color: Colors.indigo.shade300,
                                            ),
                                          ),
                                          //  แสดงชื่อเรื่องล่าสุด
                                          if (latestTitle.isNotEmpty) ...[
                                            SizedBox(height: 3),
                                            Text(
                                              'เรื่อง: $latestTitle',
                                              style: GoogleFonts.mali(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.pink.shade300,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
