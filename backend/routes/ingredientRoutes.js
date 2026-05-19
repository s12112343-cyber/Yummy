const express = require('express');
const router = express.Router();
const Ingredient = require('../models/Ingredient');
const Recipe = require('../models/Recipe');
const calculateNutrition = require('../utils/calcNutrition');

// 🔥 ADD + AUTO UPDATE
router.post('/add', async (req, res) => {
  try {
    const ingredient = new Ingredient(req.body);
    await ingredient.save();

    const recipes = await Recipe.find();

    for (let recipe of recipes) {
      const nutrition = calculateNutrition(recipe.ingredients || []);

      recipe.calories = nutrition.calories;
      recipe.fat = nutrition.fat;
      recipe.protein = nutrition.protein;
      recipe.potassium = nutrition.potassium;
      recipe.unknownIngredients = nutrition.unknownIngredients;

      await recipe.save();
    }

    res.json({ success: true });

  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// 🔥 SEARCH
router.get('/search', async (req, res) => {
  const query = req.query.q;

  const results = await Ingredient.find({
    name: { $regex: query, $options: 'i' }
  }).limit(10);

  res.json(results);
});

// 🔥 GET BY NAME
router.get('/by-name', async (req, res) => {
  try {
    const ingredient = await Ingredient.findOne({
      name: { $regex: `^${req.query.name}$`, $options: 'i' }
    });

    res.json(ingredient || {});
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;