const NotificationRequest = require('../models/NotificationRequest');


const User = require('../models/User');
const Notification = require('../models/Notification');

//
// 🔥 CREATE REQUEST FROM CHEF
//
const createRequest = async (req, res) => {
  try {
    const {
      title,
      message,
    } = req.body;

   const request = await NotificationRequest.create({
  chef: req.user.userId,

  chefName: req.body.chefName,

  title: req.body.title,

  message: req.body.message,

  status: 'pending',
});

    res.status(201).json({
      success: true,
      request,
    });
  } catch (e) {
    res.status(500).json({
      message: e.message,
    });
  }
};

//
// 🔥 GET ALL REQUESTS FOR ADMIN
//
const getAllRequests = async (req, res) => {
  try {
    const requests =
      await NotificationRequest.find()
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

//
// 🔥 APPROVE REQUEST
//
const approveNotificationRequest = async (
  req,
  res
) => {
  try {

    const request =
      await NotificationRequest.findById(
        req.params.id
      );

    if (!request) {
      return res.status(404).json({
        message: "Request not found",
      });
    }

    //
    // 🔥 GET ALL USERS
    //
    const users = await User.find();

    console.log(
      "USERS COUNT =>",
      users.length
    );

    //
    // 🔥 CREATE NOTIFICATIONS
    //
    const notifications = users
      .filter((u) => u?._id)
      .map((user) => ({
       recipientId:
  user.id.toString(),

        actorId:
          request.chef?.toString() || "",

        actorName:
          request.chefName || "Chef",

        actorImageUrl: "",

        type: "global",

        title: request.title,

        body: request.message,

        isRead: false,

        payload: {},
      }));

    console.log(
      "NOTIFICATIONS =>",
      notifications.length
    );

    //
    // 🔥 SAVE
    //
    await Notification.insertMany(
      notifications
    );
await Notification.create({
  recipientId:
    request.chef.toString(),

  actorName: 'Admin',

  actorImageUrl: '',

  type: 'global',

  title: 'Notification Approved ✅',

  body:
    'Admin approved your notification request',

  isRead: false,

  payload: {},
});
    //
    // 🔥 UPDATE REQUEST
    //
    request.status = "approved";
//
// 🔥 NOTIFY CHEF
//

    request.read = true;

    await request.save();

    res.json({
      success: true,
      message:
        "Notification approved successfully",
    });

  } catch (e) {

    console.log(
      "APPROVE ERROR =>",
      e
    );

    res.status(500).json({
      message: e.message,
    });
  }
};
//
// 🔥 REJECT REQUEST
//
const rejectRequest = async (req, res) => {
  try {
    const request =
      await NotificationRequest.findByIdAndUpdate(
        req.params.id,
        {
          status: 'rejected',
          read: true,
        },
        { new: true }
      );

    res.json({
      success: true,
      request,
    });
  } catch (e) {
    res.status(500).json({
      message: e.message,
    });
  }
};

module.exports = {
  createRequest,
  getAllRequests,
  rejectRequest,
  approveNotificationRequest,
};