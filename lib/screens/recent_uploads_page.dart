import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecentUploadsPage extends StatefulWidget {
  const RecentUploadsPage({super.key});

  @override
  State<RecentUploadsPage> createState() => _RecentUploadsPageState();
}

class _RecentUploadsPageState extends State<RecentUploadsPage> {
  bool loading = true;
  List<Map<String, dynamic>> uploads = [];

  // Change this if backend is local
  final String backendUrl = "https://relive-backend-xvfs.onrender.com";

  @override
  void initState() {
    super.initState();
    fetchUploads();
  }

  Future<void> fetchUploads() async {
    setState(() => loading = true);
    try {
      final response = await http.get(Uri.parse("$backendUrl/list-uploads/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Sort uploads by created_at (most recent first)
        final List uploadsData = data["uploads"] ?? [];
        uploadsData.sort((a, b) {
          final dateA = DateTime.tryParse(a["created_at"] ?? "") ?? DateTime(2000);
          final dateB = DateTime.tryParse(b["created_at"] ?? "") ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        setState(() {
          uploads = uploadsData.map<Map<String, dynamic>>((u) {
            return {
              "url": u["url"],
              "public_id": u["public_id"],
              "created_at": u["created_at"] ?? "",
            };
          }).toList();
        });
      } else {
        throw Exception("Failed to fetch uploads: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error fetching: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> deleteVideo(String publicId) async {
    try {
      final response = await http.delete(
        Uri.parse("$backendUrl/delete-upload/?public_id=$publicId"),
      );
      if (response.statusCode == 200) {
        setState(() {
          uploads.removeWhere((u) => u["public_id"] == publicId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Deleted successfully")),
        );
      } else {
        throw Exception("Delete failed: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error deleting video: $e")),
      );
    }
  }

  void openVideoPlayer(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(videoUrl: videoUrl),
      ),
    );
  }

  String getThumbnailUrl(String videoUrl) {
    return videoUrl.replaceFirst(
      '/video/upload/',
      '/video/upload/c_thumb,g_auto,w_400/',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Uploads"),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        foregroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUploads,
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : uploads.isEmpty
            ? const Center(
          child: Text(
            "No recent uploads yet",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        )
            : GridView.builder(
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 16 / 9,
          ),
          itemCount: uploads.length,
          itemBuilder: (context, index) {
            final upload = uploads[index];
            final videoUrl = upload["url"];
            final publicId = upload["public_id"];
            final createdAt = upload["created_at"];
            final thumbUrl = getThumbnailUrl(videoUrl);

            return Dismissible(
              key: Key(publicId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => deleteVideo(publicId),
              child: GestureDetector(
                onTap: () => openVideoPlayer(videoUrl),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Icon(Icons.error,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.play_circle,
                            color: Colors.white70,
                            size: 50,
                          ),
                        ),
                        // 🕒 Overlay upload time
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDate(createdAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 🕒 Date formatting helper
  String _formatDate(String createdAt) {
    if (createdAt.isEmpty) return "";
    try {
      final date = DateTime.parse(createdAt).toLocal();
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "";
    }
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
    );
  }
}
