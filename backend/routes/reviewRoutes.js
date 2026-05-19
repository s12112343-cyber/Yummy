const express = require('express');

const router = express.Router();

const {

  addReview,
  getChefReviews,
  getAllReviewsForAdmin,
  approveReview,
  rejectReview,

} = require('../controllers/reviewController');

const {

  verifyToken,
  adminOnly,

} = require('../middleware/authMiddleware');


// ✅ USER
router.post(
  '/',
  verifyToken,
  addReview,
);


// ✅ GET APPROVED REVIEWS
router.get(
  '/chef/:chefId',
  getChefReviews,
);


// ✅ ADMIN
router.get(
  '/admin/all',
  verifyToken,
  adminOnly,
  getAllReviewsForAdmin,
);

router.put(
  '/admin/approve/:id',
  verifyToken,
  adminOnly,
  approveReview,
);

router.delete(
  '/admin/:id',
  verifyToken,
  adminOnly,
  rejectReview,
);

module.exports = router;