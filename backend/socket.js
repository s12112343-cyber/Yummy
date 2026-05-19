const socketIo = require('socket.io');
const Message = require('./models/Message');
const { createNotification } = require('./services/notificationService');

let io;
// map of userId -> peerId they are currently viewing in chat
const activeChatByUser = {};

module.exports = {
  init: (server) => {
    io = socketIo(server, {
      cors: {
        origin: '*',
      },
    });

    io.on('connection', (socket) => {
      console.log('Socket Connected');

      // join generic chef room (existing behavior)
      socket.on('joinChefRoom', (chefId) => {
        socket.join(chefId);
        console.log('Chef joined room:', chefId);
      });

      // join personal room identified by userId
      socket.on('join', (userId) => {
        try {
          if (userId) {
            socket.join(userId);
            console.log('User joined room:', userId);
          }
        } catch (e) {}
      });

      // track which chat (peerId) a user is actively viewing
      socket.on('activeChat', ({ userId, peerId }) => {
        try {
          if (userId) {
            activeChatByUser[userId] = peerId || null;
            // console.log(`User ${userId} active chat: ${peerId}`);
          }
        } catch (e) {}
      });

      socket.on('clearActiveChat', (userId) => {
        try {
          if (userId && activeChatByUser[userId]) {
            delete activeChatByUser[userId];
          }
        } catch (e) {}
      });

      // handle private messages: persist then emit
      socket.on('privateMessage', async (payload) => {
        try {
          const { from, to, text, createdAt } = payload || {};
          if (!from || !to || !text) {
            console.warn('Invalid privateMessage payload:', payload);
            return;
          }

          console.log(`📨 Message from ${from} to ${to}: "${text}"`);
          console.log(`   Payload types: from=${typeof from}, to=${typeof to}`);

          const msg = await Message.create({ from, to, text, createdAt });

          console.log(`✅ Saved to DB with _id: ${msg._id}, from: ${msg.from}, to: ${msg.to}`);

          // emit to recipient and sender rooms
          try {
            io.to(to).emit('privateMessage', msg.toObject());
            io.to(from).emit('privateMessage', msg.toObject());
            console.log('✅ Message emitted to both rooms');
          } catch (e) {
            console.error('socket emit error', e.message);
          }

          // create a push notification for the recipient about the new message
          try {
            const recipientActivePeer = activeChatByUser[to];
            const isRecipientViewingThisChat = recipientActivePeer && recipientActivePeer.toString() === from.toString();

            if (!isRecipientViewingThisChat) {
              createNotification({
                recipientId: to,
                actorId: from,
                type: 'message',
                title: 'New message',
                body: text?.toString().slice(0, 120) || 'You have a new message',
                extraPayload: { messageId: msg._id ? msg._id.toString() : '', from },
              }).catch((err) => console.warn('createNotification error', err?.message || err));
            } else {
              // Recipient is actively viewing the chat with sender; skip push notification
              console.log(`Skipping push for ${to} (viewing chat with ${from})`);
            }
          } catch (e) {
            console.warn('Failed to create notification for message:', e.message);
          }
        } catch (e) {
          console.error('privateMessage handler error', e.message);
        }
      });

      socket.on('disconnect', () => {
        console.log('Disconnected');
      });
    });

    return io;
  },

  getIO: () => {
    if (!io) {
      throw new Error('Socket.io not initialized');
    }
    return io;
  },
};