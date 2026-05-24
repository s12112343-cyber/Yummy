const mongoose = require('mongoose');

const notificationRequestSchema = new mongoose.Schema(
  {
    chef: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chef',
    },

    chefName: {
      type: String,
      default: '',
    },

    title: {
      type: String,
      required: true,
    },

    message: {
      type: String,
      required: true,
    },

    status: {
      type: String,

      enum: [
        'pending',
        'approved',
        'rejected',
      ],

      default: 'pending',
    },

    read: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model(
  'NotificationRequest',
  notificationRequestSchema
);