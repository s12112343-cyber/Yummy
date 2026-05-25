const {
  searchMeals,
  getRandomMeals,
  getMealById,
} = require("../services/external_recipe_api_service");

exports.getExternalRecipes = async (req, res) => {
  try {
    const { search, cuisine, dietType } = req.query;

    let recipes;

    if (search && search.trim() !== "") {
recipes = await searchMeals(
  search.trim(),
);    } else {
      recipes = await getRandomMeals(10);
    }

    if (cuisine && cuisine !== "All") {
      recipes = recipes.filter(
        (recipe) =>
          recipe.cuisine.toLowerCase() === cuisine.toLowerCase()
      );
    }

    if (dietType && dietType !== "All") {
      recipes = recipes.filter(
        (recipe) =>
          recipe.dietType.toLowerCase() === dietType.toLowerCase()
      );
    }

    res.status(200).json({
      success: true,
      recipes,
    });
  } catch (error) {
    console.log("Get external recipes error:", error.message);

    res.status(500).json({
      success: false,
      message: "Failed to fetch recipes",
      error: error.message,
    });
  }
};

exports.getExternalRecipeById = async (req, res) => {
  try {
    const recipe = await getMealById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: "Recipe not found",
      });
    }

    res.status(200).json({
      success: true,
      recipe,
    });
  } catch (error) {
    console.log("Get recipe by id error:", error.message);

    res.status(500).json({
      success: false,
      message: "Failed to fetch recipe details",
      error: error.message,
    });
  }
};