const express = require('express');

const router = express.Router();

const {

  addReview,
  getChefReviews,
  getAllReviewsForAdmin,
  approveReview,
  rejectReview,
  deleteReview,
  markReviewRead,

} = require('../controllers/reviewController');

const {

  verifyToken,
  adminOnly,

} = require('../middleware/authMiddleware');


// ✅ USER ADD REVIEW
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

router.put(
  '/admin/reject/:id',
  verifyToken,
  adminOnly,
  rejectReview,
);

router.delete(
  '/admin/delete/:id',
  verifyToken,
  adminOnly,
  deleteReview,
);
router.patch(
  '/read/:id',
  verifyToken,
  adminOnly,
  markReviewRead,
);
module.exports = router;