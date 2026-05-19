const express = require("express");
const router = express.Router();
const {
  createOrUpdateProfile,
  getMyProfile,
  updateMyStreak,
  getUsersStreaks,
  searchUsers,
} = require("../controllers/userProfileController");
const { verifyToken } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");

router.get("/me", verifyToken, getMyProfile);
router.get("/users-streaks", verifyToken, apiLimiter, getUsersStreaks);
router.get("/search", verifyToken, apiLimiter, searchUsers);
router.post("/", verifyToken, apiLimiter, upload.single("image"), createOrUpdateProfile);
router.patch("/streak", verifyToken, updateMyStreak);

module.exports = router;
