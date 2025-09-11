import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:file_picker/file_picker.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final ApiService api = ApiService();
  List<dynamic> highlights = [];

  Future<void> pickAndUploadVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      File file = File(result.files.single.path!);

      // Upload video to FastAPI
      String? filePath = await api.uploadVideo(file);

      if (filePath != null) {
        String filename = filePath.split("/").last; // extract filename
        List<dynamic> data = await api.getHighlights(filename);

        setState(() {
          highlights = data;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Highlights")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: pickAndUploadVideo,
            child: const Text("Upload Video & Get Highlights"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: highlights.length,
              itemBuilder: (context, index) {
                final scene = highlights[index];
                return ListTile(
                  title: Text("Scene ${scene['scene']}"),
                  subtitle: Text("Start: ${scene['start']} - End: ${scene['end']}"),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
