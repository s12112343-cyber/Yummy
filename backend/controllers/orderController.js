const Order =
  require('../models/Order');

const Chef =
  require('../models/Chef');

const Notification =
  require('../models/Notification');

//
// ✅ CREATE ORDER
//
const createOrder = async (req, res) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Unauthorized: userId not found in token',
      });
    }

    const order = await Order.create({
      chefId: req.body.chefId,
      userId: userId, // ✅ من التوكن مش من Flutter
      recipeId: req.body.recipeId || req.body.id || req.body._id || null,

      dishName: req.body.dishName || '',
      dishImage: req.body.dishImage || '',
      customerName: req.body.customerName || '',
      customerAvatar: req.body.customerAvatar || '',

      quantity: req.body.quantity || 1,
      price: req.body.price || 0,
      totalPrice: req.body.totalPrice || 0,

      // optional size & nutrition
      size: req.body.size || '',
      calories: req.body.calories || 0,
      fat: req.body.fat || 0,
      protein: req.body.protein || 0,
      carbs: req.body.carbs || 0,

      phone: req.body.phone || '',
      city: req.body.city || '',
      street: req.body.street || '',
      paymentMethod: req.body.paymentMethod || 'cash',
      specialInstructions: req.body.specialInstructions || '',
      status: 'pending',
    });

    const chef = await Chef.findById(order.chefId);

    if (chef) {
      const notification = await Notification.create({
        recipientId: chef.userId.toString(),
        actorId: userId.toString(),
        actorName: order.customerName || 'Customer',
        actorImageUrl: order.customerAvatar || '',
        type: 'order',
        title: 'New Order 🍽️',
        body: `${order.customerName || 'Customer'} placed a new order`,
        isRead: false,
        payload: {
          orderId: order._id,
        },
      });

      const io = req.app.get('io');

      if (io) {
        io.to(chef.userId.toString()).emit(
          'newNotification',
          notification,
        );
      }

      console.log('🔥 ORDER NOTIFICATION SENT');
    }

    res.status(201).json({
      success: true,
      order,
    });
  } catch (e) {
    console.log('CREATE ORDER ERROR =>', e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};

//
// ✅ GET CHEF ORDERS
//
const getChefOrders =
async (req, res) => {

  try {

    const orders =
      await Order.find({

        chefId:
          req.params.chefId,
      }).sort({
        createdAt: -1,
      });

    res.json({

      success: true,

      orders,
    });

  } catch (e) {

    console.log(
      "GET CHEF ORDERS ERROR =>",
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

//
// ✅ GET ALL ORDERS
//
const getAllOrders =
async (req, res) => {

  try {

    const orders =
      await Order.find()
        .sort({
          createdAt: -1,
        });

    res.json({

      success: true,

      orders,
    });

  } catch (e) {

    console.log(
      "GET ALL ORDERS ERROR =>",
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

//
// ✅ GET USER ORDERS
//
const getUserOrders = async (req, res) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Unauthorized: userId not found in token',
      });
    }

    const orders = await Order.find({ userId })
      .sort({
        createdAt: -1,
      })
      .populate('chefId', 'name businessName image avatar');

    res.json({
      success: true,
      orders,
    });
  } catch (e) {
    console.log('GET USER ORDERS ERROR =>', e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};

//
// ✅ UPDATE ORDER STATUS
//
const updateOrderStatus =
async (req, res) => {

  try {

    const { status } =
      req.body;

    const order =
      await Order.findById(
        req.params.id
      );

    if (!order) {

      return res.status(404).json({
        success: false,
        message:
          'Order not found',
      });
    }

    //
    // 🔥 UPDATE STATUS
    //
    order.status =
      status.toString().toLowerCase();

    await order.save();

    //
    // 🔥 NOTIFICATION
    //
    let notificationTitle = '';

    let notificationBody = '';

    switch (
      status.toLowerCase()
    ) {

      case 'pending':

        notificationTitle =
          'Order Received 📦';

        notificationBody =
          'The chef received your order';

        break;

      case 'preparing':

        notificationTitle =
          'Preparing Order 👨‍🍳';

        notificationBody =
          'The chef is preparing your order';

        break;

      case 'completed':

        notificationTitle =
          'Order Completed ✅';

        notificationBody =
          'Your order is ready';

        break;

      case 'cancelled':

        notificationTitle =
          'Order Cancelled ❌';

        notificationBody =
          'Your order has been cancelled';

        break;
    }

    //
    // 🔥 SEND NOTIFICATION TO USER
    //
    if (
      notificationTitle !== ''
    ) {

      const notification =
        await Notification.create({

          recipientId:
            order.userId.toString(),

          actorId:
            order.chefId.toString(),

          actorName:
            'Chef',

          actorImageUrl: '',

          type:
            'order_status',

          title:
            notificationTitle,

          body:
            notificationBody,

          isRead: false,

          payload: {
            orderId:
              order._id,

            status:
              order.status,
          },
        });

      //
      // 🔥 REALTIME
      //
      const io =
        req.app.get('io');

      if (io) {

        io.to(
          order.userId.toString()
        ).emit(
          'newNotification',
          notification,
        );
      }

      console.log(
        "🔥 ORDER STATUS NOTIFICATION SENT"
      );
    }

    res.json({

      success: true,

      order,
    });

  } catch (e) {

    console.log(
      "UPDATE ORDER STATUS ERROR =>",
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

//
// ✅ CANCEL USER ORDER
//
const cancelUserOrder = async (req, res) => {
  try {
    const userId = req.user?.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Unauthorized: userId not found in token',
      });
    }

    const order = await Order.findById(req.params.id);

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    if (order.userId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Forbidden: this order does not belong to you',
      });
    }

    if (order.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: 'Only pending orders can be cancelled',
      });
    }

    order.status = 'cancelled';
    await order.save();

    const chef = await Chef.findById(order.chefId);

    if (chef) {
      const notification = await Notification.create({
        recipientId: chef.userId.toString(),
        actorId: userId.toString(),
        actorName: order.customerName || 'Customer',
        actorImageUrl: order.customerAvatar || '',
        type: 'order_status',
        title: 'Order Cancelled ❌',
        body: `${order.customerName || 'Customer'} cancelled the order`,
        isRead: false,
        payload: {
          orderId: order._id,
          status: order.status,
        },
      });

      const io = req.app.get('io');

      if (io) {
        io.to(chef.userId.toString()).emit('newNotification', notification);
      }
    }

    res.json({
      success: true,
      order,
    });
  } catch (e) {
    console.log('CANCEL USER ORDER ERROR =>', e);

    res.status(500).json({
      success: false,
      message: e.message,
    });
  }
};

module.exports = {

  createOrder,

  getChefOrders,

  getAllOrders,

  getUserOrders,

  updateOrderStatus,

  cancelUserOrder,
};

