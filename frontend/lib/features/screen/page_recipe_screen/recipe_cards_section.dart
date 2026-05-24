import 'package:flutter/material.dart';

class RecipeCardsSection extends StatelessWidget {
  final String searchText;

  const RecipeCardsSection({super.key, required this.searchText});

  @override
  Widget build(BuildContext context) {
    final List recipes = [
      {
        "title": "Chicken Burger",
        "image": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd",
        "time": "25 min",
        "calories": "420 kcal",
      },

      {
        "title": "Creamy Pasta",
        "image": "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9",
        "time": "18 min",
        "calories": "350 kcal",
      },

      {
        "title": "Healthy Salad",
        "image": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
        "time": "10 min",
        "calories": "190 kcal",
      },

      {
        "title": "Pizza",
        "image": "https://images.unsplash.com/photo-1513104890138-7c749659a591",
        "time": "35 min",
        "calories": "510 kcal",
      },
    ];

    final filteredRecipes = recipes.where((recipe) {
      return recipe["title"].toString().toLowerCase().contains(
        searchText.toLowerCase(),
      );
    }).toList();

    if (filteredRecipes.isEmpty) {
      return const Center(
        child: Text(
          "No recipes found",

          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xff6B7A90),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),

      itemCount: filteredRecipes.length,

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,

        crossAxisSpacing: 14,

        mainAxisSpacing: 14,

        childAspectRatio: 0.67,
      ),

      itemBuilder: (context, index) {
        final recipe = filteredRecipes[index];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(22),

            border: Border.all(color: const Color(0xffDDE7F3)),

            boxShadow: [
              BoxShadow(
                color: const Color(0xff93B4DF).withOpacity(0.10),

                blurRadius: 14,

                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),

                      child: Image.network(
                        recipe["image"].toString(),

                        width: double.infinity,

                        fit: BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top: 10,
                      right: 10,

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),

                          borderRadius: BorderRadius.circular(999),
                        ),

                        child: Text(
                          recipe["time"].toString(),

                          style: const TextStyle(
                            color: Colors.white,

                            fontSize: 11,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      recipe["title"].toString(),

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 15,

                        fontWeight: FontWeight.w800,

                        color: Color(0xff1B3C73),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,

                          color: Colors.orange,

                          size: 18,
                        ),

                        const SizedBox(width: 4),

                        Text(
                          recipe["calories"].toString(),

                          style: const TextStyle(
                            color: Color(0xff6B7A90),

                            fontSize: 12,

                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
