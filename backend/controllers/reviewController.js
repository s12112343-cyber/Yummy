// 📁 controllers/reviewController.js
const mongoose = require('mongoose');
const Review = require('../models/Review'); // ✅ تأكد من استيراد النموذج
const Chef = require('../models/Chef'); // ✅ استيراد نموذج الشيف

// ✅ إضافة تقييم
const addReview = async (req, res) => {
  try {
    const userId = req.user.id || req.user.userId;
    const userName = req.user.name;
    const userAvatar = req.user.profileImage || '';

    console.log('User from token:', { userId, userName });

    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }

    if (!userName) {
      return res.status(400).json({ message: 'User name is required' });
    }

    const { chefId, rating, comment, mealName, orderId } = req.body;

    console.log('Review data:', { chefId, rating, comment });

    if (!chefId) {
      return res.status(400).json({ message: 'chefId is required' });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }

    if (!comment || comment.trim() === '') {
      return res.status(400).json({ message: 'Comment is required' });
    }

    // ✅ التحقق من وجود الشيف في قاعدة البيانات
    const chefExists = await Chef.findById(chefId);
    
    if (!chefExists) {
      return res.status(404).json({ message: 'Chef not found' });
    }

    const existingReview = await Review.findOne({ chefId, userId });

    if (existingReview) {
      return res.status(400).json({
        message: 'You already reviewed this chef',
      });
    }

    const review = new Review({
      chefId: new mongoose.Types.ObjectId(chefId),
      userId: new mongoose.Types.ObjectId(userId),
      userName,
      userAvatar,
      rating,
      comment,
      mealName: mealName || '',
      orderId: orderId || '',
      status: 'pending',
    });

    await review.save();

    res.status(201).json({
      message: 'Review added, waiting for admin approval',
      success: true,
      data: review,
    });
  } catch (error) {
    console.error('Add review error:', error);
    res.status(500).json({ message: error.message });
  }
};

const getChefReviews = async (req, res) => {

  try {

    const { chefId } = req.params;

    console.log(
      'Getting reviews for chef:',
      chefId,
    );

    const reviews = await Review.find({

      chefId: chefId,

      status: 'approved',

    })

    // 🔥 أهم سطر
    .populate(
      'userId',
      'name profileImage',
    )

    .sort({
      createdAt: -1,
    });

    console.log(
      `Found ${reviews.length} reviews`,
    );

    // 🔥 رجع بيانات مرتبة
    const formattedReviews =
        reviews.map((review) => ({

      _id: review._id,

      rating: review.rating,

      comment: review.comment,

      createdAt: review.createdAt,

      userId: {

        name:

            review.userId?.name ||

            review.userName ||

            'Unknown User',

        profileImage:

            review.userId?.profileImage ||

            review.userAvatar ||

            '',
      },
    }));

    res.json({

      success: true,

      data: formattedReviews,
    });

  } catch (error) {

    console.error(
      'Error in getChefReviews:',
      error,
    );

    res.status(500).json({

      success: false,

      message: error.message,
    });
  }
};
// ✅ جلب جميع التقييمات للأدمن
const getAllReviewsForAdmin = async (req, res) => {
  try {
    console.log('Fetching all reviews for admin...');
    
    // جلب جميع التقييمات
    const reviews = await Review.find().sort({ createdAt: -1 });
    
    console.log(`Found ${reviews.length} reviews`);
    
    // جلب أسماء الشيفات لكل تقييم
    const formattedReviews = await Promise.all(reviews.map(async (review) => {
      let chefName = 'Unknown Chef';
      let chefImage = '';
      let chefSpecialty = '';
      
      if (review.chefId) {
        try {
          // جلب بيانات الشيف
          const chef = await Chef.findById(review.chefId).populate('userId', 'name');
          
          if (chef) {
            // جلب اسم الشيف من جدول User المرتبط
            if (chef.userId) {
              chefName = chef.userId.name || 'Unknown Chef';
            }
            chefImage = chef.profileImage || '';
            chefSpecialty = chef.specialty || '';
          }
        } catch (err) {
          console.error(`Error fetching chef for review ${review._id}:`, err.message);
        }
      }
      
      return {
        _id: review._id,
        chefId: review.chefId,
        userId: review.userId,
        userName: review.userName,
        userAvatar: review.userAvatar,
        rating: review.rating,
        comment: review.comment,
        status: review.status,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
        chefName: chefName,
        chefImage: chefImage,
        chefSpecialty: chefSpecialty,
      };
    }));
    
    res.json({
      success: true,
      data: formattedReviews
    });
  } catch (error) {
    console.error('Error in getAllReviewsForAdmin:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// ✅ الموافقة على التقييم
const approveReview = async (req, res) => {
  try {
    const review = await Review.findByIdAndUpdate(
      req.params.id,
      { status: 'approved' },
      { new: true }
    );
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    console.log(`Review ${req.params.id} approved`);
    
    res.json({ success: true, data: review });
  } catch (error) {
    console.error('Error in approveReview:', error);
    res.status(500).json({ message: error.message });
  }
};

// ✅ رفض التقييم
const rejectReview = async (req, res) => {
  try {
    const review = await Review.findByIdAndUpdate(
      req.params.id,
      { status: 'rejected' },
      { new: true }
    );
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    console.log(`Review ${req.params.id} rejected`);
    
    res.json({ success: true, data: review });
  } catch (error) {
    console.error('Error in rejectReview:', error);
    res.status(500).json({ message: error.message });
  }
};

// ✅ حذف التقييم
const deleteReview = async (req, res) => {
  try {
    const review = await Review.findByIdAndDelete(req.params.id);
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    console.log(`Review ${req.params.id} deleted`);
    
    res.json({ success: true, message: 'Deleted successfully' });
  } catch (error) {
    console.error('Error in deleteReview:', error);
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  addReview,
  getChefReviews,
  getAllReviewsForAdmin,
  approveReview,
  rejectReview,
  deleteReview,
};