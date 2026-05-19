const Banner = require('../models/Banner');

// ================= GET =================
const getBanners = async (req, res) => {
  try {
    const banners = await Banner.find({ isActive: true }).sort({ order: 1 });
    res.json({ success: true, banners });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ================= CREATE =================
const createBanner = async (req, res) => {
  try {
    const { image, link, order, expiryDate } = req.body;

    const banner = await Banner.create({
      image,
      link,
      order: order || 1,
      expiryDate: expiryDate || null,
      isActive: true,
    });

    res.status(201).json({ success: true, banner });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ================= UPDATE =================
const updateBanner = async (req, res) => {
  try {
    const { id } = req.params;
    const { image, link, order, expiryDate, isActive } = req.body;

    const banner = await Banner.findById(id);

    if (!banner) {
      return res.status(404).json({ message: 'Banner not found' });
    }

    if (image !== undefined) banner.image = image;
    if (link !== undefined) banner.link = link;
    if (order !== undefined) banner.order = order;
    if (expiryDate !== undefined) banner.expiryDate = expiryDate;
    if (isActive !== undefined) banner.isActive = isActive;

    await banner.save();

    res.json({
      success: true,
      banner,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ================= DELETE =================
const deleteBanner = async (req, res) => {
  try {
    const banner = await Banner.findByIdAndDelete(req.params.id);

    if (!banner) {
      return res.status(404).json({ message: 'Banner not found' });
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  getBanners,
  createBanner,
  updateBanner,
  deleteBanner,
};