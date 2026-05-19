const Chef = require('../models/Chef');
const Recipe = require('../models/Recipe');
const bcrypt = require('bcryptjs');

const User = require('../models/User');

const getchef = async (req, res) => {
  try {
    const chefs = await Chef.find().populate('userId', 'name email role profileImage');

    const result = await Promise.all(
      chefs
        .filter((chef) => chef.userId)
        .map(async (chef) => {
          const dishesCount = await Recipe.countDocuments({ chefId: chef._id });

          return {
            _id: chef._id,
            userId: chef.userId._id,
            name: chef.userId.name || 'Chef',
            email: chef.userId.email || '',
            specialty: chef.specialty || [],
            rating: chef.rating || 0,
            dishes: dishesCount,
            bio: chef.bio || '',
            location: chef.location || '',
            profileImage: chef.profileImage || chef.userId.profileImage || '',
            coverImage: chef.coverImage || '',
            reviews: chef.reviews || 0,
            createdAt: chef.createdAt,
          };
        })
    );

    res.json({
      success: true,
      data: result,
      count: result.length,
    });
  } catch (error) {
    console.error('❌ Error in getchef:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const getChefById = async (req, res) => {
  try {
    const chef = await Chef.findById(req.params.id).populate(
      'userId',
      'name email role profileImage'
    );

    if (!chef || !chef.userId) {
      return res.status(404).json({
        success: false,
        message: 'Chef not found',
      });
    }

    const dishesCount = await Recipe.countDocuments({ chefId: chef._id });

    res.json({
      success: true,
      data: {
        _id: chef._id,
        userId: chef.userId._id,
        name: chef.userId.name || 'Chef',
        email: chef.userId.email || '',
        specialty: chef.specialty || [],
        rating: chef.rating || 0,
        dishes: dishesCount,
        bio: chef.bio || '',
        location: chef.location || '',
        profileImage: chef.profileImage || chef.userId.profileImage || '',
        coverImage: chef.coverImage || '',
        reviews: chef.reviews || 0,
        createdAt: chef.createdAt,
      },
    });
  } catch (error) {
    console.error('❌ Error in getChefById:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
const createChef = async (req, res) => {
  try {

    const {
      name,
      email,
      password,
      specialty,
      profileImage,
      coverImage,
      bio,
      location
    } = req.body;

    if (!name || !email || !password || !specialty) {

      return res.status(400).json({
        success: false,
        message: 'Missing required fields',
      });
    }

    const existingUser = await User.findOne({
      email: email.toLowerCase().trim(),
    });

    if (existingUser) {

      return res.status(400).json({
        success: false,
        message: 'Email already exists',
      });
    }

    // ✅🔥 هاد أهم سطر
    const hashedPassword = await bcrypt.hash(
      password,
      10,
    );

    // ✅🔥 خزني المشفر
    const user = new User({
      name,
      email: email.toLowerCase().trim(),
      password: hashedPassword,
      role: 'chef',
      profileImage: profileImage || '',
    });

    await user.save();

    const chef = new Chef({
      userId: user._id,
      specialty: specialty || [],
      rating: 0,
      bio: bio || '',
      location: location || '',
      profileImage: profileImage || '',
      coverImage: coverImage || '',
      reviews: 0,
    });

    await chef.save();

    res.status(201).json({
      success: true,
      message: 'Chef created successfully',
      data: chef,
    });

  } catch (error) {

    console.error(
      'CREATE CHEF ERROR =>',
      error,
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
const deleteChef = async (req, res) => {
  try {
    const chefId = req.params.id;

    const chef = await Chef.findById(chefId);
    if (!chef) {
      return res.status(404).json({
        success: false,
        message: 'Chef not found',
      });
    }

    const userId = chef.userId;

    await Recipe.deleteMany({ chefId });
    await Chef.findByIdAndDelete(chefId);

    if (userId) {
      await User.findByIdAndDelete(userId);
    }

    res.json({
      success: true,
      message: 'Chef deleted successfully',
    });
  } catch (error) {
    console.error('❌ Error deleting chef:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
const getMyChef = async (req, res) => {
  try {
    const userId = req.user.userId;

    const chef = await Chef.findOne({ userId }).populate(
      'userId',
      'name email profileImage'
    );

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: 'Chef not found',
      });
    }

    const dishesCount = await Recipe.countDocuments({ chefId: chef._id });

    res.json({
      success: true,
      data: {
        _id: chef._id,
        name: chef.userId.name,
        email: chef.userId.email,

        profileImage: chef.profileImage || chef.userId.profileImage || '',
        coverImage: chef.coverImage || '',

        specialty: chef.specialty || [],
        bio: chef.bio || '',
        location: chef.location || '',
        experience: chef.experience || '',

        dishes: dishesCount,
      },
    });

  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};
const updateChef = async (req, res) => {
  try {
    const userId = req.user.userId;

    const chef = await Chef.findOne({ userId });

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: "Chef not found"
      });
    }

    const {
      name,
      bio,
      specialty,
      location,
      experience,
      coverImage
    } = req.body;

    /// 🔥 تحديث اسم اليوزر
    if (name) {
      await User.findByIdAndUpdate(userId, { name });
    }

    /// 🔥 تحديث بيانات الشيف
    if (bio !== undefined) chef.bio = bio;
    if (specialty !== undefined) chef.specialty = specialty;
    if (location !== undefined) chef.location = location;
    if (experience !== undefined) chef.experience = experience;
    if (coverImage !== undefined) chef.coverImage = coverImage;

    await chef.save();

    res.json({
      success: true,
      message: "Profile updated successfully",
      data: chef
    });

  } catch (e) {
    console.error("❌ Update Chef Error:", e);
    res.status(500).json({
      success: false,
      message: e.message
    });
  }
};
const updateProfileImage = async (req, res) => {
  try {
    console.log("FILE 👉", req.file); // 🔥 مهم

    const userId = req.user.userId;

    const chef = await Chef.findOne({ userId });

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: "Chef not found"
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image uploaded"
      });
    }

    chef.profileImage = `/uploads/${req.file.filename}`;

    await chef.save();

    res.json({
      success: true,
      imageUrl: chef.profileImage
    });

  } catch (e) {
    console.error("❌ Profile upload error:", e);
    res.status(500).json({
      success: false,
      message: e.message
    });
  }
};
const updateCoverImage = async (req, res) => {
  try {
    console.log("FILE 👉", req.file);

    const userId = req.user.userId;

    const chef = await Chef.findOne({ userId });

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: "Chef not found"
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image uploaded"
      });
    }

    chef.coverImage = `/uploads/${req.file.filename}`;

    await chef.save();

    res.json({
      success: true,
      coverImageUrl: chef.coverImage
    });

  } catch (e) {
    console.error("❌ Cover upload error:", e);
    res.status(500).json({
      success: false,
      message: e.message
    });
  }
};
// ✅ UPDATE EMAIL
const updateEmail = async (
  req,
  res,
) => {

  try {

    const userId =
        req.user.userId;

    const { email } =
        req.body;

    if (!email) {

      return res.status(400).json({

        success: false,

        message:
            'Email is required',
      });
    }

    // ✅ CLEAN EMAIL
    const cleanEmail =
        email
            .toLowerCase()
            .trim();

    // ✅ FIND USER
    const user =
        await User.findById(
      userId,
    );

    if (!user) {

      return res.status(404).json({

        success: false,

        message:
            'User not found',
      });
    }

    // ✅ CHECK EXISTING EMAIL
    const existing =
        await User.findOne({

      email: cleanEmail,
    });

    if (
        existing &&

        existing._id.toString() !==
            user._id.toString()
    ) {

      return res.status(400).json({

        success: false,

        message:
            'Email already exists',
      });
    }

    // ✅ SAVE
    user.email =
        cleanEmail;

    await user.save();

    res.json({

      success: true,

      message:
          'Email updated successfully',

      email:
          user.email,
    });

  } catch (e) {

    console.error(
      'UPDATE EMAIL ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message:
          e.message,
    });
  }
};

