const express = require('express');

const router = express.Router();

const {

  createOrder,
  getChefOrders,
  getAllOrders,
  updateOrderStatus,

} = require('../controllers/orderController');

const {

  verifyToken,

} = require('../middleware/authMiddleware');

// ✅ CREATE ORDER
router.post(
  '/create',

  verifyToken,

  createOrder,
);

// ✅ GET CHEF ORDERS
router.get(
  '/chef/:chefId',

  getChefOrders,
);

// ✅ ADMIN GET ALL ORDERS
router.get(
  '/all',

  verifyToken,

  getAllOrders,
);

// ✅ UPDATE ORDER STATUS
router.put(
  '/:id/status',

  verifyToken,

  updateOrderStatus,
);

module.exports = router;