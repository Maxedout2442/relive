import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'package:video_player/video_player.dart';

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

      String? filePath = await api.uploadVideo(file);

      if (filePath != null) {
        String filename = filePath.split("/").last;
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
                final clip = highlights[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: VideoPlayerWidget(url: clip['url']),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          clip['transcript'] ?? "No transcript",
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _controller.value.isInitialized
            ? VideoPlayer(_controller)
            : const Center(child: CircularProgressIndicator()),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 40,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
        )
      ],
    );
  }
}
