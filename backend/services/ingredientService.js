const axios = require('axios');

const FORKIFY_SEARCH_URL = 'https://forkify-api.herokuapp.com/api/search';
const FORKIFY_GET_URL = 'https://forkify-api.herokuapp.com/api/get';

function _cleanString(value) {
  return (value ?? '').toString().trim();
}

function _normalizeText(value) {
  return _cleanString(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function _splitIngredient(value) {
  const cleaned = _cleanString(value);
  if (!cleaned) {
    return null;
  }

  const normalized = cleaned.replace(/\s+/g, ' ').trim();
  const match = normalized.match(/^([\d./\s-]+)?\s*(.+)$/);
  if (!match) {
    return normalized;
  }

  const ingredientPart = _cleanString(match[2]);
  return ingredientPart || normalized;
}

function _scoreRecipeTitle(title, mealName) {
  const normalizedTitle = _normalizeText(title);
  const normalizedMeal = _normalizeText(mealName);

  if (!normalizedTitle || !normalizedMeal) {
    return 0;
  }

  if (normalizedTitle === normalizedMeal) {
    return 1000;
  }

  let score = 0;
  const mealTokens = normalizedMeal.split(' ');

  for (const token of mealTokens) {
    if (token.length < 2) {
      continue;
    }

    if (normalizedTitle.includes(token)) {
      score += token.length * 10;
    }
  }

  if (normalizedTitle.includes(normalizedMeal) || normalizedMeal.includes(normalizedTitle)) {
    score += 200;
  }

  return score;
}

function _extractForkifyIngredients(recipe) {
  const ingredients = Array.isArray(recipe?.ingredients) ? recipe.ingredients : [];

  return ingredients
    .map((ingredient) => _splitIngredient(ingredient))
    .filter(Boolean)
    .map((ingredientName) => ({
      name: ingredientName,
      quantity: 1,
      unit: 'unit',
    }));
}

async function _fetchFromInternet(mealName) {
  const searchResponse = await axios.get(FORKIFY_SEARCH_URL, {
    params: { q: mealName.trim() },
    timeout: 10000,
  });

  const recipes = Array.isArray(searchResponse.data?.recipes)
    ? searchResponse.data.recipes
    : [];

  if (recipes.length === 0) {
    return [];
  }

  const rankedRecipes = recipes
    .map((recipe) => ({
      ...recipe,
      _score: _scoreRecipeTitle(recipe.title, mealName),
    }))
    .sort((left, right) => right._score - left._score || right.social_rank - left.social_rank);

  const selectedRecipe = rankedRecipes[0];
  if (!selectedRecipe?.recipe_id) {
    return [];
  }

  const detailResponse = await axios.get(FORKIFY_GET_URL, {
    params: { rId: selectedRecipe.recipe_id },
    timeout: 10000,
  });

  const recipe = detailResponse.data?.recipe;
  if (!recipe) {
    return [];
  }

  return _extractForkifyIngredients(recipe);
}

/**
 * Main function: Fetch ingredients for a meal name
 * Supports different naming variations (e.g., burger vs hamburger)
 * @param {string} mealName - Name of the meal (can be any variation)
 * @returns {Promise<Array>} Array of ingredients with name, quantity, unit (NO calories/weight)
 */
async function fetchIngredientsForMeal(mealName) {
  try {
    if (!mealName || mealName.trim().length === 0) {
      throw new Error('Meal name is required');
    }

    const ingredients = await _fetchFromInternet(mealName);

    if (ingredients.length > 0) {
      console.log(`✅ Found ${ingredients.length} ingredients for "${mealName}" from Forkify`);
      return ingredients;
    }

    console.warn(`⚠️ No Forkify ingredients found for "${mealName}"`);
    return [];
  } catch (error) {
    console.error('❌ Error fetching ingredients:', error.message);
    return [];
  }
}

module.exports = {
  fetchIngredientsForMeal,
};
