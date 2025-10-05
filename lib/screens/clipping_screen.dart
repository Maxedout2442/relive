import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClippingScreen extends StatefulWidget {
  const ClippingScreen({super.key});

  @override
  State<ClippingScreen> createState() => _ClippingScreenState();
}

class _ClippingScreenState extends State<ClippingScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> uploads = [];
  bool loading = true;
  bool processing = false;
  double progress = 0.0;
  String statusMessage = "";
  List<dynamic> highlights = [];

  // Local backend for testing — change if deployed
  final String backendUrl = "http://192.168.0.165:8000";

  @override
  void initState() {
    super.initState();
    fetchUploads();
  }

  Future<void> fetchUploads() async {
    setState(() => loading = true);

    try {
      // 🔹 Fetch from your FastAPI backend / Cloudinary
      final response = await http.get(Uri.parse("$backendUrl/list-uploads/"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List uploadsList = data["uploads"] ?? [];

        setState(() {
          uploads = uploadsList.map<Map<String, dynamic>>((item) {
            return {
              "url": item["url"] ?? "",
              "id": item["public_id"] ?? "",
            };
          }).toList();
        });
      } else {
        throw Exception("Failed to load videos (Code ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("⚠️ Error loading Cloudinary uploads: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading videos: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }


  Future<void> processVideo(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Invalid video URL")),
      );
      return;
    }

    setState(() {
      processing = true;
      progress = 0.0;
      statusMessage = "Starting AI Clipping...";
      highlights = [];
    });

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/process-video"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"video_url": videoUrl}),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to start processing (code ${response.statusCode})");
      }

      final taskId = jsonDecode(response.body)["task_id"];

      bool done = false;
      while (!done) {
        final statusResp = await http.get(Uri.parse("$backendUrl/status/$taskId"));
        if (statusResp.statusCode != 200) break;

        final statusData = jsonDecode(statusResp.body);
        setState(() {
          statusMessage = statusData["status"] ?? "Processing...";
          progress = (statusData["progress"] ?? 0) / 100;
        });

        if ((statusData["progress"] ?? 0) >= 100) {
          done = true;
          highlights = statusData["highlights"] ?? [];
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() {
        processing = false;
      });
    }
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
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Select one of your uploaded videos to generate highlights",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ✅ If no uploads, show message
            SizedBox(
              height: 130,
              child: uploads.isEmpty
                  ? const Center(
                child: Text(
                  "No uploaded videos found.",
                  style: TextStyle(
                      color: Colors.black54, fontSize: 16),
                ),
              )
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: uploads.length,
                itemBuilder: (context, index) {
                  final video = uploads[index];
                  final videoUrl = video["url"] ?? "";
                  final thumbnailUrl = videoUrl.replaceFirst(
                    '/video/upload/',
                    '/video/upload/c_thumb,g_auto,w_300/',
                  );

                  return GestureDetector(
                    onTap: () => processVideo(videoUrl),
                    child: Container(
                      margin:
                      const EdgeInsets.symmetric(horizontal: 8),
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black12,
                        image: videoUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            if (processing) ...[
              LinearProgressIndicator(
                value: progress,
                color: Colors.deepPurpleAccent,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 10),
              Text(statusMessage,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.black54)),
            ],

            const SizedBox(height: 20),

            const Text(
              "Detected Clips",
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 🔹 Show clips (if generated)
            Expanded(
              child: highlights.isEmpty
                  ? const Center(child: Text("No clips yet."))
                  : ListView.builder(
                itemCount: highlights.length,
                itemBuilder: (context, index) {
                  final clip = highlights[index];
                  return ClipCard(
                    clipUrl: clip["url"],
                    index: index + 1,
                    transcript: clip["transcript"] ?? "",
                    onOpenFull: () =>
                        openVideoPlayer(clip["url"]),
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

class ClipCard extends StatefulWidget {
  final String clipUrl;
  final int index;
  final String transcript;
  final VoidCallback onOpenFull;

  const ClipCard({
    super.key,
    required this.clipUrl,
    required this.index,
    required this.transcript,
    required this.onOpenFull,
  });

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.clipUrl)
      ..initialize().then((_) {
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Clip ${widget.index}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.fullscreen,
                      color: Colors.deepPurpleAccent),
                  onPressed: widget.onOpenFull,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _initialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  IconButton(
                    iconSize: 50,
                    color: Colors.white70,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                ],
              ),
            )
                : const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            Text(
              widget.transcript.isEmpty
                  ? "No transcript available"
                  : "🗣 ${widget.transcript}",
              style:
              const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
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
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      })
      ..setLooping(true);
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Video Player"),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
        ),
      ),
    );
  }
}
