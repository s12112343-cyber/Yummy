const mongoose = require('mongoose');

const CommentSchema = new mongoose.Schema({
  authorName: { type: String, required: true },
  authorImageUrl: { type: String },
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

const PostSchema = new mongoose.Schema({
  authorId: { type: String, index: true },
  authorName: { type: String, required: true },
  authorImageUrl: { type: String },
  text: { type: String },
  imagePath: { type: String },
  calories: { type: Number },
  fat: { type: Number },
  carbs: { type: Number },
  protein: { type: Number },
  likedByUsers: { type: [String], default: [] },
  comments: { type: [CommentSchema], default: [] },
  publishedAt: { type: Date, default: Date.now },
  visibility: {
    type: String,
    enum: ['public', 'followers_only'],
    default: 'public',
    index: true,
  },
});

module.exports = mongoose.model('Post', PostSchema);
