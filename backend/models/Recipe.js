const mongoose = require('mongoose');

const recipeSchema = new mongoose.Schema({
  views: { type: Number, default: 0 },
  orders: { type: Number, default: 0 },
  likes: { type: Number, default: 0 },
rating: {
  type: Number,
  default: 4,
},
reviewsCount: {
  type: Number,
  default: 0,
},
chefId: {
  type: mongoose.Schema.Types.ObjectId,
  ref: 'Chef',
  required: true,
},
  name: { type: String, required: true },
  description: { type: String, default: '' },
  image: { type: String, default: '' },
  price: { type: Number, required: true },
  category: { type: String, default: '' },
  totalTime: { type: Number, default: 0 },
  rating: { type: Number, default: 4 },

  // 🔥 ingredients
  ingredients: [
    {
      name: String,
      quantity: Number,
      unit: String,
    }
  ],

  // 🔥 nutrition
  calories: { type: Number, default: 0 },
  fat: { type: Number, default: 0 },
  protein: { type: Number, default: 0 },
  potassium: { type: Number, default: 0 },

  // 🔥🔥 الجديد (التعلم)
  unknownIngredients: {
    type: [String],
    default: [],
  },

}, { timestamps: true });

module.exports = mongoose.model('Recipe', recipeSchema);