
const RecipeReview =
  require('../models/RecipeReview');

const Recipe =
  require('../models/Recipe');

const Notification =
  require('../models/Notification');

const Chef =
  require('../models/Chef');

//
// ✅ ADD REVIEW
//
const addRecipeReview =
async (req, res) => {

  try {

    const {
      recipeId,
      rating,
      comment,
    } = req.body;

    //
    // 🔥 CREATE REVIEW
    //
    const review =
      await RecipeReview.create({

        recipeId,

        rating,

        comment,

        userId:
          req.user.userId,

        userName:
          req.user.name,

        userAvatar:
          req.user.profileImage || '',
      });

    //
    // 🔥 GET RECIPE
    //
    const recipe =
      await Recipe.findById(
        recipeId
      );

    //
    // 🔥 GET CHEF
    //
    const chef =
      await Chef.findById(
        recipe.chefId
      );

    //
    // 🔥 SEND NOTIFICATION
    //
    if (recipe && chef) {

      const notification =
        await Notification.create({

          recipientId:
            chef.userId.toString(),

          actorId:
            req.user.userId.toString(),

          actorName:
            req.user.name || "User",

          actorImageUrl:
            req.user.profileImage || "",

          type: "recipe_review",

          title:
            "Recipe Rated 🍲",

          body:
            `${req.user.name} rated your recipe`,

          isRead: false,

          payload: {
            recipeId:
              recipe._id,
          },
        });

      console.log(
        "🔥 RECIPE NOTIFICATION SENT"
      );

      //
      // 🔥 REALTIME SOCKET
      //
      const io =
        req.app.get('io');

      if (io) {

        io.to(
          chef.userId.toString()
        ).emit(
          'newNotification',
          notification,
        );
      }
    }

    //
    // 🔥 GET ALL REVIEWS
    //
    const reviews =
      await RecipeReview.find({
        recipeId,
      });

    //
    // 🔥 AVG
    //
    const avg =
      reviews.reduce(
        (sum, item) =>
          sum + item.rating,
        0,
      ) / reviews.length;

    //
    // 🔥 UPDATE RECIPE
    //
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

    console.log(
      "ADD RECIPE REVIEW ERROR =>",
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

//
// ✅ GET REVIEWS
//
const getRecipeReviews =
async (req, res) => {

  try {

    const { recipeId } =
      req.params;

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

//
// ✅ DELETE REVIEW
//
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

