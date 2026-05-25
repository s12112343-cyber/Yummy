const express = require('express');

const router = express.Router();

const {

  createOrder,
  getChefOrders,
  getAllOrders,
  getUserOrders,
  updateOrderStatus,
  cancelUserOrder,

} = require('../controllers/orderController');

const {

  verifyToken,

} = require('../middleware/authMiddleware');

// ✅ CREATE ORDER
router.post('/create', verifyToken, createOrder);
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

// ✅ GET LOGGED-IN USER ORDERS
router.get(
  '/my',

  verifyToken,

  getUserOrders,
);

// ✅ UPDATE ORDER STATUS
router.put(
  '/:id/status',

  verifyToken,

  updateOrderStatus,
);

// ✅ CANCEL LOGGED-IN USER ORDER
router.put(
  '/:id/cancel',

  verifyToken,

  cancelUserOrder,
);

// Support POST for cancel as well (some clients may send POST instead of PUT)
router.post(
  '/:id/cancel',

  verifyToken,

  cancelUserOrder,
);

module.exports = router;