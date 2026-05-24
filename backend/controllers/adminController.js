const Order = require("../models/Order");
const Chef = require("../models/Chef");

const getReports = async (req, res) => {
  try {
    const { period } = req.query;

    let startDate = new Date();

    // ✅ FILTER PERIOD
    if (period === "day") {

      startDate.setHours(
        0,
        0,
        0,
        0
      );

    } else if (period === "week") {

      startDate.setDate(
        startDate.getDate() - 7
      );

    } else if (period === "month") {

      startDate.setMonth(
        startDate.getMonth() - 1
      );

    } else {

      startDate =
        new Date("2020-01-01");
    }

    // ✅ ACCEPT ALL POSSIBLE COMPLETED VALUES
    const completedStatuses = [
      "completed",
      "Completed",
      "done",
      "Done",
      "delivered",
      "Delivered",
    ];

    // ✅ GET COMPLETED ORDERS
  const completedOrders =
  await Order.find({

    status: {
      $in: completedStatuses,
    },
  });

    console.log(
      "COMPLETED ORDERS =>",
      completedOrders.length
    );

    // ✅ TOTAL REVENUE
    const totalRevenue =
      completedOrders.reduce(

        (sum, order) =>
          sum +
          Number(
            order.totalPrice || 0
          ),

        0
      );

    // ✅ COUNTS
    const totalOrders =
      completedOrders.length;

    const pendingOrders =
      await Order.countDocuments({

        status: {
          $in: [
            "pending",
            "Pending",
          ],
        },
      });

    const deliveredOrders =
      await Order.countDocuments({

        status: {
          $in: completedStatuses,
        },
      });

    const cancelledOrders =
      await Order.countDocuments({

        status: {
          $in: [
            "cancelled",
            "Cancelled",
          ],
        },
      });

    // ✅ AVERAGE
    const avgOrderValue =
      totalOrders > 0
        ? totalRevenue / totalOrders
        : 0;

    // ✅ TOP CHEFS
    const chefStats =
      await Order.aggregate([
        {
  $match: {

    status: {
      $in: completedStatuses,
    },

    chefId: {
      $ne: null,
    },
  },
},

        {
          $group: {

            _id: "$chefId",

            revenue: {
              $sum: {
                $toDouble:
                  "$totalPrice",
              },
            },

            ordersCount: {
              $sum: 1,
            },
          },
        },

        {
          $sort: {
            revenue: -1,
          },
        },

        {
          $limit: 5,
        },
      ]);

    console.log(
      "CHEF STATS =>",
      chefStats
    );

    const topChefs = [];

    for (const chefData of chefStats) {

      const chef =
        await Chef.findById(
          chefData._id
        ).populate("userId");

      console.log(
        "FOUND CHEF =>",
        chef
      );

      topChefs.push({

        name:
          chef?.businessName ||
          chef?.userId?.name ||
          "Unknown Chef",

        ordersCount:
          chefData.ordersCount || 0,

        revenue:
          Number(
            chefData.revenue || 0
          ),
      });
    }

    // ✅ POPULAR MEALS
    const mealStats =
      await Order.aggregate([
        {
          $match: {

            status: {
              $in: completedStatuses,
            },

            createdAt: {
              $gte: startDate,
            },
          },
        },

        {
          $group: {

            _id: "$dishName",

            revenue: {
              $sum: {
                $toDouble:
                  "$totalPrice",
              },
            },

            ordersCount: {
              $sum: 1,
            },
          },
        },

        {
          $sort: {
            revenue: -1,
          },
        },

        {
          $limit: 5,
        },
      ]);

    const popularMeals =
      mealStats.map((meal) => ({

        name:
          meal._id ||
          "Unknown Meal",

        ordersCount:
          meal.ordersCount || 0,

        revenue:
          Number(
            meal.revenue || 0
          ),
      }));
const allOrders = await Order.find();

console.log("========= ORDERS =========");

allOrders.forEach((o) => {
  console.log({
    status: o.status,
    totalPrice: o.totalPrice,
    chefId: o.chefId,
  });
});
    // ✅ RESPONSE
    res.status(200).json({

      success: true,

      reports: {

        // Revenue
        revenue:
          totalRevenue,

        totalRevenue,

        todayRevenue:
          totalRevenue,

        weeklyRevenue:
          totalRevenue,

        monthlyRevenue:
          totalRevenue,

        // Orders
        totalOrders,

        todayOrders:
          totalOrders,

        weeklyOrders:
          totalOrders,

        monthlyOrders:
          totalOrders,

        // Status
        pendingOrders,

        deliveredOrders,

        cancelledOrders,

        // Average
        avgOrderValue,

        // Analytics
        topChefs,

        popularMeals,
      },
    });

  } catch (e) {

    console.log(
      "GET REPORTS ERROR =>",
      e
    );

    res.status(500).json({

      success: false,

      message: e.message,
    });
  }
};

module.exports = {
  getReports,
};