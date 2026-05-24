const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");

const {
  getMyNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = require("../controllers/notificationController");

//
// GET MY NOTIFICATIONS
// الجديد: /notifications
// القديم: /notifications/my-notifications
//
router.get(
  "/",
  verifyToken,
  apiLimiter,
  getMyNotifications
);

router.get(
  "/my-notifications",
  verifyToken,
  apiLimiter,
  getMyNotifications
);

//
// MARK ALL NOTIFICATIONS AS READ
// /notifications/read-all
//
router.patch(
  "/read-all",
  verifyToken,
  apiLimiter,
  markAllNotificationsAsRead
);

//
// MARK ONE NOTIFICATION AS READ
// الجديد: /notifications/:notificationId/read
// القديم: /notifications/read/:notificationId
//
router.patch(
  "/:notificationId/read",
  verifyToken,
  apiLimiter,
  markNotificationAsRead
);

router.patch(
  "/read/:notificationId",
  verifyToken,
  apiLimiter,
  markNotificationAsRead
);

module.exports = router;