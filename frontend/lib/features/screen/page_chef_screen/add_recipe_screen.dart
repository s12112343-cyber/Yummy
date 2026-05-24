import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_ingredient_screen.dart';
import '../../../core/config/app_config.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  List<Map<String, dynamic>> ingredients = [];

  String difficulty = 'Easy';
  final _time = TextEditingController();
  final _category = TextEditingController();

  File? imageFile;

  bool loading = false;

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> addRecipe() async {
    if (imageFile == null) return;

    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      String? chefId = prefs.getString('chefId');

      if (chefId == null || chefId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chef ID not found. Open profile first.'),
          ),
        );

        setState(() {
          loading = false;
        });

        return;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/recipes'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['chefId'] = chefId ?? '';

      request.fields['name'] = _name.text;

      request.fields['description'] = _description.text;

      request.fields['price'] = _price.text;

      request.fields['totalTime'] = _time.text;

      request.fields['category'] = _category.text;
      request.fields['ingredients'] = jsonEncode(ingredients);

      request.fields['difficulty'] = difficulty;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile!.path),
      );

      final response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe added successfully')),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed To Add Recipe')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() {
      loading = false;
    });
  }

  Widget buildField(
    String title,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: title,

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Recipe')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,

              child: Container(
                width: double.infinity,
                height: 180,

                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),

                        child: Image.file(imageFile!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.add_a_photo, size: 50),
              ),
            ),

            const SizedBox(height: 20),

            buildField('Recipe Name', _name),

            buildField('Description', _description),

            buildField('Price', _price, type: TextInputType.number),
            buildField('Cooking Time', _time, type: TextInputType.number),
            buildField('Category', _category),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: difficulty,

              items: ['Easy', 'Medium', 'Hard'].map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),

              onChanged: (v) {
                setState(() {
                  difficulty = v!;
                });
              },

              decoration: InputDecoration(
                labelText: 'Difficulty',

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => AddIngredientScreen(
                        onSave: (data) {
                          setState(() {
                            ingredients = data;
                          });
                        },
                      ),
                    ),
                  );
                },

                icon: const Icon(Icons.restaurant_menu),

                label: const Text('Add Ingredients'),
              ),
            ),

            const SizedBox(height: 16),

            if (ingredients.isNotEmpty)
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...ingredients.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),

                        child: Text(
                          '• ${e['name']} - ${e['quantity']} ${e['unit']}',
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: loading ? null : addRecipe,

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Publish Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
