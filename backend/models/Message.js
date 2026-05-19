const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  from: { type: String, required: true, index: true },
  to: { type: String, required: true, index: true },
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, index: true },
  read: { type: Boolean, default: false },
});

module.exports = mongoose.model('Message', MessageSchema);
