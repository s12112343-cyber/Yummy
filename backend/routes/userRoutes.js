const express = require('express');
const router = express.Router();
const { verifyToken, adminOnly } = require('../middleware/authMiddleware');
const {
  getAllUsers,
  deleteUser,
  searchUsers,
  toggleBanUser,
  createUser,
  updateUserRole
} = require('../controllers/userController');

// Routes
router.get('/all', verifyToken, adminOnly, getAllUsers);
router.get('/search', verifyToken, adminOnly, searchUsers);
router.post('/create', verifyToken, adminOnly, createUser);
router.patch('/:id/ban', verifyToken, adminOnly, toggleBanUser);
router.patch('/:id/role', verifyToken, adminOnly, updateUserRole);
router.delete('/:id', verifyToken, adminOnly, deleteUser);

module.exports = router;