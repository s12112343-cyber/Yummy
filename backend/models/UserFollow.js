const mongoose = require("mongoose");

const userFollowSchema = new mongoose.Schema(
  {
    follower_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    following_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
  },
  { timestamps: true }
);

// Create compound index to ensure unique follow relationships
userFollowSchema.index({ follower_id: 1, following_id: 1 }, { unique: true });

module.exports = mongoose.model("UserFollow", userFollowSchema);
