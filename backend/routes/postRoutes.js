const express = require('express');
const router = express.Router();
const upload = require('../middleware/uploadMiddleware');
const { verifyToken } = require('../middleware/authMiddleware');
const postController = require('../controllers/postController');

router.get('/', verifyToken, postController.getPosts);
router.post('/', verifyToken, upload.single('image'), postController.createPost);
router.post('/:postId/like', verifyToken, postController.toggleLike);
router.post('/:postId/comment', verifyToken, postController.addComment);
router.delete('/:postId', verifyToken, postController.deletePost);

module.exports = router;
