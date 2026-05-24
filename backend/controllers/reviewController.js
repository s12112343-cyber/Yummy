// 📁 controllers/reviewController.js
const mongoose = require('mongoose');
const Review = require('../models/Review'); // ✅ تأكد من استيراد النموذج
const Chef = require('../models/Chef'); // ✅ استيراد نموذج الشيف
const User = require('../models/User');
const Notification = require('../models/Notification');

const addReview = async (req, res) => {
  try {
    const userId = req.user.id || req.user.userId;

    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }

    const userData = await User.findById(userId);

    const userName = userData?.name || 'Unknown User';
    const userAvatar = userData?.profileImage || '';

    console.log('User from DB:', { userId, userName });

    const { chefId, rating, comment, mealName, orderId } = req.body;

    if (!chefId) {
      return res.status(400).json({ message: 'chefId is required' });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }

    if (!comment || comment.trim() === '') {
      return res.status(400).json({ message: 'Comment is required' });
    }

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
      userName: userName,
      userAvatar: userAvatar,
      rating: Number(rating),
      comment: comment.trim(),
      mealName: mealName || '',
      orderId: orderId || '',
      status: 'pending',
    });

    await review.save();

    res.status(201).json({
      success: true,
      message: 'Review added, waiting for admin approval',
      data: review,
    });
  } catch (error) {
    console.error('Add review error:', error);
    res.status(500).json({ message: error.message });
  }
};
const markReviewRead = async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found',
      });
    }

    review.read = true;

    await review.save();

    res.json({
      success: true,
      message: 'Review marked as read',
    });

  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
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
const approveReview = async (req, res) => {

  try {

    const review =
      await Review.findById(
        req.params.id,
      );

    if (!review) {

      return res.status(404).json({

        success: false,

        message: 'Review not found',
      });
    }

    //
    // 🔥 GET CHEF
    //
    const chef =
      await Chef.findById(
        review.chefId,
      );

    if (!chef) {

      return res.status(404).json({

        success: false,

        message: 'Chef not found',
      });
    }

    //
    // 🔥 APPROVE REVIEW
    //
    review.status = 'approved';

    await review.save();

    //
    // 🔥 SAVE NOTIFICATION
    //
    const notification =
      await Notification.create({

        recipientId:
          chef.userId.toString(),

        actorId: '',

        actorName: 'Admin',

        actorImageUrl: '',

        type: 'review',

        title:
          'New Review ⭐',

        body:
          'Someone reviewed your profile',

        isRead: false,

        payload: {
          reviewId:
            review._id,
        },
      });

    console.log(
      'NOTIFICATION SAVED =>',
      notification,
    );

    //
    // 🔥 REALTIME SOCKET
    //
    const io =
      req.app.get('io');

    io.to(
      chef.userId.toString(),
    ).emit(
      'newNotification',
      notification,
    );

    res.status(200).json({

      success: true,

      message:
        'Review approved successfully',

      review,
    });

  } catch (e) {

    console.log(
      'APPROVE REVIEW ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};


const rejectReview = async (req, res) => {

  try {

    const review =
      await Review.findById(
        req.params.id,
      );

    if (!review) {

      return res.status(404).json({

        success: false,

        message: 'Review not found',
      });
    }

    review.status =
      'rejected';

    await review.save();

    res.status(200).json({

      success: true,

      message:
        'Review rejected successfully',

      review,
    });

  } catch (e) {

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};const deleteReview = async (req, res) => {

  try {

    await Review.findByIdAndDelete(
      req.params.id,
    );

    res.status(200).json({

      success: true,

      message:
        'Review deleted successfully',
    });

  } catch (e) {

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

module.exports = {
  addReview,
  getChefReviews,
  getAllReviewsForAdmin,
  approveReview,
  rejectReview,
  deleteReview,
  markReviewRead,
};