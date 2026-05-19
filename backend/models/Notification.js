const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    recipientId: {
      type: String,
      required: true,
      index: true,
    },
    actorId: {
      type: String,
      default: "",
      index: true,
    },
    actorName: {
      type: String,
      default: "User",
    },
    actorImageUrl: {
      type: String,
      default: "",
    },
    type: {
      type: String,
      enum: ["like", "comment", "follow", "message"],
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
    },
    body: {
      type: String,
      required: true,
    },
    postId: {
      type: String,
      default: "",
      index: true,
    },
    commentText: {
      type: String,
      default: "",
    },
    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
    readAt: {
      type: Date,
      default: null,
    },
    payload: {
      type: Object,
      default: {},
    },
  },
  {
    timestamps: true,
  }
);

notificationSchema.index({ recipientId: 1, createdAt: -1 });

module.exports = mongoose.model("Notification", notificationSchema);