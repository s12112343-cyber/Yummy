const mongoose = require('mongoose');

const chefSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
specialty: {
  type: [String],
  default: [],
},
  
  profileImage: {
    type: String,
    default: '',
  },
  coverImage: {
    type: String,
    default: '',
  },
  bio: {
    type: String,
    default: '',
  },
  rating: {
    type: Number,
    default: 0,
  },
  location: {
    type: String,
    default: '',
  },
  experience: {
  type: String,
  default: '',
},
  reviews: {
    type: Number,
    default: 0,
  },
  averageRating: {
  type: Number,
  default: 0,
},

totalReviews: {
  type: Number,
  default: 0,
},
}, { timestamps: true });

module.exports = mongoose.model('Chef', chefSchema);