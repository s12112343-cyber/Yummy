import 'package:flutter/material.dart';

class AddIngredientScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSave;

  const AddIngredientScreen({super.key, required this.onSave});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final nameController = TextEditingController();

  final quantityController = TextEditingController();

  String selectedUnit = 'g';

  List<Map<String, dynamic>> ingredients = [];

  final List<String> units = [
    'g',
    'kg',
    'ml',
    'L',
    'piece',
    'tbsp',
    'tsp',
    'cup',
  ];

  void addIngredient() {
    if (nameController.text.isEmpty || quantityController.text.isEmpty) {
      return;
    }

    setState(() {
      ingredients.add({
        "name": nameController.text.trim(),

        "quantity": double.tryParse(quantityController.text) ?? 0,

        "unit": selectedUnit,
      });

      nameController.clear();

      quantityController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Ingredients')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          widget.onSave(ingredients);

          Navigator.pop(context);
        },

        icon: const Icon(Icons.check),

        label: const Text('Save'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            TextField(
              controller: nameController,

              decoration: InputDecoration(
                labelText: 'Ingredient Name',

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,

                    keyboardType: TextInputType.number,

                    decoration: InputDecoration(
                      labelText: 'Quantity',

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,

                    items: units.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),

                    onChanged: (v) {
                      setState(() {
                        selectedUnit = v!;
                      });
                    },

                    decoration: InputDecoration(
                      labelText: 'Unit',

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: addIngredient,

                icon: const Icon(Icons.add),

                label: const Text('Add Ingredient'),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: ingredients.length,

                itemBuilder: (_, index) {
                  final item = ingredients[index];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: ListTile(
                      leading: const Icon(Icons.restaurant_menu),

                      title: Text(item['name']),

                      subtitle: Text('${item['quantity']} ${item['unit']}'),

                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),

                        onPressed: () {
                          setState(() {
                            ingredients.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
