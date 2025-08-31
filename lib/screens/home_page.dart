import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar.dart';
import 'package:relive/screens/recent_uploads_page.dart'; // make sure this file exists

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? user = FirebaseAuth.instance.currentUser;
  String? username;
  bool isLoading = true;
  List<String> recentVideos = []; // store Cloudinary URLs

  @override
  void initState() {
    super.initState();
    fetchUsername();
    fetchRecentUploads();
  }

  Future<void> fetchUsername() async {
    if (user == null) {
      setState(() {
        username = "Guest";
        isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey("username")) {
        setState(() {
          username = doc["username"];
        });
      } else {
        setState(() {
          username = user!.displayName ?? user!.email?.split('@')[0] ?? "User";
        });
      }
    } catch (e) {
      setState(() {
        username = "User";
      });
    }
  }

  Future<void> fetchRecentUploads() async {
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection("uploads")
          .orderBy("uploadedAt", descending: true)
          .limit(10)
          .get();

      setState(() {
        recentVideos = snapshot.docs.map((doc) => doc["url"] as String).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        recentVideos = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Sidebar(user: user, username: username ?? "User"),
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
            "Relive",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8E24AA), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Good Evening, ${username ?? "User"} 👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildRecentUploadsCard(),
                    _buildDemoCard(Icons.insights, "AI Results", Colors.blueAccent),
                    _buildDemoCard(Icons.analytics, "Analytics Demo", Colors.orangeAccent),
                    _buildDemoCard(Icons.star, "Highlights", Colors.greenAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUploadsCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final snapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("uploads")
            .orderBy("uploadedAt", descending: true)
            .get();

        final recentVideos =
        snapshot.docs.map((doc) => doc["url"] as String).toList();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecentUploadsPage(videoUrls: recentVideos),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(3, 5),
            )
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.upload_file, size: 50, color: Colors.purpleAccent),
              SizedBox(height: 10),
              Text(
                "Recent Uploads",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildDemoCard(IconData icon, String title, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(3, 5),
          )
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
