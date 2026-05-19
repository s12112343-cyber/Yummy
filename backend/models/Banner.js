// models/Banner.js
const mongoose = require('mongoose');

const BannerSchema = new mongoose.Schema({
  image: { 
    type: String, 
    required: true 
  },
  link: { 
    type: String,
    default: '' 
  },
  order: { 
    type: Number, 
    default: 1 
  },
  expiryDate: { 
    type: Date,
    default: null 
  },
  isActive: { 
    type: Boolean, 
    default: true 
  },
  createdAt: { 
    type: Date, 
    default: Date.now 
  }
});

module.exports = mongoose.model('Banner', BannerSchema);