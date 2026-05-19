const User = require("../models/User");
const UserProfile = require("../models/UserProfile");
const UserFollow = require("../models/UserFollow");

/**
 * Toggle follow: add to UserFollow or remove if already following
 */
exports.toggleFollow = async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    const { targetUserId } = req.body;

    if (!targetUserId) {
      return res.status(400).json({
        message: "targetUserId is required",
      });
    }

    if (currentUserId.toString() === targetUserId.toString()) {
      return res.status(400).json({
        message: "Cannot follow yourself",
      });
    }

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    // Check if follow relationship exists
    const existingFollow = await UserFollow.findOne({
      follower_id: currentUserId,
      following_id: targetUserId,
    });

    if (existingFollow) {
      // Unfollow: delete the relationship
      await UserFollow.deleteOne({
        follower_id: currentUserId,
        following_id: targetUserId,
      });

      // Get updated counts
      const followerCount = await UserFollow.countDocuments({
        following_id: targetUserId,
      });
      const followingCount = await UserFollow.countDocuments({
        follower_id: currentUserId,
      });

      return res.status(200).json({
        message: "Unfollowed successfully",
        isFollowing: false,
        followerCount,
        followingCount,
      });
    } else {
      // Follow: create new relationship
      await UserFollow.create({
        follower_id: currentUserId,
        following_id: targetUserId,
      });

      // Get updated counts
      const followerCount = await UserFollow.countDocuments({
        following_id: targetUserId,
      });
      const followingCount = await UserFollow.countDocuments({
        follower_id: currentUserId,
      });

      return res.status(200).json({
        message: "Followed successfully",
        isFollowing: true,
        followerCount,
        followingCount,
      });
    }
  } catch (error) {
    console.error("❌ Error in toggleFollow:", error.message);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get followers list with details
 */
exports.getFollowers = async (req, res) => {
  try {
    const { userId } = req.params;

    // Find all users who follow this user
    const follows = await UserFollow.find({
      following_id: userId,
    })
      .populate({
        path: "follower_id",
        select: "name email _id",
      })
      .lean();

    if (!follows) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    const followers = await Promise.all(
      follows.map(async (follow) => {
        const profile = await UserProfile.findOne({
          user_id: follow.follower_id._id,
        }).lean();

        return {
          id: follow.follower_id._id,
          name: follow.follower_id.name,
          email: follow.follower_id.email,
          profileImage: profile?.image
            ? `${baseUrl}${profile.image}`
            : "",
        };
      })
    );

    res.status(200).json({
      followers,
      count: followers.length,
    });
  } catch (error) {
    console.error("❌ Error in getFollowers:", error.message);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get following list with details
 */
exports.getFollowing = async (req, res) => {
  try {
    const { userId } = req.params;

    // Find all users that this user follows
    const follows = await UserFollow.find({
      follower_id: userId,
    })
      .populate({
        path: "following_id",
        select: "name email _id",
      })
      .lean();

    if (!follows) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    const following = await Promise.all(
      follows.map(async (follow) => {
        const profile = await UserProfile.findOne({
          user_id: follow.following_id._id,
        }).lean();

        return {
          id: follow.following_id._id,
          name: follow.following_id.name,
          email: follow.following_id.email,
          profileImage: profile?.image
            ? `${baseUrl}${profile.image}`
            : "",
        };
      })
    );

    res.status(200).json({
      following,
      count: following.length,
    });
  } catch (error) {
    console.error("❌ Error in getFollowing:", error.message);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Check if current user follows target user
 */
exports.checkFollowStatus = async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    const { targetUserId } = req.params;

    const follow = await UserFollow.findOne({
      follower_id: currentUserId,
      following_id: targetUserId,
    }).lean();

    const isFollowing = follow !== null;

    res.status(200).json({
      isFollowing,
    });
  } catch (error) {
    console.error("❌ Error in checkFollowStatus:", error.message);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/**
 * Get user stats (followers/following count)
 */
exports.getUserStats = async (req, res) => {
  try {
    const { userId } = req.params;

    const followerCount = await UserFollow.countDocuments({
      following_id: userId,
    });

    const followingCount = await UserFollow.countDocuments({
      follower_id: userId,
    });

    res.status(200).json({
      userId,
      followerCount,
      followingCount,
    });
  } catch (error) {
    console.error("❌ Error in getUserStats:", error.message);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
