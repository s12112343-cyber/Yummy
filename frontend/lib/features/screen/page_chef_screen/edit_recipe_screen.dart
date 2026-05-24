import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

class EditRecipeScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController timeCtrl;
  late TextEditingController categoryCtrl;

  List<Map<String, dynamic>> ingredients = [];

  File? imageFile;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    nameCtrl = TextEditingController(text: widget.recipe['name'] ?? '');

    descCtrl = TextEditingController(text: widget.recipe['description'] ?? '');

    priceCtrl = TextEditingController(text: widget.recipe['price'].toString());

    timeCtrl = TextEditingController(
      text: widget.recipe['totalTime'].toString(),
    );

    categoryCtrl = TextEditingController(text: widget.recipe['category'] ?? '');

    ingredients = List<Map<String, dynamic>>.from(
      widget.recipe['ingredients'] ?? [],
    );
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      imageFile = File(picked.path);
    });
  }

  Future<void> updateRecipe() async {
    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${AppConfig.baseUrl}/recipes/${widget.recipe['_id']}'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = nameCtrl.text;
      request.fields['description'] = descCtrl.text;
      request.fields['price'] = priceCtrl.text;
      request.fields['totalTime'] = timeCtrl.text;
      request.fields['category'] = categoryCtrl.text;

      request.fields['ingredients'] = jsonEncode(ingredients);

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile!.path),
        );
      }

      final response = await request.send();

      final body = await response.stream.bytesToString();

      print(body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recipe updated')));

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update')));
      }
    } catch (e) {
      print(e);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() {
      loading = false;
    });
  }

  Widget ingredientCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [
            TextField(
              controller: TextEditingController(
                text: ingredients[index]['name'],
              ),

              decoration: const InputDecoration(labelText: 'Ingredient Name'),

              onChanged: (v) {
                ingredients[index]['name'] = v;
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: TextEditingController(
                text: ingredients[index]['quantity'].toString(),
              ),

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Quantity'),

              onChanged: (v) {
                ingredients[index]['quantity'] = double.tryParse(v) ?? 0;
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: TextEditingController(
                text: ingredients[index]['unit'],
              ),

              decoration: const InputDecoration(labelText: 'Unit'),

              onChanged: (v) {
                ingredients[index]['unit'] = v;
              },
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,

              child: IconButton(
                onPressed: () {
                  setState(() {
                    ingredients.removeAt(index);
                  });
                },

                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.recipe['image'];

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            GestureDetector(
              onTap: pickImage,

              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),

                child: imageFile != null
                    ? Image.file(
                        imageFile!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,

                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, size: 50),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: nameCtrl,

              decoration: const InputDecoration(labelText: 'Recipe Name'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descCtrl,
              maxLines: 4,

              decoration: const InputDecoration(labelText: 'Description'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: priceCtrl,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Price'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: timeCtrl,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Time'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: categoryCtrl,

              decoration: const InputDecoration(labelText: 'Category'),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                const Text(
                  'Ingredients',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      ingredients.add({'name': '', 'quantity': 1, 'unit': ''});
                    });
                  },

                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: ingredients.length,

              itemBuilder: (context, index) {
                return ingredientCard(index);
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: loading ? null : updateRecipe,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
