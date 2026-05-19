const Notification = require("../models/Notification");

exports.getMyNotifications = async (req, res) => {
  try {
    const userId = req.user.userId.toString();
    const unreadOnly = req.query.unreadOnly === "true";

    const filter = {
      recipientId: userId,
    };

    if (unreadOnly) {
      filter.isRead = false;
    }

    const [notifications, unreadCount] = await Promise.all([
      Notification.find(filter).sort({ createdAt: -1 }).lean(),
      Notification.countDocuments({ recipientId: userId, isRead: false }),
    ]);

    res.status(200).json({
      notifications,
      unreadCount,
    });
  } catch (error) {
    console.error("Get notifications error:", error);
    res.status(500).json({ message: "Failed to load notifications" });
  }
};

exports.markNotificationAsRead = async (req, res) => {
  try {
    const userId = req.user.userId.toString();
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
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    res.status(200).json({ notification });
  } catch (error) {
    console.error("Mark notification read error:", error);
    res.status(500).json({ message: "Failed to update notification" });
  }
};

exports.markAllNotificationsAsRead = async (req, res) => {
  try {
    const userId = req.user.userId.toString();

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

    res.status(200).json({ message: "Notifications marked as read" });
  } catch (error) {
    console.error("Mark all notifications error:", error);
    res.status(500).json({ message: "Failed to update notifications" });
  }
};