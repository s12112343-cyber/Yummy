const User = require('../models/User');
const Chef = require('../models/Chef');

// ================= جلب جميع المستخدمين =================
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find()
      .select('-password')
      .sort({ createdAt: -1 });
    
    // إضافة معلومات إضافية للشيفات
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

// ================= إنشاء مستخدم جديد (Admin أو Chef فقط) =================
const createUser = async (req, res) => {
  try {
    const { name, email, password, role, profileImage, specialty, bio } = req.body;
    
    // التحقق من صحة البيانات
    if (!name || !email || !password) {
      return res.status(400).json({ 
        message: 'Name, email and password are required' 
      });
    }
    
    // التحقق من أن الدور مسموح به (Admin أو Chef فقط)
    if (role !== 'admin' && role !== 'chef') {
      return res.status(400).json({ 
        message: 'Only Admin and Chef roles can be created here. Regular users register through the app.' 
      });
    }
    
    // التحقق من وجود المستخدم
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }
    
    // إنشاء المستخدم
    const user = new User({ 
      name, 
      email, 
      password, 
      role,
      isBanned: false,
      profileImage: profileImage || '',
    });
    await user.save();
    
    // إذا كان الدور Chef، أضف سجل في جدول Chef
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
    
    // إزالة كلمة المرور من الرد
    const userResponse = user.toObject();
    delete userResponse.password;
    
    // إذا كان Chef، أضف معلومات Chef في الرد
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

    // لو كان شيف احذفه من جدول Chef
    if (user.role === 'chef') {
      await Chef.findOneAndDelete({ userId: req.params.id });
    }

    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'User deleted successfully' });
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

    res.json({ success: true, users });
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

    /// 🔥 استخدمي القيمة القادمة من Flutter
    if (typeof isBanned !== 'undefined') {
      user.isBanned = isBanned;
    } else {
      user.isBanned = !user.isBanned; // fallback
    }

    await user.save();

    res.json({
      success: true,
      user, // 🔥 مهم جدًا
      isBanned: user.isBanned,
      message: user.isBanned ? 'User banned' : 'User unbanned'
    });

  } catch (err) {
    console.error("BAN ERROR:", err);

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
    
    // إذا تغير الدور من/إلى Chef، قم بتحديث جدول Chef
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

module.exports = { 
  getAllUsers, 
  createUser, 
  deleteUser, 
  searchUsers, 
  toggleBanUser,
  updateUserRole
};