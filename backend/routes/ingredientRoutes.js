const express = require('express');
const router = express.Router();
const Ingredient = require('../models/Ingredient');
const Recipe = require('../models/Recipe');
const calculateNutrition = require('../utils/calcNutrition');
const { searchSpoonacularIngredients } = require('../services/spoonacularIngredientService');

function _escapeRegex(value) {
  return (value ?? '')
    .toString()
    .trim()
    .replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function _toIngredientPayload(ingredient) {
  return {
    name: ingredient.name,
    imageUrl: null,
    source: 'local',
  };
}

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
  try {
    const query = (req.query.q ?? '').toString().trim();

    if (!query) {
      return res.json([]);
    }

    const escapedQuery = _escapeRegex(query);

    const [localResults, spoonacularResults] = await Promise.all([
      Ingredient.find({
        name: { $regex: escapedQuery, $options: 'i' },
      }).limit(10),
      searchSpoonacularIngredients(query, 10),
    ]);

    const combinedResults = [];
    const seenNames = new Set();

    for (const ingredient of localResults.map(_toIngredientPayload)) {
      const key = ingredient.name.toLowerCase();

      if (!seenNames.has(key)) {
        seenNames.add(key);
        combinedResults.push(ingredient);
      }
    }

    for (const ingredient of spoonacularResults) {
      const key = ingredient.name.toLowerCase();

      if (!seenNames.has(key)) {
        seenNames.add(key);
        combinedResults.push(ingredient);
      }
    }

    return res.json(combinedResults.slice(0, 10));
  } catch (error) {
    console.error('Ingredient search failed:', error.message);
    return res.status(500).json({ message: 'Failed to search ingredients' });
  }
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