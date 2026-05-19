const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  name: String,
  calories: Number,
  fat: Number,
  protein: Number,
  potassium: Number,
});

module.exports = mongoose.model('Ingredient', schema);