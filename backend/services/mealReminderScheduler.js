const MealReminderSetting = require("../models/MealReminderSetting");
const { createNotification } = require("./notificationService");

const timersByUser = new Map();

const MEAL_LABELS = {
  breakfast: "Breakfast",
  lunch: "Lunch",
  snack: "Snack",
  dinner: "Dinner",
};

function cancelMealReminders(userId) {
  const key = userId?.toString();
  if (!key) return;

  const timers = timersByUser.get(key) || [];
  for (const timer of timers) {
    clearTimeout(timer);
  }

  timersByUser.delete(key);
}

function parseTime(time) {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time || "");
  if (!match) return null;
  return {
    hour: Number(match[1]),
    minute: Number(match[2]),
  };
}

function nextUtcDateForLocalTime(time, timezoneOffsetMinutes) {
  const parsed = parseTime(time);
  if (!parsed) return null;

  const offsetMs = Number(timezoneOffsetMinutes || 0) * 60 * 1000;
  const nowMs = Date.now();
  const localNow = new Date(nowMs + offsetMs);

  let year = localNow.getUTCFullYear();
  let month = localNow.getUTCMonth();
  let day = localNow.getUTCDate();

  let candidateUtcMs =
    Date.UTC(year, month, day, parsed.hour, parsed.minute, 0, 0) - offsetMs;

  if (candidateUtcMs <= nowMs) {
    const tomorrowLocal = new Date(
      Date.UTC(year, month, day + 1, parsed.hour, parsed.minute, 0, 0)
    );
    year = tomorrowLocal.getUTCFullYear();
    month = tomorrowLocal.getUTCMonth();
    day = tomorrowLocal.getUTCDate();
    candidateUtcMs =
      Date.UTC(year, month, day, parsed.hour, parsed.minute, 0, 0) - offsetMs;
  }

  return new Date(candidateUtcMs);
}

function scheduleMealReminders(setting) {
  const userKey = setting?.userId?.toString();
  if (!userKey) return { scheduledCount: 0 };

  cancelMealReminders(userKey);

  if (!setting.enabled) {
    return { scheduledCount: 0 };
  }

  const timers = [];
  const reminders = Array.isArray(setting.reminders) ? setting.reminders : [];

  for (const reminder of reminders) {
    if (!reminder.enabled) continue;

    const mealType = reminder.mealType?.toString();
    const label = MEAL_LABELS[mealType] || "Meal";
    const nextDate = nextUtcDateForLocalTime(
      reminder.time,
      setting.timezoneOffsetMinutes
    );

    if (!nextDate) continue;

    const delayMs = Math.max(0, nextDate.getTime() - Date.now());

    const timer = setTimeout(async () => {
      try {
        await createNotification({
          recipientId: userKey,
          actorId: "",
          type: "meal_reminder",
          title: `${label} reminder`,
          body: `Time for ${label.toLowerCase()}. Keep your meal plan on track.`,
          extraPayload: {
            reminderType: "meal",
            mealType,
            scheduledTime: reminder.time,
          },
        });

        const latest = await MealReminderSetting.findOne({
          userId: userKey,
        }).lean();
        if (latest) {
          scheduleMealReminders(latest);
        }
      } catch (error) {
        console.error("[mealReminderScheduler] send failed:", error.message);
      }
    }, delayMs);

    if (typeof timer.unref === "function") {
      timer.unref();
    }

    timers.push(timer);
  }

  timersByUser.set(userKey, timers);

  console.log(
    `[mealReminderScheduler] Scheduled ${timers.length} meal reminders for ${userKey}`
  );

  return { scheduledCount: timers.length };
}

async function bootstrapMealReminderScheduler() {
  try {
    const settings = await MealReminderSetting.find({ enabled: true }).lean();
    let total = 0;

    for (const setting of settings) {
      total += scheduleMealReminders(setting).scheduledCount;
    }

    console.log(
      `[mealReminderScheduler] Bootstrapped ${total} meal reminders`
    );
  } catch (error) {
    console.error("[mealReminderScheduler] bootstrap failed:", error.message);
  }
}

module.exports = {
  scheduleMealReminders,
  cancelMealReminders,
  bootstrapMealReminderScheduler,
};
