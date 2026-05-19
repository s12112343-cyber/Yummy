const Notification = require("../models/Notification");
const User = require("../models/User");
const UserProfile = require("../models/UserProfile");
const { sendPushNotification } = require("./firebaseAdmin");

async function buildActorSnapshot(actorId) {
  if (!actorId) {
    return {
      actorName: "User",
      actorImageUrl: "",
      fcmTokens: [],
    };
  }

  const [user, profile] = await Promise.all([
    User.findById(actorId).select("name fcmTokens").lean(),

    // نحاول نجيب صورة المستخدم من أكثر من اسم محتمل
    UserProfile.findOne({ user_id: actorId })
      .select("image image_url imageUrl profileImageUrl")
      .lean(),
  ]);

  const actorImageUrl =
    profile?.image_url ||
    profile?.imageUrl ||
    profile?.profileImageUrl ||
    profile?.image ||
    "";

  return {
    actorName: user?.name || "User",
    actorImageUrl,
    fcmTokens: user?.fcmTokens || [],
  };
}

async function createNotification({
  recipientId,
  actorId,
  type,
  title,
  body,
  postId = "",
  commentText = "",
  extraPayload = {},
}) {
  try {
    if (!recipientId || !type || !title || !body) {
      return null;
    }

    const recipientValue = recipientId.toString();
    const actorValue = actorId ? actorId.toString() : "";

    // ما نبعت إشعار للشخص على فعله هو نفسه
    if (actorValue && actorValue === recipientValue) {
      return null;
    }

    console.log(
      `[notificationService] Creating ${type} notification for ${recipientValue}`
    );

    const actorSnapshot = await buildActorSnapshot(actorValue);

    // keep actor image path as provided by snapshot (no URL conversion)
    const actorImageUrlAbsolute = actorSnapshot.actorImageUrl || '';

    // For message notifications we want a compact system-style title and
    // a body that shows "SenderName: message"
    let finalTitle = title;
    let finalBody = body;
    if (type === 'message') {
      finalTitle = 'New message';
      finalBody = `${actorSnapshot.actorName}: ${body ? body.toString().slice(0, 240) : ''}`;
    }

    const notification = await Notification.create({
      recipientId: recipientValue,
      actorId: actorValue,
      actorName: actorSnapshot.actorName,
      actorImageUrl: actorSnapshot.actorImageUrl,
      type,
      title: finalTitle,
      body: finalBody,
      postId: postId ? postId.toString() : "",
      commentText,
      payload: extraPayload,
    });

    console.log(
      `[notificationService] ✅ Notification saved: ${notification._id}`
    );

    const recipient = await User.findById(recipientValue)
      .select("fcmTokens")
      .lean();

    const tokens = Array.from(
      new Set((recipient?.fcmTokens || []).filter(Boolean))
    );

    console.log(
      `[notificationService] Found ${tokens.length} FCM tokens for recipient`
    );

    // debug: list tokens (shortened)
    if (tokens.length > 0) {
      console.log('[notificationService] tokens:', tokens.map(t => t.substring(0,8) + '...'));
    }

    if (tokens.length > 0) {
      try {
        console.log(
          `[notificationService] 📤 Sending FCM to ${tokens.length} tokens...`
        );
        const dataPayload = {
          notificationId: notification._id.toString(),
          recipientId: recipientValue,
          actorId: actorValue,
          actorName: actorSnapshot.actorName,
          actorImageUrl: actorSnapshot.actorImageUrl,
          type,
          postId: postId ? postId.toString() : "",
        };

        // Include message-specific fields when applicable
        if (type === 'message') {
          // include messageId if provided in extraPayload
          if (extraPayload && extraPayload.messageId) {
            dataPayload.messageId = extraPayload.messageId.toString();
          }
          // include the message text in data so client can show it directly
          dataPayload.messageText = body ? body.toString().slice(0, 240) : '';
        }

        const payload = {
          title: finalTitle,
          body: finalBody,
          data: dataPayload,
        };

        console.log('[notificationService] payload:', JSON.stringify(payload));

        const result = await sendPushNotification(tokens, payload);

        console.log(`[notificationService] 📤 FCM send result:`, result && result.response ? {
          successCount: result.response.successCount,
          failureCount: result.response.failureCount,
        } : result);
      } catch (error) {
        console.error(
          "[notificationService] Push notification failed:",
          error.message
        );
      }
    } else {
      console.warn(
        `[notificationService] ⚠️ No FCM tokens for recipient ${recipientValue}`
      );
    }

    return notification;
  } catch (error) {
    console.error(
      "[notificationService] Create notification failed:",
      error.message
    );
    return null;
  }
}

async function addDeviceToken(userId, token) {
  if (!userId || !token) {
    return;
  }

  console.log(
    `[notificationService] Adding device token for user ${userId}: ${token.substring(
      0,
      8
    )}...`
  );

  await User.updateOne(
    { _id: userId },
    {
      $addToSet: {
        fcmTokens: token,
      },
    }
  );
}

module.exports = {
  createNotification,
  addDeviceToken,
};