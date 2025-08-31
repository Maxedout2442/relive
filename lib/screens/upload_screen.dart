import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _video;
  bool _uploading = false;

  // 🔹 Cloudinary details
  final String cloudName = "dq057lhpr";
  final String uploadPreset = "Project";

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _video = File(picked.path);
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_video == null) return;

    setState(() {
      _uploading = true;
    });

    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");

      final request = http.MultipartRequest("POST", url)
        ..fields["upload_preset"] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath("file", _video!.path));

      final streamedResponse = await request.send();
      final responseString = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseString);

      if (data["secure_url"] != null) {
        final videoUrl = data["secure_url"];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Uploaded to Cloudinary!")),
        );

        // 🔹 Save video URL to Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .collection("uploads")
              .add({
            "url": videoUrl,
            "uploadedAt": FieldValue.serverTimestamp(),
          });
        }

        print("Cloudinary Video URL: $videoUrl");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Upload failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8E24AA), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            "Upload Video 📤",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 200, child: Lottie.asset("assets/upload.json")),
                const SizedBox(height: 20),
                _video == null
                    ? const Text("No video selected",
                    style: TextStyle(color: Colors.white70, fontSize: 16))
                    : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "🎬 Selected: ${_video!.path.split('/').last}",
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Pick Video"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _uploadVideo,
                  icon: const Icon(Icons.cloud_upload),
                  label: _uploading
                      ? const Text("Uploading...")
                      : const Text("Upload"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (_uploading) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Uploading...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
