const express = require('express');
const router = express.Router();
const feedbackController = require('../controllers/feedbackController');
const { verifyToken, adminOnly } = require('../middleware/authMiddleware');

// POST /api/feedback
router.post('/', feedbackController.createFeedback);

// GET /api/feedback/admin/all
router.get('/admin/all', verifyToken, adminOnly, feedbackController.listFeedbacks);

// PATCH /api/feedback/admin/mark-read/:id
router.patch('/admin/mark-read/:id', verifyToken, adminOnly, feedbackController.markFeedbackRead);

// DELETE /api/feedback/admin/:id
router.delete('/admin/:id', verifyToken, adminOnly, feedbackController.deleteFeedback);

// PATCH /api/feedback/admin/mark-read-all
router.patch('/admin/mark-read-all', verifyToken, adminOnly, feedbackController.markAllRead);

module.exports = router;
