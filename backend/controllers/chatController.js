const Message = require('../models/Message');
const User = require('../models/User');
const UserProfile = require('../models/UserProfile');

exports.saveMessage = async (req, res) => {
  try {
    const { from, to, text, createdAt } = req.body;
    if (!from || !to || !text) {
      return res.status(400).json({ success: false, message: 'from, to and text are required' });
    }

    const msg = await Message.create({ from, to, text, createdAt });

    // emit via socket if available
    try {
      const io = req.app.get('io');
      io.to(to).emit('privateMessage', msg);
      io.to(from).emit('privateMessage', msg);
    } catch (e) {
      // ignore
    }

    return res.json({ success: true, message: 'Saved', data: msg });
  } catch (error) {
    console.error('chat.saveMessage error', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getConversation = async (req, res) => {
  try {
    const { a, b } = req.params;
    if (!a || !b) return res.status(400).json({ success: false, message: 'Missing params' });

    console.log(`🔍 getConversation query: a=${a}, b=${b}`);

    // Mark all incoming messages as read for user 'a'
    await Message.updateMany(
      { from: b, to: a, read: false },
      { read: true }
    );

    const messages = await Message.find({
      $or: [
        { from: a, to: b },
        { from: b, to: a },
      ],
    }).sort({ createdAt: 1 });

    console.log(`✅ Found ${messages.length} messages for conversation ${a} <-> ${b}`);
    
    if (messages.length > 0) {
      console.log('Sample message:', JSON.stringify(messages[0], null, 2));
    }

    return res.json({ success: true, messages });
  } catch (error) {
    console.error('chat.getConversation error', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteConversation = async (req, res) => {
  try {
    const { a, b } = req.params;
    if (!a || !b) return res.status(400).json({ success: false, message: 'Missing params' });

    console.log(`🗑️ deleteConversation request: a=${a}, b=${b}`);

    const result = await Message.deleteMany({
      $or: [
        { from: a, to: b },
        { from: b, to: a },
      ],
    });

    console.log(`✅ Deleted ${result.deletedCount || 0} messages for conversation ${a} <-> ${b}`);

    return res.json({
      success: true,
      message: 'Conversation deleted',
      deletedCount: result.deletedCount || 0,
    });
  } catch (error) {
    console.error('chat.deleteConversation error', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getUserConversations = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) return res.status(400).json({ success: false, message: 'Missing userId' });

    console.log(`💬 getUserConversations request: userId=${userId}`);

    const messages = await Message.find({
      $or: [{ from: userId }, { to: userId }],
    }).sort({ createdAt: -1 });

    const peerMap = new Map();
    const peerIds = new Set();

    for (const message of messages) {
      const from = message.from?.toString?.() ?? message.from;
      const to = message.to?.toString?.() ?? message.to;
      const peerId = from === userId ? to : from;
      if (!peerId || peerMap.has(peerId)) continue;

      peerIds.add(peerId);
      peerMap.set(peerId, {
        peerId,
        lastMessage: message.text ?? '',
        lastMessageAt: message.createdAt ?? null,
        unreadCount: 0,
      });
    }

    const unreadCounts = await Message.aggregate([
      { $match: { to: userId, read: false } },
      { $group: { _id: '$from', count: { $sum: 1 } } },
    ]);

    for (const item of unreadCounts) {
      const peerId = item._id?.toString?.() ?? item._id;
      if (peerMap.has(peerId)) {
        peerMap.get(peerId).unreadCount = item.count || 0;
      }
    }

    const users = await User.find({ _id: { $in: Array.from(peerIds) } }).select('name');
    const userMap = new Map(users.map((user) => [user._id.toString(), user]));

    const profiles = await UserProfile.find({ user_id: { $in: Array.from(peerIds) } }).select('user_id image');
    const profileMap = new Map(
      profiles.map((profile) => [
        profile.user_id.toString(),
        profile.image ? `${req.protocol}://${req.get('host')}${profile.image.startsWith('/') ? profile.image : `/${profile.image}`}` : '',
      ])
    );

    const conversations = Array.from(peerMap.values()).map((item) => ({
      peerId: item.peerId,
      peerName: userMap.get(item.peerId)?.name?.trim() || 'User',
      peerImageUrl: profileMap.get(item.peerId) || '',
      lastMessage: item.lastMessage,
      lastMessageAt: item.lastMessageAt,
      unreadCount: item.unreadCount,
    }));

    return res.json({ success: true, conversations });
  } catch (error) {
    console.error('chat.getUserConversations error', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.markAsRead = async (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ success: false, message: 'messageIds array required' });
    }

    await Message.updateMany(
      { _id: { $in: messageIds } },
      { read: true }
    );

    return res.json({ success: true, message: 'Messages marked as read' });
  } catch (error) {
    console.error('chat.markAsRead error', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};
