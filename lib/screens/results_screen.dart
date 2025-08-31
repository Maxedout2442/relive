import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final String videoUrl;
  const ResultsScreen({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Results")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Video Results", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Text("Processed URL: $videoUrl"),
          ],
        ),
      ),
    );
  }
}
