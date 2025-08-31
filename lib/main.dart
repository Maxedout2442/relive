import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';
import 'screens/upload_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_page.dart';

// Providers
import 'package:relive/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Relive',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            final username = user.displayName ?? user.email!.split('@')[0];
            // ✅ Try to show displayName, otherwise fallback to email prefix
            return HomePage();
          }
          return LoginPage(onTap: () {
            Navigator.pushReplacementNamed(context, '/signup');
          });
        },
      ),
      routes: {
        '/login': (context) => LoginPage(onTap: () {
          Navigator.pushReplacementNamed(context, '/signup');
        }),
        '/signup': (context) => SignupPage(onTap: () {
          Navigator.pushReplacementNamed(context, '/login');
        }),
        '/home': (context) {
          return const HomePage();
        },


        '/upload': (context) => UploadScreen(),
        '/results': (context) => const ResultsScreen(videoUrl: "demo"),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
