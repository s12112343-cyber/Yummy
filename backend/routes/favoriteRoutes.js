const express = require('express');

const Favorite = require('../models/Favorite');
const { verifyToken } = require('../middleware/authMiddleware');
const { apiLimiter } = require('../middleware/rateLimitMiddleware');

const router = express.Router();

const normalizeRecipe = (recipe, recipeId) => {
  if (!recipe || typeof recipe !== 'object') {
    return { _id: recipeId, id: recipeId };
  }

  return {
    ...recipe,
    _id: recipeId,
    id: recipeId,
  };
};

router.get('/', verifyToken, apiLimiter, async (req, res) => {
  try {
    const favorites = await Favorite.find({ user: req.user.userId })
      .sort({ createdAt: -1 })
      .lean();

    return res.status(200).json({
      success: true,
      favorites: favorites.map((favorite) => ({
        id: favorite._id,
        recipeId: favorite.recipeId,
        recipe: normalizeRecipe(favorite.recipe, favorite.recipeId),
        createdAt: favorite.createdAt,
        updatedAt: favorite.updatedAt,
      })),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to load favorites',
    });
  }
});

router.post('/', verifyToken, apiLimiter, async (req, res) => {
  try {
    const { recipeId, recipe } = req.body;

    if (!recipeId) {
      return res.status(400).json({
        success: false,
        message: 'recipeId is required',
      });
    }

    const normalizedRecipe = normalizeRecipe(recipe, recipeId);

    const favorite = await Favorite.findOneAndUpdate(
      { user: req.user.userId, recipeId },
      {
        user: req.user.userId,
        recipeId,
        recipe: normalizedRecipe,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    ).lean();

    return res.status(200).json({
      success: true,
      favorite: {
        id: favorite._id,
        recipeId: favorite.recipeId,
        recipe: normalizeRecipe(favorite.recipe, favorite.recipeId),
        createdAt: favorite.createdAt,
        updatedAt: favorite.updatedAt,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to save favorite',
    });
  }
});

router.delete('/:recipeId', verifyToken, apiLimiter, async (req, res) => {
  try {
    const { recipeId } = req.params;

    await Favorite.deleteOne({ user: req.user.userId, recipeId });

    return res.status(200).json({
      success: true,
      message: 'Favorite removed',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to remove favorite',
    });
  }
});

module.exports = router;
