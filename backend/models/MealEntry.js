const mongoose = require("mongoose");

const mealEntrySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    date: {
      type: Date,
      required: true,
      index: true,
    },
    date_key: {
      type: String,
      required: true,
      index: true,
    },
    meal_type: {
      type: String,
      enum: ["breakfast", "lunch", "snack", "dinner"],
      required: true,
      index: true,
    },
    meal_name: {
      type: String,
      required: true,
      trim: true,
    },
    calories: {
      type: Number,
      required: true,
      min: 0,
    },
    protein: {
      type: Number,
      required: true,
      min: 0,
    },
    carbs: {
      type: Number,
      required: true,
      min: 0,
    },
    fat: {
      type: Number,
      required: true,
      min: 0,
    },
    grams: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { timestamps: true }
);

mealEntrySchema.index({ user: 1, date_key: 1, meal_type: 1 });

module.exports = mongoose.model("MealEntry", mealEntrySchema);
