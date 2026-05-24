const mongoose = require("mongoose");

const appSettingsSchema =
  new mongoose.Schema({

    appIcon: {
      type: String,
      default: "classic",
    },

  });

module.exports =
  mongoose.model(
    "AppSettings",
    appSettingsSchema,
  );