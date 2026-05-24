const express = require('express');

const router = express.Router();

const controller = require(
  '../controllers/notificationRequestController'
);

const {
  verifyToken,
  adminOnly,
} = require('../middleware/authMiddleware');

//
// 🔥 CHEF SEND REQUEST
//
router.post(
  '/',
  verifyToken,
  controller.createRequest
);

//
// 🔥 ADMIN GET ALL
//
router.get(
  '/admin',
  verifyToken,
  adminOnly,
  controller.getAllRequests
);

//
// 🔥 APPROVE
//
router.patch(
  '/approve/:id',
  verifyToken,
  adminOnly,
  controller.approveNotificationRequest
);

//
// 🔥 REJECT
//
router.patch(
  '/reject/:id',
  verifyToken,
  adminOnly,
  controller.rejectRequest
);

module.exports = router;