const updatePassword = async (
  req,
  res,
) => {

  try {

    const userId =
        req.user.userId;

    const {
      currentPassword,
      newPassword,
    } = req.body;

    const user =
        await User.findById(
      userId,
    );

    if (!user) {

      return res.status(404).json({

        success: false,

        message:
            'User not found',
      });
    }

    const isMatch =
        await bcrypt.compare(

      currentPassword.trim(),

      user.password,
    );

    if (!isMatch) {

      return res.status(400).json({

        success: false,

        message:
            'Current password is wrong',
      });
    }

    // ✅ HASH
    const hashedPassword =
        await bcrypt.hash(

      newPassword.trim(),

      10,
    );

    console.log(
      'NEW HASH =>',
      hashedPassword,
    );

    // ✅ FORCE UPDATE
    await User.updateOne(

      {
        _id: userId,
      },

      {
        $set: {
          password:
              hashedPassword,
        },
      }
    );

    res.status(200).json({

      success: true,

      message:
          'Password updated successfully',
    });

  } catch (error) {

    console.log(
      'UPDATE PASSWORD ERROR =>',
      error,
    );

    res.status(500).json({

      success: false,

      message:
          'Server error',
    });
  }
};
module.exports = {
  getchef,
  getChefById,
  createChef,
  deleteChef,
  getMyChef,
  updateChef,
  updateProfileImage,
  updateCoverImage,
    updateEmail,
  updatePassword,
};