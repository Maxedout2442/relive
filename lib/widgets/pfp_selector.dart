import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePictureSelector extends StatefulWidget {
  const ProfilePictureSelector({super.key});

  @override
  State<ProfilePictureSelector> createState() => _ProfilePictureSelectorState();
}

class _ProfilePictureSelectorState extends State<ProfilePictureSelector> {
  String? _selectedAnimal;

  final List<Map<String, String>> _animalOptions = [
    {'name': 'Cat', 'asset': 'assets/animals/cat.json'},
    {'name': 'Dog', 'asset': 'assets/animals/dog.json'},
    {'name': 'Panda', 'asset': 'assets/animals/panda.json'},
    {'name': 'Fox', 'asset': 'assets/animals/fox.json'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedAnimal();
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openAnimalSelector,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey.shade300,
        child: _selectedAnimal == null
            ? const Icon(Icons.person, size: 32, color: Colors.grey)
            : ClipOval(
          child: Lottie.asset(
            _selectedAnimal!,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
