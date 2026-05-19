const UserProfile = require("../models/UserProfile");
const User = require("../models/User");
const fs = require("fs/promises");
const path = require("path");
const sharp = require("sharp");

const uploadFolder = path.join(__dirname, "../uploads");

const parseListField = (value) => {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item).trim())
      .filter((item) => item && item.toLowerCase() !== "none");
  }

  if (typeof value === "string") {
    const trimmed = value.trim();

    if (!trimmed) {
      return [];
    }

    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed
          .map((item) => String(item).trim())
          .filter((item) => item && item.toLowerCase() !== "none");
      }
    } catch (_) {
      // Keep fallback parsing below for comma-separated text.
    }

    return trimmed
      .split(",")
      .map((item) => item.trim())
      .filter((item) => item && item.toLowerCase() !== "none");
  }

  if (value === undefined || value === null) {
    return [];
  }

  const stringValue = String(value).trim();
  if (!stringValue || stringValue.toLowerCase() === "none") {
    return [];
  }

  return [stringValue];
};

const normalizeDateOnlyUtc = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;

  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
  );
};

const createOrUpdateProfile = async (req, res) => {
  try {
    const user_id = req.user.userId;

    const {
      name,
      email,
      goal,
      gender,
      date_of_birth,
      height_value,
      height_unit,
      weight_value,
      weight_unit,
      activity_level,
      allergies,
      medical_conditions,
    } = req.body;

    if (!user_id) {
      return res.status(400).json({
        message: "user_id is required",
      });
    }

    if (!name || !name.trim()) {
      return res.status(400).json({
        message: "name is required",
      });
    }

    const userUpdates = {
      name: name.trim(),
    };

    if (email !== undefined) {
      const normalizedEmail = String(email).trim().toLowerCase();
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

      if (!normalizedEmail) {
        return res.status(400).json({
          message: "email is required",
        });
      }

      if (!emailRegex.test(normalizedEmail)) {
        return res.status(400).json({
          message: "Please provide a valid email address",
        });
      }

      const existingEmailUser = await User.findOne({
        email: normalizedEmail,
        _id: { $ne: user_id },
      });

      if (existingEmailUser) {
        return res.status(409).json({
          message: "Email already registered",
        });
      }

      userUpdates.email = normalizedEmail;
    }

    // Validate height value - must be between 50cm and 300cm
    if (height_value !== undefined && height_value !== null) {
      const heightNum = Number(height_value);
      if (isNaN(heightNum) || heightNum < 50 || heightNum > 300) {
        return res.status(400).json({
          message: "Height must be between 50 and 300 cm",
        });
      }
    }

    // Validate weight value - must be between 10kg and 600kg
    if (weight_value !== undefined && weight_value !== null) {
      const weightNum = Number(weight_value);
      if (isNaN(weightNum) || weightNum < 10 || weightNum > 600) {
        return res.status(400).json({
          message: "Weight must be between 10 and 600 kg",
        });
      }
    }

    const updatedUser = await User.findByIdAndUpdate(user_id, userUpdates, {
      new: true,
    });

    if (!updatedUser) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const existingProfile = await UserProfile.findOne({ user_id });

    let imagePath = existingProfile?.image || "";

    if (req.file) {
      const jpgFileName = `${Date.now()}-${Math.round(
        Math.random() * 1e9
      )}.jpg`;
      const jpgAbsolutePath = path.join(uploadFolder, jpgFileName);

      try {
        await fs.mkdir(uploadFolder, { recursive: true });

        await sharp(req.file.buffer)
          .rotate()
          .jpeg({ quality: 88, mozjpeg: true })
          .toFile(jpgAbsolutePath);

        imagePath = `/uploads/${jpgFileName}`;
      } catch (conversionError) {
        return res.status(400).json({
          message: "Failed to process image. Please upload a valid image file.",
        });
      }
    }

    const profile = await UserProfile.findOneAndUpdate(
      { user_id },
      {
        user_id,
        goal: goal || "",
        gender: gender || "",
        date_of_birth: date_of_birth || null,
        height: {
          value: height_value || 0,
          unit: height_unit || "cm",
        },
        weight: {
          value: weight_value || 0,
          unit: weight_unit || "kg",
        },
        activity_level: activity_level || "",
        allergies: parseListField(allergies),
        medical_conditions: parseListField(medical_conditions),
        image: imagePath,
      },
      { new: true, upsert: true }
    );

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    res.status(201).json({
      message: "Profile and name saved successfully",
      user: updatedUser,
      profile: {
        ...profile.toObject(),
        image_url: profile.image ? `${baseUrl}${profile.image}` : "",
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

const getMyProfile = async (req, res) => {
  try {
    const user_id = req.user.userId;

    const user = await User.findById(user_id).select("name email");
    const profile = await UserProfile.findOne({ user_id });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    res.status(200).json({
      user,
      profile: profile
        ? {
            ...profile.toObject(),
            image_url: profile.image ? `${baseUrl}${profile.image}` : "",
          }
        : null,
    });
  } catch (error) {
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

const updateMyStreak = async (req, res) => {
  try {
    const user_id = req.user.userId;
    const { streak_count, streak_dates } = req.body;

    const parsedCount = Number(streak_count);
    if (!Number.isFinite(parsedCount) || parsedCount < 0) {
      return res.status(400).json({
        message: "streak_count must be a non-negative number",
      });
    }

    if (!Array.isArray(streak_dates)) {
      return res.status(400).json({
        message: "streak_dates must be an array",
      });
    }

    const normalizedDates = [];
    const uniqueDates = new Set();

    for (const item of streak_dates) {
      const normalized = normalizeDateOnlyUtc(item);
      if (!normalized) continue;

      const key = normalized.toISOString().slice(0, 10);
      if (uniqueDates.has(key)) continue;
      uniqueDates.add(key);
      normalizedDates.push(normalized);
    }

    normalizedDates.sort((a, b) => a.getTime() - b.getTime());

    const profile = await UserProfile.findOneAndUpdate(
      { user_id },
      {
        $set: {
          user_id,
          streak_count: Math.floor(parsedCount),
          streak_dates: normalizedDates,
        },
      },
      { new: true, upsert: true }
    );

    return res.status(200).json({
      message: "Streak updated successfully",
      streak: {
        streak_count: profile.streak_count || 0,
        streak_dates: profile.streak_dates || [],
      },
    });
  } catch (error) {
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

const getUsersStreaks = async (req, res) => {
  try {
    const users = await User.find({ role: "user" }).select("name").sort({ createdAt: -1 }).lean();

    if (!users.length) {
      return res.status(200).json({ users: [] });
    }

    const userIds = users.map((user) => user._id);
    const profiles = await UserProfile.find({
      user_id: { $in: userIds },
      streak_count: { $gt: 0 },
    })
      .select("gender image streak_count user_id")
      .sort({ streak_count: -1, updatedAt: -1 })
      .lean();
    const userMap = new Map(users.map((user) => [user._id.toString(), user]));

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    const payload = profiles
      .map((profile) => {
      const user = userMap.get(profile.user_id.toString());
      const imagePath = (profile.image || "").toString();

      return {
        id: user?._id || profile.user_id,
        name: (user?.name || "User").toString(),
        gender: (profile.gender || "").toString(),
        streak_count: Number(profile.streak_count || 0),
        image_url: imagePath
          ? `${baseUrl}${imagePath.startsWith("/") ? imagePath : `/${imagePath}`}`
          : "",
      };
      })
      .sort((a, b) => b.streak_count - a.streak_count);

    return res.status(200).json({ users: payload });
  } catch (error) {
    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

const searchUsers = async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim();
    if (!q) return res.status(200).json({ users: [] });

    const regex = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');

    const users = await User.find({ role: 'user', $or: [{ name: regex }, { email: regex }] })
      .select('name email')
      .limit(50)
      .lean();

    const payload = users.map((u) => ({ id: u._id, name: u.name || 'User', email: u.email || '' }));
    return res.status(200).json({ users: payload });
  } catch (error) {
    return res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  createOrUpdateProfile,
  getMyProfile,
  updateMyStreak,
  getUsersStreaks,
  searchUsers,
};
