const express = require("express");

const router = express.Router();

const {
  getExternalRecipes,
  getExternalRecipeById,
} = require("../controllers/external_recipe_controller");

router.get("/", getExternalRecipes);

router.get("/:id", getExternalRecipeById);

module.exports = router;