const express = require('express');
const router = express.Router();
const { verifyToken, adminOnly } = require('../middleware/authMiddleware');
const {
  getBanners,
  createBanner,
  updateBanner,
  deleteBanner,
} = require('../controllers/bannerController');

// ✅ Routes
router.get('/', getBanners);
router.post('/', verifyToken, adminOnly, createBanner);
router.put('/:id', verifyToken, adminOnly, updateBanner);
router.delete('/:id', verifyToken, adminOnly, deleteBanner);
module.exports = router;