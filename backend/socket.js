const socketIO = require("socket.io");

const Message = require("./models/Message");
const {
  createNotification,
} = require("./services/notificationService");

let io;

// userId -> peerId currently opened in chat
const activeChatByUser = {};

module.exports = {
  init: (server) => {
    io = socketIO(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"],
      },
    });

    io.on("connection", (socket) => {
      console.log("🔥 USER CONNECTED");

      //
      // CHEF ROOM
      //
      socket.on("joinChefRoom", (chefId) => {
        try {
          if (!chefId) return;

          socket.join(chefId.toString());

          console.log("CHEF JOINED =>", chefId);
        } catch (e) {
          console.error("joinChefRoom error:", e.message);
        }
      });

      //
      // USER ROOM - old/new support
      // frontend may call: join
      //
      socket.on("join", (userId) => {
        try {
          if (!userId) return;

          socket.join(userId.toString());

          console.log("USER JOINED =>", userId);
        } catch (e) {
          console.error("join error:", e.message);
        }
      });

      //
      // USER ROOM - second code support
      // frontend may call: joinUserRoom
      //
      socket.on("joinUserRoom", (userId) => {
        try {
          if (!userId) return;

          socket.join(userId.toString());

          console.log("USER JOINED ROOM =>", userId);
        } catch (e) {
          console.error("joinUserRoom error:", e.message);
        }
      });

      //
      // Track active chat
      //
      socket.on("activeChat", ({ userId, peerId }) => {
        try {
          if (!userId) return;

          activeChatByUser[userId.toString()] =
            peerId ? peerId.toString() : null;

          console.log(
            `ACTIVE CHAT => user ${userId} with ${peerId}`
          );
        } catch (e) {
          console.error("activeChat error:", e.message);
        }
      });

      //
      // Clear active chat
      //
      socket.on("clearActiveChat", (userId) => {
        try {
          if (!userId) return;

          delete activeChatByUser[userId.toString()];

          console.log("CLEAR ACTIVE CHAT =>", userId);
        } catch (e) {
          console.error("clearActiveChat error:", e.message);
        }
      });

      //
      // PRIVATE MESSAGE
      //
      socket.on("privateMessage", async (payload) => {
        try {
          const { from, to, text, createdAt } = payload || {};

          if (!from || !to || !text) {
            console.warn("Invalid privateMessage payload:", payload);
            return;
          }

          const fromId = from.toString();
          const toId = to.toString();

          console.log(
            `📨 Message from ${fromId} to ${toId}: "${text}"`
          );

          const msg = await Message.create({
            from: fromId,
            to: toId,
            text,
            createdAt,
          });

          const messageObject = msg.toObject();

          //
          // Emit to recipient and sender rooms
          //
          io.to(toId).emit("privateMessage", messageObject);
          io.to(fromId).emit("privateMessage", messageObject);

          console.log("✅ Message saved and emitted");

          //
          // Create notification if recipient is not viewing this chat
          //
          const recipientActivePeer =
            activeChatByUser[toId];

          const isRecipientViewingThisChat =
            recipientActivePeer &&
            recipientActivePeer.toString() === fromId;

          if (!isRecipientViewingThisChat) {
            createNotification({
              recipientId: toId,
              actorId: fromId,
              type: "message",
              title: "New message",
              body:
                text.toString().slice(0, 120) ||
                "You have a new message",
              extraPayload: {
                messageId: msg._id
                  ? msg._id.toString()
                  : "",
                from: fromId,
              },
            }).catch((err) => {
              console.warn(
                "createNotification error:",
                err?.message || err
              );
            });
          } else {
            console.log(
              `Skipping notification for ${toId}, user is viewing chat with ${fromId}`
            );
          }
        } catch (e) {
          console.error(
            "privateMessage handler error:",
            e.message
          );
        }
      });

      socket.on("disconnect", () => {
        console.log("❌ USER DISCONNECTED");
      });
    });

    return io;
  },

  getIO: () => {
    if (!io) {
      throw new Error("Socket.io not initialized!");
    }

    return io;
  },
};