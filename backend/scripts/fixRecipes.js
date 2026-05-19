const mongoose = require('mongoose');
require('dotenv').config();

const Recipe = require('../models/Recipe');
const calculateNutrition = require('../utils/calcNutrition');

async function fixRecipes() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("✅ Connected to DB");

    const recipes = await Recipe.find();

    for (let recipe of recipes) {
      let cleanedIngredients = [];

      for (let item of recipe.ingredients || []) {
        if (!item || !item.name) continue;

        const cleanName = item.name
          .toString()
          .toLowerCase()
          .trim();

        cleanedIngredients.push({
          name: cleanName,
          quantity: item.quantity || 100, // 🔥 default
        });
      }

      // 🔥 حذف الفارغ
      cleanedIngredients = cleanedIngredients.filter(i => i.name !== '');

      // 🔥 حساب nutrition
      const nutrition = calculateNutrition(cleanedIngredients);

      // 🔥 تحديث
      recipe.ingredients = cleanedIngredients;
      recipe.calories = nutrition.calories;
      recipe.fat = nutrition.fat;
      recipe.protein = nutrition.protein;
      recipe.potassium = nutrition.potassium;
      recipe.unknownIngredients = nutrition.unknownIngredients;

      await recipe.save();

      console.log(`🔥 Fixed: ${recipe.name}`);
    }

    console.log("💀 ALL DATA FIXED SUCCESSFULLY");
    process.exit();

  } catch (e) {
    console.error("❌ Error:", e);
    process.exit(1);
  }
}

fixRecipes();