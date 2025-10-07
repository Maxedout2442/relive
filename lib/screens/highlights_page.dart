import 'package:flutter/material.dart';

class HighlightsPage extends StatelessWidget {
  const HighlightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Highlights"),
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
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 50, color: Colors.deepPurple),
                    const SizedBox(height: 10),
                    Text(
                      "Highlight ${index + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
