const User = require('../models/User');
const Chef = require('../models/Chef');

// ================= جلب جميع المستخدمين =================
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find()
      .select('-password')
      .sort({ createdAt: -1 });

    const usersWithDetails = await Promise.all(users.map(async (user) => {
      const userObj = user.toObject();

      if (user.role === 'chef') {
        const chef = await Chef.findOne({ userId: user._id });
        if (chef) {
          userObj.specialty = chef.specialty;
          userObj.bio = chef.bio;
          userObj.profileImage = chef.profileImage || userObj.profileImage;
          userObj.rating = chef.rating;
          userObj.dishes = chef.dishes;
          userObj.followers = chef.followers;
        }
      }

      return userObj;
    }));

    res.json({ success: true, users: usersWithDetails });
  } catch (err) {
    console.error('Error in getAllUsers:', err);
    res.status(500).json({ message: err.message });
  }
};

// ================= إنشاء مستخدم جديد =================
const createUser = async (req, res) => {
  try {
    const { name, email, password, role, profileImage, specialty, bio } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        message: 'Name, email and password are required'
      });
    }

    if (role !== 'admin' && role !== 'chef') {
      return res.status(400).json({
        message: 'Only Admin and Chef roles can be created here. Regular users register through the app.'
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const user = new User({
      name,
      email,
      password,
      role,
      isBanned: false,
      profileImage: profileImage || '',
    });

    await user.save();

    if (role === 'chef') {
      const chef = new Chef({
        userId: user._id,
        specialty: specialty || '',
        bio: bio || '',
        profileImage: profileImage || '',
        rating: 0,
        dishes: 0,
        followers: '0',
      });

      await chef.save();
    }

    const userResponse = user.toObject();
    delete userResponse.password;

    if (role === 'chef') {
      const chefData = await Chef.findOne({ userId: user._id });

      userResponse.specialty = chefData?.specialty || '';
      userResponse.bio = chefData?.bio || '';
      userResponse.profileImage = chefData?.profileImage || userResponse.profileImage;
      userResponse.rating = chefData?.rating || 0;
      userResponse.dishes = chefData?.dishes || 0;
      userResponse.followers = chefData?.followers || '0';
    }

    res.status(201).json({
      success: true,
      user: userResponse,
      message: `${role === 'admin' ? 'Admin' : 'Chef'} created successfully`
    });
  } catch (err) {
    console.error('Error in createUser:', err);
    res.status(500).json({ message: err.message });
  }
};

// ================= حذف مستخدم =================
const deleteUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (user.role === 'chef') {
      await Chef.findOneAndDelete({ userId: req.params.id });
    }

    await User.findByIdAndDelete(req.params.id);

    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (err) {
    console.error('Error in deleteUser:', err);
    res.status(500).json({ message: err.message });
  }
};

// ================= البحث عن مستخدمين =================
const searchUsers = async (req, res) => {
  try {
    const { q } = req.query;

    if (!q) {
      return res.json({ success: true, users: [] });
    }

    const users = await User.find({
      $or: [
        { name: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } },
      ],
    }).select('-password');

    res.json({
      success: true,
      users
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ================= حظر/إلغاء حظر مستخدم =================
const toggleBanUser = async (req, res) => {
  try {
    const { isBanned } = req.body;

    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    if (typeof isBanned !== 'undefined') {
      user.isBanned = isBanned;
    } else {
      user.isBanned = !user.isBanned;
    }

    await user.save();

    res.json({
      success: true,
      user: {
        ...user.toObject(),
        isBanned: !!user.isBanned,
      },
      isBanned: user.isBanned,
      message: user.isBanned ? 'User banned' : 'User unbanned'
    });
  } catch (err) {
    console.error('BAN ERROR:', err);

    res.status(500).json({
      success: false,
      message: err.message
    });
  }
};

// ================= تحديث دور المستخدم =================
const updateUserRole = async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;

    if (!['user', 'chef', 'admin'].includes(role)) {
      return res.status(400).json({ message: 'Invalid role' });
    }

    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const oldRole = user.role;

    user.role = role;
    await user.save();

    if (role === 'chef' && oldRole !== 'chef') {
      const chef = new Chef({
        userId: user._id,
        name: user.name,
        email: user.email,
        isActive: true,
        createdAt: new Date()
      });

      await chef.save();
    } else if (oldRole === 'chef' && role !== 'chef') {
      await Chef.findOneAndDelete({ userId: user._id });
    }

    const userResponse = user.toObject();
    delete userResponse.password;

    res.json({
      success: true,
      user: userResponse,
      message: 'User role updated successfully'
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ================= جلب بيانات المستخدم الحالي =================
const getProfile = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId).select('-password');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        isBanned: !!user.isBanned,
        profileImage: user.profileImage || '',
      },
    });
  } catch (err) {
    console.error('Error in getProfile:', err);

    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

module.exports = {
  getAllUsers,
  createUser,
  deleteUser,
  searchUsers,
  toggleBanUser,
  updateUserRole,
  getProfile,
};