const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({

  chefId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Chef',
    required: true,
  },

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },

  userName: {
    type: String,
    default: '',
  },

  userAvatar: {
    type: String,
    default: '',
  },

  rating: {
    type: Number,
    required: true,
  },

  comment: {
    type: String,
    default: '',
  },

  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
  },
read: {
  type: Boolean,
  default: false,
},
}, {
  timestamps: true,
});

module.exports =
  mongoose.model(
    'Review',
    reviewSchema,
  );