import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClippingScreen extends StatefulWidget {
  const ClippingScreen({super.key});

  @override
  State<ClippingScreen> createState() => _ClippingScreenState();
}

class _ClippingScreenState extends State<ClippingScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool loading = true;
  List<Map<String, dynamic>> uploads = [];

  @override
  void initState() {
    super.initState();
    fetchUploads();
  }

  Future<void> fetchUploads() async {
    setState(() => loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('uploads')
          .orderBy('uploadedAt', descending: true)
          .get();

      uploads = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'title': data['title'] ?? 'Untitled',
          'videoUrl': data['videoUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint("⚠️ Error fetching uploads: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading videos: $e")),
      );
    }

    setState(() => loading = false);
  }

  void openVideoPlayer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Clipping 🎬"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchUploads),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : uploads.isEmpty
          ? const Center(child: Text("No uploads yet."))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: uploads.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final video = uploads[index];
            final videoUrl = video['videoUrl'] ?? '';
            final thumb = videoUrl.replaceFirst(
              '/upload/',
              '/upload/c_fill,w_400,h_300,g_auto/',
            );

            return GestureDetector(
              onTap: () => openVideoPlayer(videoUrl),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  image: DecorationImage(
                    image: NetworkImage(thumb),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black54,
                        child: Text(
                          video['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 50),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerPage({super.key, required this.videoUrl});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Player")),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        }),
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
