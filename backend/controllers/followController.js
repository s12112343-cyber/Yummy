const User = require("../models/User");
const UserProfile = require("../models/UserProfile");
const UserFollow = require("../models/UserFollow");
const { createNotification } = require("../services/notificationService");

const toObjectIdString = (value) => value?.toString?.() ?? `${value ?? ""}`;

const buildProfileImageUrl = (req, imagePath) => {
  const raw = (imagePath || "").toString().trim();
  if (!raw) return "";

  const baseUrl = `${req.protocol}://${req.get("host")}`;
  if (raw.startsWith("http://") || raw.startsWith("https://")) {
    return raw;
  }

  return raw.startsWith("/") ? `${baseUrl}${raw}` : `${baseUrl}/${raw}`;
};

/**
 * Toggle follow: create or remove a UserFollow row.
 */
exports.toggleFollow = async (req, res) => {
  try {
    const currentUserId = toObjectIdString(req.user.userId);
    const { targetUserId } = req.body;
    const normalizedTargetUserId = toObjectIdString(targetUserId).trim();

    if (!normalizedTargetUserId) {
      return res.status(400).json({ message: "targetUserId is required" });
    }

    if (currentUserId === normalizedTargetUserId) {
      return res.status(400).json({ message: "Cannot follow yourself" });
    }

    const targetUser = await User.findById(normalizedTargetUserId).select("_id");
    if (!targetUser) {
      return res.status(404).json({ message: "User not found" });
    }

    const existingFollow = await UserFollow.findOne({
      follower_id: currentUserId,
      following_id: normalizedTargetUserId,
    });

    let isFollowing = false;

    if (existingFollow) {
      await UserFollow.deleteOne({ _id: existingFollow._id });
      isFollowing = false;
    } else {
      await UserFollow.create({
        follower_id: currentUserId,
        following_id: normalizedTargetUserId,
      });
      isFollowing = true;

      const actor = await User.findById(currentUserId).select("name").lean();
      await createNotification({
        recipientId: normalizedTargetUserId,
        actorId: currentUserId,
        type: "follow",
        title: "New follower",
        body: `${actor?.name || 'Someone'} started following you`,
      });
    }

    const followerCount = await UserFollow.countDocuments({
      following_id: normalizedTargetUserId,
    });
    const followingCount = await UserFollow.countDocuments({
      follower_id: currentUserId,
    });

    return res.status(200).json({
      message: isFollowing ? "Followed successfully" : "Unfollowed successfully",
      isFollowing,
      followerCount,
      followingCount,
    });
  } catch (error) {
    console.error("❌ Error in toggleFollow:", error.message);
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get followers list with details.
 */
exports.getFollowers = async (req, res) => {
  try {
    const { userId } = req.params;

    const targetUser = await User.findById(userId).select("_id").lean();
    if (!targetUser) {
      return res.status(404).json({ message: "User not found" });
    }

    const follows = await UserFollow.find({ following_id: targetUser._id })
      .populate({ path: "follower_id", select: "name email _id" })
      .lean();

    const followers = await Promise.all(
      follows.map(async (follow) => {
        const profile = await UserProfile.findOne({ user_id: follow.follower_id._id })
          .select("image")
          .lean();

        return {
          id: follow.follower_id._id,
          name: follow.follower_id.name,
          email: follow.follower_id.email,
          profileImage: buildProfileImageUrl(req, profile?.image),
        };
      })
    );

    return res.status(200).json({ followers, count: followers.length });
  } catch (error) {
    console.error("❌ Error in getFollowers:", error.message);
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get following list with details.
 */
exports.getFollowing = async (req, res) => {
  try {
    const { userId } = req.params;

    const sourceUser = await User.findById(userId).select("_id").lean();
    if (!sourceUser) {
      return res.status(404).json({ message: "User not found" });
    }

    const follows = await UserFollow.find({ follower_id: sourceUser._id })
      .populate({ path: "following_id", select: "name email _id" })
      .lean();

    const following = await Promise.all(
      follows.map(async (follow) => {
        const profile = await UserProfile.findOne({ user_id: follow.following_id._id })
          .select("image")
          .lean();

        return {
          id: follow.following_id._id,
          name: follow.following_id.name,
          email: follow.following_id.email,
          profileImage: buildProfileImageUrl(req, profile?.image),
        };
      })
    );

    return res.status(200).json({ following, count: following.length });
  } catch (error) {
    console.error("❌ Error in getFollowing:", error.message);
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Check if current user follows target user.
 */
exports.checkFollowStatus = async (req, res) => {
  try {
    const currentUserId = toObjectIdString(req.user.userId);
    const { targetUserId } = req.params;
    const normalizedTargetUserId = toObjectIdString(targetUserId).trim();

    const isFollowing = !!(await UserFollow.findOne({
      follower_id: currentUserId,
      following_id: normalizedTargetUserId,
    }).lean());

    return res.status(200).json({ isFollowing });
  } catch (error) {
    console.error("❌ Error in checkFollowStatus:", error.message);
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get user stats (followers/following count).
 */
exports.getUserStats = async (req, res) => {
  try {
    const { userId } = req.params;

    const targetUser = await User.findById(userId).select("_id").lean();
    if (!targetUser) {
      return res.status(404).json({ message: "User not found" });
    }

    const followerCount = await UserFollow.countDocuments({
      following_id: targetUser._id,
    });
    const followingCount = await UserFollow.countDocuments({
      follower_id: targetUser._id,
    });

    return res.status(200).json({
      userId: targetUser._id,
      followerCount,
      followingCount,
    });
  } catch (error) {
    console.error("❌ Error in getUserStats:", error.message);
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
