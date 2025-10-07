import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:convert';
import 'clipping_screen.dart'; // ✅ navigate here after upload

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final picker = ImagePicker();
  File? _videoFile;
  bool uploading = false;
  String uploadStatus = "";

  // Cloudinary
  final String cloudName = "dq057lhpr";
  final String uploadPreset = "ml_default";

  // Backend (Render)
  final String backendUrl = "https://relive-backend-xvfs.onrender.com";

  final user = FirebaseAuth.instance.currentUser;

  Future<void> pickVideo() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _videoFile = File(pickedFile.path));
    }
  }

  Future<File?> compressVideo(File file) async {
    setState(() => uploadStatus = "Compressing video...");
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    return info?.file;
  }

  Future<void> uploadVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video first.")),
      );
      return;
    }

    setState(() {
      uploading = true;
      uploadStatus = "Preparing video...";
    });

    try {
      // Step 1: Compress
      final compressed = await compressVideo(_videoFile!);
      if (compressed == null) throw Exception("Compression failed");

      // Step 2: Upload to Cloudinary
      setState(() => uploadStatus = "Uploading to Cloudinary...");
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', compressed.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (response.statusCode != 200 || data["secure_url"] == null) {
        throw Exception("Cloudinary upload failed: ${data.toString()}");
      }

      final videoUrl = data["secure_url"];
      final title = _videoFile!.path.split('/').last;

      // Step 3: Save to Firestore
      final uploadDoc = await FirebaseFirestore.instance.collection('uploads').add({
        'title': title,
        'videoUrl': videoUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'userId': user?.uid,
      });

      setState(() => uploadStatus = "Starting AI clipping...");

      // Step 4: Trigger AI processing backend
      final aiResponse = await http.post(
        Uri.parse("$backendUrl/process-video"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"video_url": videoUrl}),
      );

      if (aiResponse.statusCode == 200) {
        final taskId = jsonDecode(aiResponse.body)["task_id"];
        await FirebaseFirestore.instance.collection('uploads').doc(uploadDoc.id).update({
          'taskId': taskId,
          'processing': true,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Upload complete! AI Clipping started.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Upload succeeded, but AI processing failed.")),
        );
      }

      // Step 5: Navigate to ClippingScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ClippingScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
      setState(() => uploadStatus = "Error during upload");
    } finally {
      setState(() => uploading = false);
      VideoCompress.deleteAllCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Video 🎥"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_videoFile == null)
              Lottie.asset('assets/upload.json', width: 200)
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black12,
                ),
                child: Center(
                  child: Text(
                    "🎬 Selected: ${_videoFile!.path.split('/').last}",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            if (!uploading)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.video_library),
                    label: const Text("Pick Video"),
                    onPressed: pickVideo,
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload"),
                    onPressed: uploadVideo,
                  ),
                ],
              ),

            if (uploading) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(uploadStatus, style: const TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}
