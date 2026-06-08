const { createNotification } = require("./notificationService");

const timersByUser = new Map();

const WATER_STEP_ML = 250;
const MAX_REMINDERS = 12;
const DAY_END_HOUR = 22;

function dateKeyFromDate(date) {
  const year = date.getFullYear().toString().padStart(4, "0");
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatAmount(amountMl) {
  if (amountMl >= 1000 && amountMl % 1000 === 0) {
    return `${amountMl / 1000}L`;
  }

  if (amountMl >= 1000) {
    return `${(amountMl / 1000).toFixed(1)}L`;
  }

  return `${amountMl}ml`;
}

function cancelWaterReminders(userId) {
  const key = userId?.toString();
  if (!key) return;

  const timers = timersByUser.get(key) || [];
  for (const timer of timers) {
    clearTimeout(timer);
  }

  timersByUser.delete(key);
}

function scheduleWaterReminders({
  userId,
  dateKey,
  consumedWaterMl,
  dailyWaterGoalMl,
}) {
  const userKey = userId?.toString();
  if (!userKey) return { scheduledCount: 0 };

  cancelWaterReminders(userKey);

  const now = new Date();
  const todayKey = dateKeyFromDate(now);
  if (dateKey !== todayKey || dailyWaterGoalMl <= 0) {
    return { scheduledCount: 0 };
  }

  const remainingWaterMl = dailyWaterGoalMl - consumedWaterMl;
  if (remainingWaterMl <= 0) {
    return { scheduledCount: 0 };
  }

  const dayEnd = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    DAY_END_HOUR,
    0,
    0,
    0
  );

  if (now >= dayEnd) {
    return { scheduledCount: 0 };
  }

  const desiredReminderCount = Math.ceil(remainingWaterMl / WATER_STEP_ML);
  const reminderCount = Math.min(desiredReminderCount, MAX_REMINDERS);
  const remainingMs = dayEnd.getTime() - now.getTime();
  const intervalMs = Math.floor(remainingMs / (reminderCount + 1));

  if (reminderCount <= 0 || intervalMs <= 0) {
    return { scheduledCount: 0 };
  }

  const timers = [];

  for (let i = 0; i < reminderCount; i += 1) {
    const reminderNumber = i + 1;
    const delayMs = intervalMs * reminderNumber;
    const reminderAmountMl = Math.min(
      WATER_STEP_ML,
      dailyWaterGoalMl - (consumedWaterMl + WATER_STEP_ML * i)
    );
    const plannedTotalMl = Math.min(
      dailyWaterGoalMl,
      consumedWaterMl + WATER_STEP_ML * reminderNumber
    );

    const timer = setTimeout(async () => {
      try {
        await createNotification({
          recipientId: userKey,
          actorId: "",
          type: "water",
          title: "Water reminder",
          body: `Drink about ${formatAmount(
            reminderAmountMl
          )} now. Today's water target: ${formatAmount(plannedTotalMl)}.`,
          extraPayload: {
            reminderType: "water",
            reminderAmountMl,
            plannedTotalMl,
            dailyWaterGoalMl,
          },
        });
      } catch (error) {
        console.error("[waterReminderScheduler] send failed:", error.message);
      }
    }, delayMs);

    if (typeof timer.unref === "function") {
      timer.unref();
    }

    timers.push(timer);
  }

  timersByUser.set(userKey, timers);

  console.log(
    `[waterReminderScheduler] Scheduled ${timers.length} water reminders for ${userKey}`
  );

  return { scheduledCount: timers.length };
}

module.exports = {
  scheduleWaterReminders,
  cancelWaterReminders,
};
