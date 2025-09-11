import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = "http://127.0.0.1:8000";

  // Upload video
  Future<String?> uploadVideo(File videoFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/upload-video/"),
    );
    request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);
      return jsonResponse["file_path"]; // returns uploaded path
    } else {
      return null;
    }
  }

  // Get highlights
  Future<List<dynamic>> getHighlights(String filename) async {
    var response = await http.get(Uri.parse("$baseUrl/highlights/$filename"));
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      return jsonResponse["highlights"];
    } else {
      return [];
    }
  }
}
