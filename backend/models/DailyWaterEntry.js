const mongoose = require("mongoose");

const dailyWaterEntrySchema = new mongoose.Schema(
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
    consumed_water_ml: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    daily_water_goal_ml: {
      type: Number,
      required: true,
      min: 0,
      default: 3500,
    },
    last_drink_time: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

dailyWaterEntrySchema.index({ user: 1, date_key: 1 }, { unique: true });

module.exports = mongoose.model("DailyWaterEntry", dailyWaterEntrySchema);
