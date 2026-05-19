const express = require('express');
const router = express.Router();
const upload = require('../upload');

const {
  getchef,
  getChefById,
  createChef,
  deleteChef,
  getMyChef,
  updateChef,
  updateProfileImage,
  updateCoverImage,

  // ✅ NEW
  updateEmail,
  updatePassword,

} = require('../controllers/chefController');

const { adminOnly, verifyToken } = require('../middleware/authMiddleware');

/// 🔥 حطي /me أول
router.get('/me', verifyToken, getMyChef);

/// 🔵 باقي الراوتات
router.get('/', getchef);
router.get('/:id', getChefById);

router.post('/create', adminOnly, createChef);
router.delete('/:id', adminOnly, deleteChef);

router.patch('/update', verifyToken, updateChef);

router.patch('/image', verifyToken, upload.single('image'), updateProfileImage);

router.patch('/cover', verifyToken, upload.single('coverImage'), updateCoverImage);
// ✅ UPDATE EMAIL
router.patch(
  '/update-email',
  verifyToken,
  updateEmail,
);

// ✅ UPDATE PASSWORD
router.patch(
  '/update-password',
  verifyToken,
  updatePassword,
);
module.exports = router;