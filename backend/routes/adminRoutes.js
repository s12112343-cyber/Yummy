const express = require("express");

const router = express.Router();

const {
  verifyToken,
  adminOnly,
} = require("../middleware/authMiddleware");

const {
  getReports,
} = require("../controllers/adminController");

router.get(
  "/reports",
  verifyToken,
  adminOnly,
  getReports
);

module.exports = router;