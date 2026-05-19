const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');

// Save a message (also emits over socket when possible)
router.post('/messages', chatController.saveMessage);

// Get conversation between two users (a and b are user ids)
router.get('/conversation/:a/:b', chatController.getConversation);

// Delete a full conversation between two users
router.delete('/conversation/:a/:b', chatController.deleteConversation);

// List user conversations with last message and unread count
router.get('/conversations/:userId', chatController.getUserConversations);

// Mark messages as read
router.post('/mark-read', chatController.markAsRead);

module.exports = router;
