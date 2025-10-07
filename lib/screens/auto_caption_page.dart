import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AutoCaptionPage extends StatefulWidget {
  const AutoCaptionPage({super.key});

  @override
  State<AutoCaptionPage> createState() => _AutoCaptionPageState();
}

class _AutoCaptionPageState extends State<AutoCaptionPage> {
  XFile? _video;

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _video = video;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auto-Captioning"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8E24AA), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.subtitles, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text("Upload Video for Captioning"),
                ),
                const SizedBox(height: 20),
                if (_video != null)
                  Column(
                    children: [
                      const Text(
                        "Preview:",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _video!.name,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
                const Text(
                  "Soon this will generate captions automatically using AI Speech-to-Text.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
