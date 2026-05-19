const mongoose = require("mongoose");

const connectDB = async () => {
  try {
    // Validate that required environment variable exists
    if (!process.env.MONGO_URI) {
      throw new Error("MONGO_URI environment variable is required. Please set it in .env file");
    }

    await mongoose.connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 5000,
      family: 4
    });

    console.log("✅ MongoDB connected successfully");
  } catch (error) {
    console.error("❌ MongoDB connection error:", error.message);
    process.exit(1);
  }
};

module.exports = connectDB;