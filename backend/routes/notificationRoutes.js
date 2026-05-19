const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");
const {
  getMyNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = require("../controllers/notificationController");

router.get("/", verifyToken, apiLimiter, getMyNotifications);
router.patch("/read-all", verifyToken, apiLimiter, markAllNotificationsAsRead);
router.patch("/:notificationId/read", verifyToken, apiLimiter, markNotificationAsRead);

module.exports = router;