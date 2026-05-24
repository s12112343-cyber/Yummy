const Notification = require("../models/Notification");

const getAuthUserId = (req) => {
  return (
    req.user?.userId ||
    req.user?.id ||
    req.user?._id
  )?.toString();
};

exports.getMyNotifications = async (req, res) => {
  try {
    const userId = getAuthUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const unreadOnly = req.query.unreadOnly === "true";

    const filter = {
      recipientId: userId,
    };

    if (unreadOnly) {
      filter.isRead = false;
    }

    const [notifications, unreadCount] = await Promise.all([
      Notification.find(filter)
        .sort({ createdAt: -1 })
        .lean(),

      Notification.countDocuments({
        recipientId: userId,
        isRead: false,
      }),
    ]);

    res.status(200).json({
      success: true,
      notifications,
      unreadCount,
    });
  } catch (error) {
    console.error("GET NOTIFICATIONS ERROR =>", error);

    res.status(500).json({
      success: false,
      message:
        error.message ||
        "Failed to load notifications",
    });
  }
};

exports.markNotificationAsRead = async (req, res) => {
  try {
    const userId = getAuthUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const { notificationId } = req.params;

    const notification = await Notification.findOneAndUpdate(
      {
        _id: notificationId,
        recipientId: userId,
      },
      {
        isRead: true,
        readAt: new Date(),
      },
      {
        new: true,
      }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    res.status(200).json({
      success: true,
      notification,
    });
  } catch (error) {
    console.error("MARK READ ERROR =>", error);

    res.status(500).json({
      success: false,
      message:
        error.message ||
        "Failed to update notification",
    });
  }
};

exports.markAllNotificationsAsRead = async (req, res) => {
  try {
    const userId = getAuthUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    await Notification.updateMany(
      {
        recipientId: userId,
        isRead: false,
      },
      {
        isRead: true,
        readAt: new Date(),
      }
    );

    res.status(200).json({
      success: true,
      message: "Notifications marked as read",
    });
  } catch (error) {
    console.error("MARK ALL ERROR =>", error);

    res.status(500).json({
      success: false,
      message:
        error.message ||
        "Failed to update notifications",
    });
  }
};