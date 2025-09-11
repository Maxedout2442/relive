import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ResultsScreen extends StatefulWidget {
  final String videoUrl;
  final List<dynamic> highlights;

  const ResultsScreen({
    Key? key,
    required this.videoUrl,
    required this.highlights,
  }) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seekTo(Duration position) {
    if (_isInitialized) {
      _controller.seekTo(position);
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Results")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Video Results",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 🔹 Video Player
            if (_isInitialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    Align(
                      alignment: Alignment.center,
                      child: IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 50,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),

            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Detected Highlights",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),

            // 🔹 Highlights List
            Expanded(
              child: widget.highlights.isEmpty
                  ? const Center(child: Text("No highlights detected."))
                  : ListView.builder(
                itemCount: widget.highlights.length,
                itemBuilder: (context, index) {
                  final scene = widget.highlights[index];
                  final sceneLabel =
                      scene['scene']?.toString() ?? (index + 1).toString();
                  final startSeconds =
                      double.tryParse(scene['start'].toString()) ?? 0.0;
                  final endSeconds =
                      double.tryParse(scene['end'].toString()) ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text("Scene $sceneLabel"),
                      subtitle: Text(
                          "Start: $startSeconds sec\nEnd: $endSeconds sec"),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          _seekTo(Duration(seconds: startSeconds.toInt()));
                        },
                      ),
                    ),
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
