const express = require('express');

const router = express.Router();

const {
  addRecipeReview,
  getRecipeReviews,
  deleteRecipeReview,
} = require('../controllers/reviewRecipeController');

const {
  verifyToken,
} = require('../middleware/authMiddleware');

router.post(
  '/',
  verifyToken,
  addRecipeReview,
);

router.get(
  '/:recipeId',
  getRecipeReviews,
);

router.delete(
  '/:id',
  verifyToken,
  deleteRecipeReview,
);

module.exports = router;