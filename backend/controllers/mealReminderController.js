const MealReminderSetting = require("../models/MealReminderSetting");
const { scheduleMealReminders } = require("../services/mealReminderScheduler");

const DEFAULT_REMINDERS = [
  { mealType: "breakfast", enabled: true, time: "08:00" },
  { mealType: "lunch", enabled: true, time: "13:00" },
  { mealType: "snack", enabled: true, time: "16:30" },
  { mealType: "dinner", enabled: true, time: "19:30" },
];

const VALID_MEALS = new Set(["breakfast", "lunch", "snack", "dinner"]);

function normalizeReminder(item, fallback) {
  const mealType = item?.mealType?.toString() || fallback.mealType;
  const time = item?.time?.toString() || fallback.time;
  const isValidTime = /^([01]\d|2[0-3]):[0-5]\d$/.test(time);

  return {
    mealType: VALID_MEALS.has(mealType) ? mealType : fallback.mealType,
    enabled:
      item?.enabled === undefined ? fallback.enabled : Boolean(item.enabled),
    time: isValidTime ? time : fallback.time,
  };
}

function normalizeReminders(rawReminders) {
  const byType = new Map();

  if (Array.isArray(rawReminders)) {
    for (const item of rawReminders) {
      const mealType = item?.mealType?.toString();
      if (VALID_MEALS.has(mealType)) {
        byType.set(mealType, item);
      }
    }
  }

  return DEFAULT_REMINDERS.map((fallback) =>
    normalizeReminder(byType.get(fallback.mealType), fallback)
  );
}

async function getMealReminders(req, res) {
  try {
    const userId = req.user.userId;
    let setting = await MealReminderSetting.findOne({ userId }).lean();

    if (!setting) {
      setting = await MealReminderSetting.create({
        userId,
        enabled: true,
        timezoneOffsetMinutes: Number(req.query.timezoneOffsetMinutes || 0),
        reminders: DEFAULT_REMINDERS,
      });
      setting = setting.toObject();
      scheduleMealReminders(setting);
    }

    return res.status(200).json({
      success: true,
      settings: {
        enabled: setting.enabled,
        timezoneOffsetMinutes: setting.timezoneOffsetMinutes || 0,
        reminders: normalizeReminders(setting.reminders),
      },
    });
  } catch (error) {
    console.error("[mealReminderController] get failed:", error.message);
    return res.status(500).json({ success: false, message: "Server error" });
  }
}

async function updateMealReminders(req, res) {
  try {
    const userId = req.user.userId;
    const enabled =
      req.body.enabled === undefined ? true : Boolean(req.body.enabled);
    const timezoneOffsetMinutes = Number(req.body.timezoneOffsetMinutes || 0);
    const reminders = normalizeReminders(req.body.reminders);

    const setting = await MealReminderSetting.findOneAndUpdate(
      { userId },
      {
        $set: {
          userId,
          enabled,
          timezoneOffsetMinutes,
          reminders,
        },
      },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).lean();

    const schedule = scheduleMealReminders(setting);

    return res.status(200).json({
      success: true,
      message: "Meal reminders updated",
      reminders: schedule,
      settings: {
        enabled: setting.enabled,
        timezoneOffsetMinutes: setting.timezoneOffsetMinutes || 0,
        reminders: normalizeReminders(setting.reminders),
      },
    });
  } catch (error) {
    console.error("[mealReminderController] update failed:", error.message);
    return res.status(500).json({ success: false, message: "Server error" });
  }
}

module.exports = {
  getMealReminders,
  updateMealReminders,
};
