// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';

// class SttService {
//   final String baseUrl;
//   SttService({String? base})
//       : baseUrl = base ??
//           (Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000');

//   Future<String> transcribe(String path) async {
//     final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/stt'))
//       ..files.add(await http.MultipartFile.fromPath(
//         'audio', path, contentType: MediaType('audio', 'wav'),
//       ));
//     final res = await http.Response.fromStream(await req.send());
//     if (res.statusCode != 200) throw Exception(res.body);
//     return RegExp(r'"text"\s*:\s*"([^"]*)"', dotAll: true)
//             .firstMatch(res.body)
//             ?.group(1) ?? '';
//   }

//   Future<Map<String, dynamic>> score(String path, String expected) async {
//     final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/stt-score'))
//       ..fields['expected_text'] = expected
//       ..files.add(await http.MultipartFile.fromPath(
//         'audio', path, contentType: MediaType('audio', 'wav'),
//       ));
//     final res = await http.Response.fromStream(await req.send());
//     if (res.statusCode != 200) throw Exception(res.body);
//     return {
//       'text': RegExp(r'"text"\s*:\s*"([^"]*)"', dotAll: true).firstMatch(res.body)?.group(1) ?? '',
//       'char_accuracy': double.parse(RegExp(r'"char_accuracy"\s*:\s*([0-9.]+)').firstMatch(res.body)!.group(1)!),
//     };
//   }
// }
