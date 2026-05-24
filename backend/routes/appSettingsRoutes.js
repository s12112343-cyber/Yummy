const express =
  require("express");

const router =
  express.Router();

const {
  getSettings,
  updateIcon,
} = require(
  "../controllers/appSettingsController",
);


// GET
router.get(
  "/",
  getSettings,
);


// PATCH
router.patch(
  "/icon",
  updateIcon,
);

module.exports =
  router;