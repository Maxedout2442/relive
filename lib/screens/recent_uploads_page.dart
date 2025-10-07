import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class RecentUploadsPage extends StatefulWidget {
  const RecentUploadsPage({super.key});

  @override
  State<RecentUploadsPage> createState() => _RecentUploadsPageState();
}

class _RecentUploadsPageState extends State<RecentUploadsPage> {
  late Future<List<Map<String, dynamic>>> _uploadsFuture;

  @override
  void initState() {
    super.initState();
    _uploadsFuture = fetchUploads();
  }

  /// 🔹 Fetch uploads from Firestore (latest first)
  Future<List<Map<String, dynamic>>> fetchUploads() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('uploads')
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['title'] ?? 'Untitled',
        'videoUrl': data['videoUrl'] ?? '',
        'uploadedAt': data['uploadedAt'],
      };
    }).toList();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

  void openVideoPlayer(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(videoUrl: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Uploads 📂"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _uploadsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final uploads = snapshot.data ?? [];
            if (uploads.isEmpty) {
              return const Center(
                child: Text(
                  "No uploads yet.",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uploads.length,
              itemBuilder: (context, index) {
                final upload = uploads[index];
                final videoUrl = upload['videoUrl'] ?? '';
                final thumb = videoUrl.replaceFirst(
                  '/upload/',
                  '/upload/c_fill,w_500,h_300,g_auto/',
                );

                return GestureDetector(
                  onTap: () => openVideoPlayer(videoUrl, upload['title']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(3, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🖼 Thumbnail
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(thumb),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white70,
                                size: 60,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  upload['title'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Uploaded: ${formatTimestamp(upload['uploadedAt'])}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
  });

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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
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
        backgroundColor: Colors.deepPurpleAccent,
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
