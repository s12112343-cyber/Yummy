const Order = require('../models/Order');

const createOrder = async (req, res) => {

  try {

    const userId =
        req.user.userId;

    const {

      chefId,
      dishName,
      dishImage,

      quantity,
      price,

      totalPrice,

      phone,
      city,
      street,

      paymentMethod,

      specialInstructions,

    } = req.body;

    // 🔥 VALIDATION
    if (!chefId) {

      return res.status(400).json({

        success: false,

        message:
            'chefId is required',
      });
    }

    // 🔥 SAFE NUMBERS
    const parsedQuantity =

        Number(quantity) || 1;

    const parsedPrice =

        Number(price) || 0;

    // 🔥 FINAL TOTAL PRICE
    const finalTotalPrice =

        totalPrice != null

            ? Number(totalPrice)

            : parsedPrice *
                parsedQuantity;

    // 🔥 CREATE ORDER
    const order =
        await Order.create({

      chefId,
      userId,

      dishName,
      dishImage,

      quantity:
          parsedQuantity,

      price:
          parsedPrice,

      totalPrice:
          finalTotalPrice,

      phone,
      city,
      street,

      paymentMethod,

      specialInstructions,

      customerName:

          req.user.name || '',

      customerAvatar:

          req.user.profileImage || '',

      status: 'pending',
    });

    // 🔥 SOCKET REALTIME
    const io =
        req.app.get('io');

    if (io) {

      io.to(chefId)
          .emit(
            'newOrder',
            order,
          );
    }

    res.status(201).json({

      success: true,

      order,
    });

  } catch (e) {

    console.log(
      'CREATE ORDER ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};
const getChefOrders = async (
  req,
  res,
) => {

  try {

    const chefId =
        req.params.chefId;

    // ✅ FIX NULL
    if (

        !chefId ||

        chefId === 'null' ||

        chefId === 'undefined'

    ) {

      return res.status(400).json({

        success: false,

        message:
            'chefId is required',
      });
    }

    const orders =
        await Order.find({

      chefId,
    })

    .populate(

      'userId',

      'name email profileImage',
    )

    .sort({

      createdAt: -1,
    });

    res.json({

      success: true,

      orders,
    });

  } catch (e) {

    console.log(

      'GET CHEF ORDERS ERROR =>',

      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};
const getAllOrders = async (
  req,
  res,
) => {

  try {

    const orders = await Order.find()

      .populate({
        path: 'chefId',

        populate: {
          path: 'userId',
          select: 'name profileImage',
        },
      })

      .populate(
        'userId',
        'name email profileImage',
      )

      .sort({
        createdAt: -1,
      });

    // 🔥 FIX UNKNOWN CHEF
    const formattedOrders =
        orders.map((order) => ({

      ...order._doc,

      chefId: {

        ...order.chefId?._doc,

        name:

            order.chefId?.businessName ||

            order.chefId?.userId?.name ||

            'Unknown Chef',
      },
    }));

    res.json({

      success: true,

      orders: formattedOrders,
    });

  } catch (e) {

    console.log(
      'GET ALL ORDERS ERROR =>',
      e,
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};
const updateOrderStatus = async (
  req,
  res,
) => {

  try {

    const { status } = req.body;

    const order =
        await Order.findByIdAndUpdate(

      req.params.id,

      {
        status:
            status.toString().toLowerCase(),
      },

      {
        new: true,
      }
    );

    if (!order) {

      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    const io = req.app.get('io');

    io.emit(
      'orderStatusUpdated',
      order,
    );

    res.json({
      success: true,
      order,
    });

  } catch (e) {

    console.log(
      'UPDATE STATUS ERROR =>',
      e,
    );

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
  updateOrderStatus,
};