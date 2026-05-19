const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Post = require('../models/Post');
const User = require('../models/User');
const UserProfile = require('../models/UserProfile');
const UserFollow = require('../models/UserFollow');
const { createNotification } = require('../services/notificationService');

function _normalizeVisibility(raw) {
  const v = (raw || 'public').toString().trim().toLowerCase();
  return v === 'followers_only' ? 'followers_only' : 'public';
}

async function loadFollowingIdsSet(viewerIdStr) {
  if (!viewerIdStr || !mongoose.Types.ObjectId.isValid(viewerIdStr)) {
    return new Set();
  }
  const rows = await UserFollow.find({
    follower_id: new mongoose.Types.ObjectId(viewerIdStr),
  })
    .select('following_id')
    .lean();
  return new Set(rows.map((r) => r.following_id.toString()));
}

function postVisibleToViewer(post, viewerIdStr, followingIdSet) {
  const vis = post.visibility || 'public';
  if (vis !== 'followers_only') return true;
  const aid = post.authorId?.toString();
  if (!aid) return true;
  if (viewerIdStr && aid === viewerIdStr) return true;
  return followingIdSet.has(aid);
}

async function assertPostVisibleToUser(postDoc, viewerIdStr) {
  const vis = postDoc.visibility || 'public';
  if (vis !== 'followers_only') return true;
  const aid = postDoc.authorId?.toString();
  if (!viewerIdStr) return false;
  if (aid === viewerIdStr) return true;
  if (!aid) return true;
  if (
    !mongoose.Types.ObjectId.isValid(viewerIdStr) ||
    !mongoose.Types.ObjectId.isValid(aid)
  ) {
    return false;
  }
  const exists = await UserFollow.exists({
    follower_id: new mongoose.Types.ObjectId(viewerIdStr),
    following_id: new mongoose.Types.ObjectId(aid),
  });
  return !!exists;
}

// Helper to save uploaded buffer to disk and return public path
async function saveUpload(file) {
  if (!file) return null;
  const uploadsDir = path.join(__dirname, '..', 'uploads');
  if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
  const filename = `${Date.now()}-${Math.floor(Math.random() * 1000000)}-${file.originalname}`;
  const filePath = path.join(uploadsDir, filename);
  await fs.promises.writeFile(filePath, file.buffer);
  console.log(`📸 Image saved: /uploads/${filename}`);
  return `/uploads/${filename}`;
}

function _normalizeIncomingImageUrl(raw) {
  if (!raw || typeof raw !== 'string') return raw;
  try {
    const uri = new URL(raw);
    if (uri.pathname && uri.pathname.startsWith('/uploads')) {
      return uri.pathname + (uri.search || '');
    }
    return raw;
  } catch (_) {
    return raw;
  }
}

function _buildFullUrl(req, value) {
  if (!value || typeof value !== 'string') return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  const origin = `${req.protocol}://${req.get('host')}`;
  if (value.startsWith('/')) return `${origin}${value}`;
  return `${origin}/${value}`;
}

exports.createPost = async (req, res, next) => {
  try {
    const { text, calories, fat, carbs, protein, authorName, authorImageUrl } = req.body;
    const visibility = _normalizeVisibility(req.body.visibility);
    const authorId = req.user?.userId?.toString();

    console.log(`📝 Creating post: text=${text ? text.substring(0, 50) : 'none'}, image=${req.file ? 'yes' : 'no'}`);

    const imagePath = req.file ? await saveUpload(req.file) : undefined;
    // Normalize incoming author image: if client sent an absolute URL to /uploads,
    // store only the path (so host/ip changes won't require DB migration).
    const normalizedAuthorImage = _normalizeIncomingImageUrl(authorImageUrl);

    const post = new Post({
      authorId: authorId || undefined,
      authorName: authorName || 'Unknown',
      authorImageUrl: normalizedAuthorImage || undefined,
      text: text || '',
      imagePath,
      calories: calories ? Number(calories) : undefined,
      fat: fat ? Number(fat) : undefined,
      carbs: carbs ? Number(carbs) : undefined,
      protein: protein ? Number(protein) : undefined,
      visibility,
    });

    await post.save();

    const postObj = post.toObject();
    postObj.authorImageUrl = _buildFullUrl(req, postObj.authorImageUrl || '');
    postObj.imagePath = _buildFullUrl(req, postObj.imagePath || '');

    console.log(`✅ Post created with ID: ${post._id}`);
    res.status(201).json({ error: false, post: postObj });
  } catch (err) {
    console.error(`❌ Error creating post: ${err.message}`);
    next(err);
  }
};

