const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema(
  {
    chefId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chef',
      required: true,
    },

    recipeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Recipe',
      default: null,
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    dishName: {
      type: String,
      default: '',
    },

    dishImage: {
      type: String,
      default: '',
    },

    customerName: {
      type: String,
      default: '',
    },

    customerAvatar: {
      type: String,
      default: '',
    },

    quantity: {
      type: Number,
      default: 1,
    },

    price: {
      type: Number,
      default: 0,
    },

    totalPrice: {
      type: Number,
      default: 0,
    },

    phone: {
      type: String,
      default: '',
    },

    city: {
      type: String,
      default: '',
    },

    street: {
      type: String,
      default: '',
    },

    paymentMethod: {
      type: String,
      default: 'cash',
    },

    specialInstructions: {
      type: String,
      default: '',
    },

    // Optional size and nutrition fields captured from the order
    size: {
      type: String,
      default: '',
    },

    calories: {
      type: Number,
      default: 0,
    },

    fat: {
      type: Number,
      default: 0,
    },

    protein: {
      type: Number,
      default: 0,
    },

    carbs: {
      type: Number,
      default: 0,
    },

    status: {
      type: String,
      enum: [
        'pending',
        'preparing',
        'completed',
        'cancelled',
      ],
      default: 'pending',
    },

    orderTime: {
      type: Date,
      default: Date.now,
    },
  },

  { timestamps: true }
);

module.exports = mongoose.model(
  'Order',
  orderSchema,
);

