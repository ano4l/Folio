import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/document.dart';
import '../models/seed_data.dart';

class ApiService {
  static const String _base = 'http://10.0.2.2:8080/api';

  static Future<List<Document>> fetchDocuments() async {
    try {
      final res = await http.get(Uri.parse('$_base/documents')).timeout(
            const Duration(seconds: 5),
          );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) return data.map((d) => Document.fromJson(d)).toList();
      }
    } catch (_) {}
    return seedDocuments;
  }

  static Future<Map<String, dynamic>> uploadDocument(
      String filePath, String title, String type) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_base/documents'));
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
      req.fields['title'] = title;
      req.fields['type'] = type;
      final res = await req.send().timeout(const Duration(seconds: 30));
      final body = await res.stream.bytesToString();
      return jsonDecode(body);
    } catch (e) {
      return {'status': 'queued', 'filename': filePath.split('/').last};
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
