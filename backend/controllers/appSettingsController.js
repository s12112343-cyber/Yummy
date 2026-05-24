const AppSettings =
  require("../models/AppSettings");


// GET SETTINGS
const getSettings =
  async (req, res) => {

    try {

      let settings =
        await AppSettings.findOne();

      if (!settings) {

        settings =
          await AppSettings.create({
            appIcon: "classic",
          });
      }

      res.status(200).json({
        success: true,
        settings,
      });

    } catch (e) {

      res.status(500).json({
        success: false,
        message: e.message,
      });
    }
};


// UPDATE ICON
const updateIcon =
  async (req, res) => {

    try {

      const { appIcon } =
        req.body;

      let settings =
        await AppSettings.findOne();

      if (!settings) {

        settings =
          await AppSettings.create({
            appIcon,
          });

      } else {

        settings.appIcon =
          appIcon;

        await settings.save();
      }

      res.status(200).json({
        success: true,
        message:
          "Icon updated",
        settings,
      });

    } catch (e) {

      res.status(500).json({
        success: false,
        message: e.message,
      });
    }
};

module.exports = {
  getSettings,
  updateIcon,
};