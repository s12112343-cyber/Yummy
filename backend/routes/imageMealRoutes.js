const express = require("express");

const router = express.Router();

const { verifyToken } = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");
const upload = require("../middleware/aiMealUploadMiddleware");
const { analyzeImageAI } = require("../controllers/imageMealController");

router.post(
  "/analyze-image-ai",
  verifyToken,
  apiLimiter,
  upload.single("image"),
  analyzeImageAI
);

module.exports = router;
