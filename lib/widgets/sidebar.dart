import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Sidebar extends StatelessWidget {
  final User? user;
  final String username;

  const Sidebar({super.key, required this.user, required this.username});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 50),
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 40, color: Colors.deepPurple)
                        : null,
                  ),
                  accountName: Text(
                    username,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  accountEmail: Text(
                    user?.email ?? "",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),

                _buildDrawerItem(Icons.home, "Home", () {
                  Navigator.pop(context);
                }),
                _buildDrawerItem(Icons.video_library, "My Uploads", () {
                  Navigator.pushNamed(context, '/upload');
                }),
                _buildDrawerItem(Icons.assessment, "Results", () {
                  Navigator.pushNamed(context, '/results');
                }),

                const Divider(color: Colors.white38),

                _buildDrawerItem(Icons.settings, "Settings", () {
                  Navigator.pushNamed(context, '/settings');
                }),


                const Spacer(),

                _buildDrawerItem(Icons.logout, "Logout", () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      hoverColor: Colors.white24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
