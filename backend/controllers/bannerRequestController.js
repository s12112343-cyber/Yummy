const Banner = require('../models/Banner');
const BannerRequest = require('../models/BannerRequest');
const Chef = require('../models/Chef');
const Notification = require('../models/Notification');
/// =======================================================
/// CREATE REQUEST (CHEF)
/// =======================================================
const createBannerRequest = async (req, res) => {
  try {
    const {
      image,
      link,
      expiryDate,

      chefId,
      chefName,
      chefEmail,
      chefImage,
      chefLocation,
      chefSpecialties,
    } = req.body;

    if (!image) {
      return res.status(400).json({
        success: false,
        message: 'Image is required',
      });
    }

    /// 🔥 تأكد الشيف موجود
    const chef = await Chef.findById(chefId);

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: 'Chef not found',
      });
    }

    /// 🔥 إنشاء الطلب
    const request = await BannerRequest.create({
      chef: chefId,

      image,
      link,
      expiryDate,

      chefName,
      chefEmail,
      chefImage,
      chefLocation,
      chefSpecialties,

      status: 'pending',
    });

    res.status(201).json({
      success: true,
      message: 'Banner request created successfully',
      request,
    });

  } catch (e) {
    console.log('CREATE BANNER REQUEST ERROR =>', e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};


/// =======================================================
/// GET ALL REQUESTS (ADMIN)
/// =======================================================
const getBannerRequests = async (req, res) => {
  try {
    const requests = await BannerRequest.find({
      status: 'pending',
    })
      .populate('chef')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      requests,
    });
  } catch (e) {
    res.status(500).json({
      message: e.message,
    });
  }
};
/// =======================================================
/// APPROVE REQUEST
/// =======================================================

const approveBannerRequest = async (req, res) => {
  try {
    const request = await BannerRequest.findById(req.params.id);

    if (!request) {
      return res.status(404).json({
        message: 'Request not found',
      });
    }

    /// 🔥 CREATE REAL BANNER
    const newBanner = await Banner.create({
      image: request.image,
      link: request.link,
      expiryDate: request.expiryDate,

      isActive: true,

      chef: request.chef,

      /// optional
      order: 1,
    });

    /// 🔥 UPDATE REQUEST STATUS
    request.status = 'approved';
//
// 🔥 NOTIFY CHEF
//
await Notification.create({
  recipientId:
    request.chef.toString(),

  actorName: 'Admin',

  actorImageUrl: '',

  type: 'global',

  title: 'Banner Approved ✅',

  body:
    'Admin approved your banner request',

  isRead: false,

  payload: {},
});
    await request.save();

    res.status(200).json({
      success: true,
      message: 'Banner approved successfully',
      banner: newBanner,
    });

  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};


/// =======================================================
/// REJECT REQUEST
/// =======================================================
const rejectBannerRequest = async (req, res) => {
  try {

    const request = await BannerRequest.findById(req.params.id);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found',
      });
    }

    request.status = 'rejected';

    await request.save();

    /// أو إذا بدك حذف كامل:
    // await request.deleteOne();

    res.json({
      success: true,
      message: 'Banner request rejected',
    });

  } catch (e) {

    console.log('REJECT REQUEST ERROR =>', e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};
const getChefBanners = async (req, res) => {
  try {
    const banners = await Banner.find({
      chef: req.params.chefId,
    }).sort({ createdAt: -1 });

    res.json({
      success: true,
      banners,
    });
  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};
const markBannerRequestRead = async (req, res) => {
  try {
    const request = await BannerRequest.findById(req.params.id);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found',
      });
    }

    request.read = true;

    await request.save();

    res.json({
      success: true,
      message: 'Banner request marked as read',
    });

  } catch (e) {
    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};
/// =======================================================
/// GET MY REQUESTS
/// =======================================================

const getMyBannerRequests = async (req, res) => {
  try {

    const chefId = req.user.userId;

    const chef = await Chef.findOne({
      userId: chefId,
    });

    if (!chef) {
      return res.status(404).json({
        success: false,
        message: 'Chef not found',
      });
    }

    const requests = await BannerRequest.find({
      chef: chef._id,
    }).sort({
      createdAt: -1,
    });

    res.json({
      success: true,
      requests,
    });

  } catch (e) {

    console.log(e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};
/// =======================================================
/// EXPORTS
/// =======================================================
module.exports = {
  createBannerRequest,
  getBannerRequests,
  approveBannerRequest,
  rejectBannerRequest,
  getChefBanners,
  getMyBannerRequests,
  markBannerRequestRead,
};