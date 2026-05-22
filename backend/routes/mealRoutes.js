const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");
const {
	addMealsBatch,
	getDailySummary,
	getPeriodSummary,
	analyzeQuickAddMeal,
	analyzePhotoAI,
	getPreviousMeals,
	updateDailyWater,
	fetchIngredientsForMeal,
} = require("../controllers/mealController");
const upload = require("../middleware/aiMealUploadMiddleware");

router.use("/", require("./imageMealRoutes"));

router.post("/batch", verifyToken, apiLimiter, addMealsBatch);
router.get("/summary", verifyToken, apiLimiter, getDailySummary);
router.get("/summary/period", verifyToken, apiLimiter, getPeriodSummary);
router.post("/quick-add/analyze", verifyToken, apiLimiter, analyzeQuickAddMeal);
router.post("/analyze-photo-ai", verifyToken, apiLimiter, upload.single("image"), analyzePhotoAI);
router.get("/previous", verifyToken, apiLimiter, getPreviousMeals);
router.get("/saved-foods", verifyToken, apiLimiter, getPreviousMeals);
router.patch("/water", verifyToken, apiLimiter, updateDailyWater);
router.post("/fetch-ingredients", verifyToken, apiLimiter, fetchIngredientsForMeal);

module.exports = router;
