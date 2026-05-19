const Recipe = require('../models/Recipe');
const Chef = require('../models/Chef');
const calculateNutrition = require('../utils/calcNutrition');


// ✅ CREATE RECIPE
const createRecipe = async (req, res) => {
  try {

    console.log("BODY =>", req.body);
    console.log("FILE =>", req.file);

    const {
      name,
      description,
      price,
      category,
      totalTime,
      chefId,
      ingredients,
    } = req.body;

    // ✅ parse ingredients
    const parsedIngredients =
      typeof ingredients === 'string'
        ? JSON.parse(ingredients)
        : ingredients;

    // ✅ nutrition
    const nutrition =
      await calculateNutrition(parsedIngredients);

    // ✅ image path
    let imageUrl = '';

    if (req.file) {
      imageUrl =
        `/uploads/${req.file.filename}`;
    }

    console.log("CHEF ID =>", chefId);

    // ✅ create recipe
    const recipe = new Recipe({
      name,
      description,
      image: imageUrl,
      price,
      category,
      totalTime,
      chefId,
      ingredients: parsedIngredients,

      calories: nutrition.calories,
      fat: nutrition.fat,
      protein: nutrition.protein,
      potassium: nutrition.potassium,
      unknownIngredients:
        nutrition.unknownIngredients,
    });

    await recipe.save();

    console.log("✅ RECIPE SAVED");

    res.status(201).json({
      success: true,
      data: recipe,
    });

  } catch (error) {

    console.log(
      "❌ CREATE RECIPE ERROR =>",
      error
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });

  }
};


// ✅ UPDATE RECIPE
const updateRecipe = async (req, res) => {
  try {

    console.log("UPDATE BODY =>", req.body);
    console.log("UPDATE FILE =>", req.file);

    const updatedData = {
      ...req.body,
    };

    // ✅ parse ingredients
    if (req.body.ingredients) {
      updatedData.ingredients =
        JSON.parse(req.body.ingredients);
    }

    // ✅ new image
    if (req.file) {
      updatedData.image =
        `/uploads/${req.file.filename}`;
    }

    // ✅ recalculate nutrition
    if (updatedData.ingredients) {

      const nutrition =
        await calculateNutrition(
          updatedData.ingredients
        );

      updatedData.calories =
        nutrition.calories;

      updatedData.fat =
        nutrition.fat;

      updatedData.protein =
        nutrition.protein;

      updatedData.potassium =
        nutrition.potassium;

      updatedData.unknownIngredients =
        nutrition.unknownIngredients;
    }

    const recipe =
      await Recipe.findByIdAndUpdate(
        req.params.id,
        updatedData,
        {
          returnDocument: 'after',
        }
      );

    res.json({
      success: true,
      data: recipe,
    });

  } catch (e) {

    console.log(
      "❌ UPDATE ERROR =>",
      e
    );

    res.status(500).json({
      success: false,
      message: e.message,
    });

  }
};


// ✅ GET RECIPES BY CHEF
const getRecipesByChef = async (req, res) => {
  try {

    const recipes = await Recipe.find({
      chefId: req.params.chefId,
    })

    .populate({
      path: 'chefId',
      model: 'Chef',
    })

    .lean();

    const formattedRecipes =
      recipes.map((recipe) => {

      return {

        ...recipe,

        chef: {
          _id: recipe.chefId?._id,
          name:
            recipe.chefId?.name || '',
          profileImage:
            recipe.chefId?.profileImage || '',
          bio:
            recipe.chefId?.bio || '',
          specialties:
            recipe.chefId?.specialties || [],
          experience:
            recipe.chefId?.experience || '',
        }

      };

    });

    res.json({
      success: true,
      data: formattedRecipes,
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      success: false,
      message: err.message,
    });

  }
};


// ✅ GET TRENDING
const getTrendingRecipes = async (req, res) => {

  try {

    const recipes = await Recipe.find()

      .populate({
        path: 'chefId',
        model: 'Chef',
      })

      .sort({
        rating: -1,
        views: -1,
        orders: -1,
      })

      .limit(10)

      .lean();

    const formattedRecipes =
      recipes.map((recipe) => {

      return {

        ...recipe,

        chef: {
          _id: recipe.chefId?._id,
          name:
            recipe.chefId?.name || '',
          profileImage:
            recipe.chefId?.profileImage || '',
          bio:
            recipe.chefId?.bio || '',
          specialties:
            recipe.chefId?.specialties || [],
          experience:
            recipe.chefId?.experience || '',
        }

      };

    });

    res.status(200).json({
      success: true,
      data: formattedRecipes,
    });

  } catch (error) {

    console.error(
      "❌ Trending Error:",
      error
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });

  }

};


// ✅ GET ALL RECIPES
const getAllRecipes = async (req, res) => {
  try {

    const recipes =
      await Recipe.find()
      .populate('chefId');

    res.json({
      success: true,
      data: recipes,
    });

  } catch (error) {

    console.error(
      '❌ Error fetching all recipes:',
      error
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });

  }
};


// ✅ UPDATE OLD NUTRITION
const updateOldRecipesNutrition =
  async (req, res) => {

  try {

    const recipes =
      await Recipe.find();

    for (let recipe of recipes) {

      const nutrition =
        await calculateNutrition(
          recipe.ingredients || []
        );

      recipe.calories =
        nutrition.calories;

      recipe.fat =
        nutrition.fat;

      recipe.protein =
        nutrition.protein;

      recipe.potassium =
        nutrition.potassium;

      recipe.unknownIngredients =
        nutrition.unknownIngredients;

      await recipe.save();
    }

    res.json({
      message:
        'All recipes updated 🔥'
    });

  } catch (error) {

    res.status(500).json({
      message: error.message
    });

  }
};


module.exports = {
  createRecipe,
  updateRecipe,
  getRecipesByChef,
  getTrendingRecipes,
  getAllRecipes,
  updateOldRecipesNutrition,
};