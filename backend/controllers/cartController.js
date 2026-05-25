const Cart = require('../models/Cart');

const normalizeCartItem = (item) => {
  const normalized = { ...item };

  const id = normalized.id ?? normalized._id ?? '';
  normalized.id = id.toString();
  normalized._id = (normalized._id ?? id).toString();
  normalized.quantity = Number.parseInt(normalized.quantity ?? 1, 10) || 1;
  normalized.price = Number(normalized.price ?? 0) || 0;
  normalized.size = (normalized.size ?? '').toString();

  return normalized;
};

const calculateTotalQty = (items = []) =>
  items.reduce((sum, item) => sum + (Number.parseInt(item.quantity ?? 1, 10) || 1), 0);

const getMyCart = async (req, res) => {
  try {
    const userId = req.user.userId;
    const cart = await Cart.findOne({ userId }).lean();

    const items = (cart?.items ?? []).map(normalizeCartItem);

    res.status(200).json({
      success: true,
      items,
      count: calculateTotalQty(items),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const saveMyCart = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { items } = req.body;

    if (!Array.isArray(items)) {
      return res.status(400).json({
        success: false,
        message: 'items must be an array',
      });
    }

    const normalizedItems = items.map(normalizeCartItem);

    const cart = await Cart.findOneAndUpdate(
      { userId },
      { userId, items: normalizedItems },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).lean();

    res.status(200).json({
      success: true,
      message: 'Cart saved successfully',
      items: (cart?.items ?? normalizedItems).map(normalizeCartItem),
      count: calculateTotalQty(cart?.items ?? normalizedItems),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const clearMyCart = async (req, res) => {
  try {
    const userId = req.user.userId;

    await Cart.deleteOne({ userId });

    res.status(200).json({
      success: true,
      message: 'Cart cleared successfully',
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  getMyCart,
  saveMyCart,
  clearMyCart,
};