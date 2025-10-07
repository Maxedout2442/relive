import 'package:flutter/material.dart';

class AIResultsPage extends StatelessWidget {
  const AIResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Results"),
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
                const Icon(Icons.analytics_outlined, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "AI Insights Coming Soon!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This page will visualize AI analysis results like mood detection, emotion tracking, or engagement charts.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
