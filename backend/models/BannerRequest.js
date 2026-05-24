const mongoose = require('mongoose');

const bannerRequestSchema = new mongoose.Schema(
  {
    chef: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chef',
    },

    image: {
      type: String,
      required: true,
    },

    link: {
      type: String,
      default: '',
    },

    expiryDate: {
      type: Date,
    },

    /// 🔥 STATUS
    status: {
      type: String,

      enum: [
        'pending',
        'approved',
        'rejected',
      ],

      default: 'pending',
    },
read: {
  type: Boolean,
  default: false,
},
    /// 🔥 EXTRA INFO
    chefName: String,

    chefEmail: String,

    chefImage: String,

    chefLocation: String,

    chefSpecialties: [String],
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model(
  'BannerRequest',
  bannerRequestSchema,
);