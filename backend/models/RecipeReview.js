const mongoose =
    require('mongoose');

const recipeReviewSchema =
    new mongoose.Schema({

  recipeId: {

    type:
        mongoose.Schema.Types.ObjectId,

    ref: 'Recipe',

    required: true,
  },

  userId: {

    type:
        mongoose.Schema.Types.ObjectId,

    ref: 'User',
  },

  userName: {

    type: String,

    default: '',
  },

  rating: {

    type: Number,

    required: true,
  },

  comment: {

    type: String,

    default: '',
  },

}, {

  timestamps: true,
});

module.exports =
    mongoose.model(
      'RecipeReview',
      recipeReviewSchema,
    );