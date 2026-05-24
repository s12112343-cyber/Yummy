const express = require('express');

const router = express.Router();

const {
  createBannerRequest,
  getBannerRequests,
  approveBannerRequest,
  rejectBannerRequest,
  getChefBanners,
  getMyBannerRequests,
  markBannerRequestRead,
} = require('../controllers/bannerRequestController');
const {
  verifyToken,
  adminOnly,
} = require('../middleware/authMiddleware');


/// CHEF
router.post(
  '/',
  verifyToken,
  createBannerRequest,
);


/// ADMIN
router.get(
  '/admin',
  verifyToken,
  adminOnly,
  getBannerRequests,
);

router.put(
  '/approve/:id',
  verifyToken,
  adminOnly,
  approveBannerRequest,
);

router.delete(
  '/:id',
  verifyToken,
  adminOnly,
  rejectBannerRequest,
);
router.get(
  '/my-requests',
  verifyToken,
  getMyBannerRequests,
);
router.patch(
  '/read/:id',
  verifyToken,
  adminOnly,
  markBannerRequestRead,
);
module.exports = router;