import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _video;
  bool _uploading = false;
  double _progress = 0.0;
  String _statusMessage = "";

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

  Future<File?> _compressVideo(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality, // smaller file size = more reliable
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      debugPrint("Compression error: $e");
      return file;
    }
  }

  Future<void> _uploadVideo() async {
    if (_video == null) return;

    setState(() {
      _uploading = true;
      _progress = 0.0;
      _statusMessage = "Compressing video...";
    });

    try {
      // 1️⃣ Compress video to smaller size
      final compressedVideo = await _compressVideo(_video!);
      final fileToUpload = compressedVideo ?? _video!;
      debugPrint("File size after compression: ${fileToUpload.lengthSync() / (1024 * 1024)} MB");

      _statusMessage = "Uploading to Cloudinary...";
      setState(() => _progress = 0.2);

      // 2️⃣ Upload to Cloudinary using simple request (prevents broken pipe)
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
      var request = http.MultipartRequest("POST", url);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', fileToUpload.path));

      var response = await request.send();
      var responseString = await response.stream.bytesToString();
      final data = jsonDecode(responseString);

      if (data["secure_url"] != null) {
        final videoUrl = data["secure_url"];
        setState(() {
          _progress = 1.0;
          _statusMessage = "✅ Upload complete!";
        });

        // 3️⃣ Save uploaded video to Firestore
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

        // 4️⃣ Notify user & navigate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Uploaded to Cloudinary successfully!")),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pushNamed(context, '/clipping');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Upload failed. Please try again.")),
        );
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Upload error: $e")),
      );
    } finally {
      setState(() {
        _uploading = false;
        _statusMessage = "";
      });
      VideoCompress.dispose();
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
                    ? const Text(
                  "No video selected",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                )
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
                      : const Text("Upload to Cloudinary"),
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
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
