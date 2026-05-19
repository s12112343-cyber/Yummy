
const RecipeReview =
    require('../models/RecipeReview');

const Recipe =
    require('../models/Recipe');


// ✅ ADD REVIEW
const addRecipeReview =
async (req, res) => {

  try {

    const {

      recipeId,
      rating,
      comment,

    } = req.body;

    // 🔥 CREATE REVIEW
    const review =
        await RecipeReview.create({

      recipeId,

      rating,

      comment,

      userId:
          req.user.userId,

      userName:
          req.user.name,
    });

    // 🔥 GET ALL REVIEWS
const reviews =
    await RecipeReview.find({
  recipeId,
});

// 🔥 AVG REAL REVIEWS ONLY
const avg =
    reviews.reduce(
      (sum, item) =>
          sum + item.rating,
      0,
    ) / reviews.length;

// 🔥 UPDATE RECIPE
await Recipe.findByIdAndUpdate(
  recipeId,
  {

    rating:
        reviews.length > 0
            ? avg
            : 4,

    reviewsCount:
        reviews.length,
  },
);
    res.status(201).json({

      success: true,

      review,
    });

  } catch (e) {

    console.log(e);

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};


// ✅ GET RECIPE REVIEWS
const getRecipeReviews = async (req, res) => {

  try {

    const { recipeId } = req.params;

    const reviews =
        await RecipeReview.find({

      recipeId,

    }).sort({
      createdAt: -1,
    });

    res.json({

      success: true,

      data: reviews,
    });

  } catch (e) {

    console.log(
      'GET RECIPE REVIEWS ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};



const deleteRecipeReview =
async (req, res) => {

  try {

    await RecipeReview.findByIdAndDelete(
      req.params.id,
    );

    res.json({

      success: true,

      message:
          'Review deleted',
    });

  } catch (e) {

    console.log(
      'DELETE REVIEW ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};
module.exports = {

  addRecipeReview,

  getRecipeReviews,
  deleteRecipeReview,
};