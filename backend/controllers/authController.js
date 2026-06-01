const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const User = require("../models/User");
const UserProfile = require("../models/UserProfile");
const UserFollow = require("../models/UserFollow");
const { sendResetCodeEmail } = require("../services/emailService");
const { addDeviceToken } = require("../services/notificationService");
const changeEmail = async (req, res) => {
  try {
    const userId = req.user.userId;

    const { email } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    const normalizedEmail =
      email.trim().toLowerCase();

    // ✅ check existing email
    const existingUser =
      await User.findOne({
        email: normalizedEmail,
      });

    if (
      existingUser &&
      existingUser._id.toString() !== userId
    ) {
      return res.status(400).json({
        success: false,
        message: "Email already exists",
      });
    }

    const user =
      await User.findByIdAndUpdate(
        userId,
        {
          email: normalizedEmail,
        },
        {
          new: true,
        }
      );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Email updated successfully",

      user: {
        id: user._id,
        email: user.email,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};
// Error handler wrapper
const handleError = (error, res) => {
  console.error("Error:", error.message);
  
  // Don't expose internal error details
  if (process.env.NODE_ENV === "production") {
    return res.status(500).json({
      message: "An error occurred. Please try again later.",
    });
  }
  
  return res.status(500).json({
    message: "Server error",
    error: error.message,
  });
};

const register = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        message: "Email and password are required",
      });
    }

    // Validate password strength
    if (password.length < 8) {
      return res.status(400).json({
        message: "Password must be at least 8 characters",
      });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });

    if (existingUser) {
      return res.status(409).json({
        message: "Email already registered",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      name: "",
      email: email.toLowerCase(),
      password: hashedPassword,
      role: "user", // Always set to "user", NEVER from request
    });

    const token = jwt.sign(
      {
        userId: user._id,
        role: user.role,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(201).json({
      message: "Account created successfully",
      token,
      userId: user._id,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        message: "Email and password are required",
      });
    }

    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(401).json({
        message: "Invalid email or password",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({
        message: "Invalid email or password",
      });
    }

    if (user.isBanned) {
      return res.status(403).json({
        message: "Your account has been banned. Please contact support.",
        isBanned: true,
      });
    }

    const token = jwt.sign(
      {
        userId: user._id,
        role: user.role,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(200).json({
      message: "Login successful",
      token,
      userId: user._id,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        isBanned: !!user.isBanned,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};

const registerDeviceToken = async (req, res) => {
  try {
    const userId = req.user?.userId;
    const { token } = req.body;

    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    if (!token || !token.trim()) {
      return res.status(400).json({ message: "Device token is required" });
    }

    await addDeviceToken(userId, token.trim());

    res.status(200).json({
      message: "Device token saved successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

const updateUserName = async (req, res) => {
  try {
    const { name } = req.body;
    const userId = req.user.userId; // From JWT token, not request body

    if (!name || !name.trim()) {
      return res.status(400).json({
        message: "Name is required",
      });
    }

    if (name.trim().length < 2 || name.trim().length > 100) {
      return res.status(400).json({
        message: "Name must be between 2 and 100 characters",
      });
    }

    const user = await User.findByIdAndUpdate(
      userId,
      { name: name.trim() },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.status(200).json({
      message: "Name updated successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};

const sendResetCode = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({
        message: "Email is required",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(404).json({
        message: "If email exists, verification code will be sent",
      });
    }

    const code = Math.floor(1000 + Math.random() * 9000).toString();

    const hashedCode = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    user.reset_code = hashedCode;
    user.reset_code_expires = new Date(Date.now() + 10 * 60 * 1000);
    user.reset_code_verified = false;

    await user.save();

    try {
      await sendResetCodeEmail(user.email, code);
    } catch (emailError) {
      // Rollback the code if email fails
      user.reset_code = null;
      user.reset_code_expires = null;
      await user.save();

      return res.status(503).json({
        message: "Email service temporarily unavailable. Please try again later.",
      });
    }

    res.status(200).json({
      message: "If email exists, verification code will be sent",
    });
  } catch (error) {
    handleError(error, res);
  }
};

const verifyResetCode = async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({
        message: "Email and code are required",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    if (!user.reset_code || !user.reset_code_expires) {
      return res.status(400).json({
        message: "No reset code found. Request a new one.",
      });
    }

    if (user.reset_code_expires < new Date()) {
      user.reset_code = null;
      user.reset_code_expires = null;
      user.reset_code_verified = false;
      await user.save();

      return res.status(400).json({
        message: "Verification code expired. Request a new one.",
      });
    }

    const hashedCode = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    if (hashedCode !== user.reset_code) {
      return res.status(400).json({
        message: "Invalid verification code",
      });
    }

    user.reset_code_verified = true;
    await user.save();

    res.status(200).json({
      message: "Code verified successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

const resetPassword = async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({
        message: "Email and new password are required",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        message: "Password must be at least 8 characters",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    if (!user.reset_code_verified) {
      return res.status(400).json({
        message: "Verification code not confirmed",
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    user.password = hashedPassword;
    user.reset_code = null;
    user.reset_code_expires = null;
    user.reset_code_verified = false;

    await user.save();

    res.status(200).json({
      message: "Password reset successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};
const changePassword = async (req, res) => {
  try {
    const userId = req.user.userId;

    const {
      currentPassword,
      newPassword,
    } = req.body;

    if (
      !currentPassword ||
      !newPassword
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Current and new password are required",
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message:
          "Password must be at least 6 characters",
      });
    }

    const user =
      await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const isMatch =
      await bcrypt.compare(
        currentPassword,
        user.password
      );

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message:
          "Current password is incorrect",
      });
    }

    const hashedPassword =
      await bcrypt.hash(
        newPassword,
        10
      );

    user.password =
      hashedPassword;

    await user.save();

    res.status(200).json({
      success: true,
      message:
        "Password updated successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};
const getMe = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId).select("-password -reset_code");

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const profile = await UserProfile.findOne({ user_id: userId });
    const followerCount = await UserFollow.countDocuments({
      following_id: userId,
    });
    const followingCount = await UserFollow.countDocuments({
      follower_id: userId,
    });

      const baseUrl = `${req.protocol}://${req.get("host")}`;

      res.status(200).json({
        message: "User fetched successfully",
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
          isBanned: !!user.isBanned,
          followerCount,
          followingCount,
          profile: profile
            ? {
                ...profile.toObject(),
                image_url: profile.image ? `${baseUrl}${profile.image}` : "",
              }
            : null,
        },
      });
  } catch (error) {
    handleError(error, res);
  }
};

module.exports = {
  register,
  login,
  registerDeviceToken,
  updateUserName,
  sendResetCode,
  verifyResetCode,
  resetPassword,
  getMe,
  changeEmail,
  changePassword,
};