exports.getPosts = async (req, res, next) => {
  try {
    const viewerId = req.user?.userId?.toString();
    const followingIdSet = await loadFollowingIdsSet(viewerId);

    const posts = await Post.find().sort({ publishedAt: -1 }).lean();
    const visible = posts.filter((p) =>
      postVisibleToViewer(p, viewerId, followingIdSet),
    );
    console.log(`📋 Retrieved ${posts.length} posts (${visible.length} visible to viewer)`);

    const baseOrigin = `${req.protocol}://${req.get('host')}`;
    const transformed = visible.map((p) => {
      const copy = { ...p };
      copy.imagePath = copy.imagePath
        ? (copy.imagePath.startsWith('http') ? copy.imagePath : `${baseOrigin}${copy.imagePath.startsWith('/') ? copy.imagePath : `/${copy.imagePath}`}`)
        : '';
      copy.authorImageUrl = copy.authorImageUrl
        ? (copy.authorImageUrl.startsWith('http') ? copy.authorImageUrl : `${baseOrigin}${copy.authorImageUrl.startsWith('/') ? copy.authorImageUrl : `/${copy.authorImageUrl}`}`)
        : '';
      return copy;
    });

    res.json({ error: false, posts: transformed });
  } catch (err) {
    console.error(`❌ Error fetching posts: ${err.message}`);
    next(err);
  }
};

exports.toggleLike = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.userId?.toString();

    if (!userId) {
      return res.status(401).json({ error: true, message: 'Unauthorized' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ error: true, message: 'Post not found' });
    }

    const canSee = await assertPostVisibleToUser(post, userId);
    if (!canSee) {
      return res.status(404).json({ error: true, message: 'Post not found' });
    }

    const likedByUsers = Array.isArray(post.likedByUsers) ? post.likedByUsers : [];
    const likeIndex = likedByUsers.indexOf(userId);

    if (likeIndex >= 0) {
      likedByUsers.splice(likeIndex, 1);
      console.log(`👎 User ${userId} removed like from post ${postId}`);
    } else {
      likedByUsers.push(userId);
      console.log(`👍 User ${userId} liked post ${postId}`);
    }

    post.likedByUsers = likedByUsers;
    await post.save();

    if (likeIndex < 0 && post.authorId) {
      const actor = await User.findById(userId).select('name').lean();
      await createNotification({
        recipientId: post.authorId.toString(),
        actorId: userId,
        type: 'like',
        title: 'New like',
        body: `${actor?.name || 'Someone'} liked your post`,
        postId: post._id.toString(),
      });
    }

    res.json({
      error: false,
      message: likeIndex >= 0 ? 'Like removed' : 'Like added',
      post,
      likeCount: likedByUsers.length,
      likedByMe: likeIndex < 0,
    });
  } catch (err) {
    console.error(`❌ Error toggling like: ${err.message}`);
    next(err);
  }
};

exports.addComment = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const { authorName, authorImageUrl, text } = req.body;
    const userId = req.user?.userId?.toString();

    console.log(`💬 Adding comment to post ${postId}`);

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ error: true, message: 'Post not found' });
    }

    const canSee = await assertPostVisibleToUser(post, userId);
    if (!canSee) {
      return res.status(404).json({ error: true, message: 'Post not found' });
    }

    post.comments.push({
      authorName: authorName || 'User',
      authorImageUrl: _normalizeIncomingImageUrl(authorImageUrl) || undefined,
      text: text || '',
      createdAt: new Date(),
    });

    await post.save();

    if (post.authorId) {
      const actor = await User.findById(userId).select('name').lean();
      const commentPreview = (text || '').toString().trim().slice(0, 80);
      await createNotification({
        recipientId: post.authorId.toString(),
        actorId: userId,
        type: 'comment',
        title: 'New comment',
        body: `${actor?.name || 'Someone'} commented: ${commentPreview || 'Nice post'}`,
        postId: post._id.toString(),
        commentText: text || '',
      });
    }

    // Return post with full URLs
    const postObj = post.toObject();
    postObj.authorImageUrl = _buildFullUrl(req, postObj.authorImageUrl || '');
    postObj.imagePath = _buildFullUrl(req, postObj.imagePath || '');

    console.log(`✅ Comment added, total: ${post.comments.length}`);
    res.status(201).json({ error: false, post: postObj, commentCount: post.comments.length });
  } catch (err) {
    console.error(`❌ Error adding comment: ${err.message}`);
    next(err);
  }
};

exports.deletePost = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.userId?.toString();

    if (!userId) {
      return res.status(401).json({ error: true, message: 'Unauthorized' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ error: true, message: 'Post not found' });
    }

    let canDelete = post.authorId?.toString() === userId;

    // Fallback for legacy posts created before authorId existed.
    if (!canDelete && !post.authorId && post.authorName) {
      const user = await User.findById(userId).select('name').lean();
      const myName = (user?.name || '').toString().trim().toLowerCase();
      const postName = post.authorName.toString().trim().toLowerCase();
      canDelete = myName.length > 0 && myName === postName;
    }

    if (!canDelete) {
      return res
        .status(403)
        .json({ error: true, message: 'Only the post owner can delete this post' });
    }

    await Post.findByIdAndDelete(postId);
    return res.json({ error: false, message: 'Post deleted successfully', postId });
  } catch (err) {
    console.error(`❌ Error deleting post: ${err.message}`);
    next(err);
  }
};
