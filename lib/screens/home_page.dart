import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar.dart';
import 'package:relive/screens/recent_uploads_page.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? user = FirebaseAuth.instance.currentUser;
  String? username;
  bool isLoading = true;
  List<String> recentVideos = [];
  String? _selectedAnimal;

  final List<Map<String, String>> _animalOptions = [
    {'name': 'Chameleon', 'asset': 'assets/animals/Camaleon.json'},
    {'name': 'Crocodile', 'asset': 'assets/animals/crocodile.json'},
    {'name': 'Toucan', 'asset': 'assets/animals/Toucan.json'},
    {'name': 'Monkey', 'asset': 'assets/animals/monkey.json'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute
        .of(context)!
        .settings
        .arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('username')) {
      username = args['username'];
      isLoading = false;
    } else {
      fetchUsername();
    }
    _loadSelectedAnimal();
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
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSelectedAnimal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAnimal = prefs.getString('selectedAnimal');
    });
  }

  Future<void> _saveSelectedAnimal(String assetPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedAnimal', assetPath);
    setState(() {
      _selectedAnimal = assetPath;
    });
  }

  void _openAnimalSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white.withOpacity(0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _animalOptions.length,
            itemBuilder: (context, index) {
              final animal = _animalOptions[index];
              return GestureDetector(
                onTap: () {
                  _saveSelectedAnimal(animal['asset']!);
                  Navigator.pop(context);
                },
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Lottie.asset(animal['asset']!),
                        ),
                        Text(
                          animal['name']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String getGreeting() {
    final hour = DateTime
        .now()
        .hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
          shaderCallback: (bounds) =>
              const LinearGradient(
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 Greeting Box with two-line text + glowing PFP
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              getGreeting(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (username ?? "User"),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: _openAnimalSelector,
                        child: Animate(
                          effects: [
                            ScaleEffect(
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeInOut,
                              begin: const Offset(1, 1),
                              end: const Offset(1.08, 1.08),
                            ),
                            FadeEffect(
                              duration: const Duration(seconds: 2),
                              begin: 1,
                              end: 0.85,
                            ),
                          ],
                          onComplete: (controller) =>
                              controller.repeat(reverse: true),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purpleAccent
                                      .withOpacity(0.6),
                                  blurRadius: 14,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor:
                              Colors.white.withOpacity(0.9),
                              child: _selectedAnimal == null
                                  ? const Icon(Icons.person,
                                  color: Colors.grey, size: 45)
                                  : ClipOval(
                                child: Transform.scale(
                                  scale: 1.4, // ✅ makes full animation visible
                                  child: Lottie.asset(
                                    _selectedAnimal!,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ Scrollable Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildRecentUploadsCard(),
                    _buildDemoCard(Icons.insights, "AI Results",
                        Colors.blueAccent),
                    _buildDemoCard(Icons.analytics, "Auto-Captioning",
                        Colors.orangeAccent),
                    _buildDemoCard(Icons.star, "Highlights",
                        Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUploadsCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecentUploadsPage()),
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
              Icon(Icons.upload_file, size: 50, color: Colors.black),
              SizedBox(height: 10),
              Text(
                "Recent Uploads",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard(IconData icon, String title, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (title == "AI Results") {
          Navigator.pushNamed(context, '/aiResults');
        } else if (title == "Auto-Captioning") {
          Navigator.pushNamed(context, '/autoCaption');
        } else if (title == "Highlights") {
          Navigator.pushNamed(context, '/highlights');
        }
      },
      child: Container(
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
      ),
    );
  }
}
