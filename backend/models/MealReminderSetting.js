const mongoose = require("mongoose");

const mealReminderItemSchema = new mongoose.Schema(
  {
    mealType: {
      type: String,
      enum: ["breakfast", "lunch", "snack", "dinner"],
      required: true,
    },
    enabled: {
      type: Boolean,
      default: true,
    },
    time: {
      type: String,
      required: true,
      default: "08:00",
      match: [/^([01]\d|2[0-3]):[0-5]\d$/, "time must be HH:mm"],
    },
  },
  { _id: false }
);

const mealReminderSettingSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },
    enabled: {
      type: Boolean,
      default: true,
    },
    timezoneOffsetMinutes: {
      type: Number,
      default: 0,
    },
    reminders: {
      type: [mealReminderItemSchema],
      default: [],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model(
  "MealReminderSetting",
  mealReminderSettingSchema
);
