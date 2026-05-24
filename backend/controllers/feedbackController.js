const Feedback = require('../models/Feedback');

function normalizeAvatarPath(value) {
  const raw = (value ?? '').toString().trim();

  if (!raw) return '';

  try {
    const parsed = new URL(raw);
    return parsed.pathname || '';
  } catch (_) {}

  if (raw.startsWith('/')) {
    return raw;
  }

  if (raw.includes('uploads')) {
    return `/${raw}`;
  }

  return raw;
}

// 🔥 CREATE FEEDBACK
const createFeedback = async (req, res, next) => {
  try {
    const { message, name, avatar } = req.body;

    if (!message || !message.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: 'Message is required',
      });
    }

    const feedback = new Feedback({
      user: req.user ? req.user._id : null,
      name: name?.toString?.() ?? '',
      avatar: normalizeAvatarPath(avatar),
      message: message.toString(),
    });

    await feedback.save();

    return res.status(201).json({
      success: true,
      feedback,
    });
  } catch (err) {
    next(err);
  }
};

// 🔥 LIST FEEDBACKS
const listFeedbacks = async (req, res, next) => {
  try {
    const feedbacks = await Feedback.find()
      .sort({ createdAt: -1 })
      .lean();

    return res.json({
      success: true,
      feedbacks,
    });
  } catch (err) {
    next(err);
  }
};

// 🔥 DELETE FEEDBACK
const deleteFeedback = async (req, res, next) => {
  try {
    const { id } = req.params;

    const deleted = await Feedback.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Feedback not found',
      });
    }

    return res.json({
      success: true,
      message: 'Feedback deleted',
    });
  } catch (err) {
    next(err);
  }
};

// 🔥 MARK ONE AS READ
const markFeedbackRead = async (req, res) => {
  try {
    const feedback = await Feedback.findByIdAndUpdate(
      req.params.id,
      {
        read: true,
      },
      { new: true }
    );

    if (!feedback) {
      return res.status(404).json({
        message: 'Feedback not found',
      });
    }

    res.json({
      success: true,
      feedback,
    });
  } catch (e) {
    res.status(500).json({
      message: e.message,
    });
  }
};

// 🔥 MARK ALL AS READ
const markAllRead = async (req, res, next) => {
  try {
    const result = await Feedback.updateMany(
      {
        read: { $ne: true },
      },
      {
        $set: { read: true },
      }
    );

    return res.json({
      success: true,
      modifiedCount:
        result.modifiedCount ??
        result.nModified ??
        0,
    });
  } catch (err) {
    next(err);
  }
};

// 🔥 EXPORTS
module.exports = {
  createFeedback,
  listFeedbacks,
  deleteFeedback,
  markFeedbackRead,
  markAllRead,
};