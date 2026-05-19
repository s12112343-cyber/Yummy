const express = require('express');
const router = express.Router();

const Recipe = require('../models/Recipe');

const recipeController =
  require('../controllers/recipeController');

const upload = require('../upload');


// ✅ CREATE RECIPE
router.post(
  '/',
  upload.single('image'),
  recipeController.createRecipe,
);


// ✅ GET RECIPES BY CHEF
router.get(
  '/chef/:chefId',
  recipeController.getRecipesByChef
);


// ✅ TRENDING
router.get(
  '/trending',
  recipeController.getTrendingRecipes
);


// ✅ GET ALL RECIPES
router.get(
  '/',
  recipeController.getAllRecipes
);


// ✅ UPDATE OLD NUTRITION
router.get(
  '/update-nutrition',
  recipeController.updateOldRecipesNutrition
);


// ✅ DELETE RECIPE
router.delete('/:id', async (req, res) => {
  try {

    const recipe =
      await Recipe.findByIdAndDelete(req.params.id);

    if (!recipe) {

      return res.status(404).json({
        success: false,
        message: 'Recipe not found',
      });

    }

    res.json({
      success: true,
      message: 'Recipe deleted successfully',
    });

  } catch (e) {

    console.log("DELETE ERROR =>", e);

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
});


// ✅ UPDATE RECIPE
router.patch(
  '/:id',
  upload.single('image'),
  recipeController.updateRecipe
);


// ✅ GET RECIPE BY ID
router.get('/:id', async (req, res) => {
  try {

    const recipe =
      await Recipe.findById(req.params.id);

    res.json({
      success: true,
      data: recipe,
    });

  } catch (e) {

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
});


module.exports = router;