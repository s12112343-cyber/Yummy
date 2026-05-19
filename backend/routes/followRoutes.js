const express = require("express");
const router = express.Router();
const { verifyToken } = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");

const {
  toggleFollow,
  getFollowers,
  getFollowing,
  checkFollowStatus,
  getUserStats,
} = require("../controllers/followController");

// Toggle follow/unfollow
router.post("/toggle", verifyToken, apiLimiter, toggleFollow);

// Get followers list
router.get("/:userId/followers", verifyToken, apiLimiter, getFollowers);

// Get following list
router.get("/:userId/following", verifyToken, apiLimiter, getFollowing);

// Check if current user follows target user
router.get("/:targetUserId/status", verifyToken, checkFollowStatus);

// Get user stats (follower/following count)
router.get("/:userId/stats", verifyToken, getUserStats);

module.exports = router;
