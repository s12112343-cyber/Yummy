const MealEntry = require("../models/MealEntry");
const DailyWaterEntry = require("../models/DailyWaterEntry");
const UserProfile = require("../models/UserProfile");
const { analyzeQuickAddText } = require("../services/quickAddNutritionService");
const { analyzeFoodImageWithAI } = require("../services/aiFoodVisionService");
const { assessMealRestrictions } = require("../utils/mealRestrictionRules");
const fs = require("fs/promises");

const allowedMealTypes = new Set(["breakfast", "lunch", "snack", "dinner"]);

const toDateKey = (value) => {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return null;
  return trimmed;
};

const dateFromDateKey = (dateKey) => {
  const [year, month, day] = dateKey.split("-").map((part) => Number(part));
  return new Date(year, month - 1, day);
};

const dateKeyFromDate = (date) => {
  const year = date.getFullYear().toString().padStart(4, "0");
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const numberOrZero = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return parsed;
};

const currentDateKey = () => dateKeyFromDate(new Date());

const addDaysToDateKey = (dateKey, days) => {
  const date = dateFromDateKey(dateKey);
  date.setDate(date.getDate() + days);
  return dateKeyFromDate(date);
};

const resolvePeriodRange = (period) => {
  const normalized = (period || "week").toString().trim().toLowerCase();
  const todayKey = currentDateKey();

  if (normalized === "all") {
    return {
      period: "all",
      label: "All time",
      startDateKey: null,
      endDateKey: null,
      days: null,
    };
  }

  if (normalized === "month") {
    return {
      period: "month",
      label: "Last 30 days",
      startDateKey: addDaysToDateKey(todayKey, -29),
      endDateKey: todayKey,
      days: 30,
    };
  }

  return {
    period: "week",
    label: "Last 7 days",
    startDateKey: addDaysToDateKey(todayKey, -6),
    endDateKey: todayKey,
    days: 7,
  };
};

const buildDateKeySeries = (startDateKey, endDateKey) => {
  if (!startDateKey || !endDateKey) return [];

  const dates = [];
  let cursor = dateFromDateKey(startDateKey);
  const lastDate = dateFromDateKey(endDateKey);

  while (cursor <= lastDate) {
    dates.push(dateKeyFromDate(cursor));
    cursor = new Date(cursor);
    cursor.setDate(cursor.getDate() + 1);
  }

  return dates;
};

const addMealsBatch = async (req, res) => {
  try {
    const userId = req.user.userId;
    const mealType = (req.body.mealType || "").toString().trim().toLowerCase();
    const dateKey = toDateKey(req.body.dateKey);
    const meals = Array.isArray(req.body.meals) ? req.body.meals : [];
    const bypassRestrictions =
      req.body.bypassRestrictions === true || req.body.bypassRestrictions === "true";

    if (!allowedMealTypes.has(mealType)) {
      return res.status(400).json({ message: "Invalid meal type" });
    }

    if (!dateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    if (meals.length === 0) {
      return res.status(400).json({ message: "No meals to save" });
    }

    const profile = await UserProfile.findOne({ user_id: userId }).lean();
    const restrictions = profile
      ? {
          allergies: Array.isArray(profile.allergies) ? profile.allergies : [],
          medical_conditions: Array.isArray(profile.medical_conditions)
            ? profile.medical_conditions
            : [],
        }
      : { allergies: [], medical_conditions: [] };

    const dayDate = dateFromDateKey(dateKey);

    const blockingIssues = [];

    const docs = meals
      .map((meal) => {
        const mealName = (meal.mealName || "").toString().trim();
        if (!mealName) return null;

        const ingredients = Array.isArray(meal.ingredients)
          ? meal.ingredients.map((item) => (item || "").toString())
          : [];
        const possibleAllergens = Array.isArray(meal.possibleAllergens)
          ? meal.possibleAllergens.map((item) => (item || "").toString())
          : [];

        const restrictionResult = assessMealRestrictions(
          {
            mealName,
            ingredients,
            possibleAllergens,
            calories: numberOrZero(meal.calories),
            protein: numberOrZero(meal.protein),
            carbs: numberOrZero(meal.carbs),
            fat: numberOrZero(meal.fat),
          },
          restrictions
        );

        if (restrictionResult.hasBlockedIssues && !bypassRestrictions) {
          blockingIssues.push({
            mealName,
            issues: restrictionResult.issues,
          });
          return null;
        }

        return {
          user: userId,
          date: dayDate,
          date_key: dateKey,
          meal_type: mealType,
          meal_name: mealName,
          calories: numberOrZero(meal.calories),
          protein: numberOrZero(meal.protein),
          carbs: numberOrZero(meal.carbs),
          fat: numberOrZero(meal.fat),
          grams: numberOrZero(meal.grams),
        };
      })
      .filter(Boolean);

    if (blockingIssues.length > 0) {
      return res.status(409).json({
        message: "One or more meals conflict with your saved allergies or medical conditions.",
        issues: blockingIssues,
      });
    }

    if (docs.length === 0) {
      return res.status(400).json({ message: "Meals payload is invalid" });
    }

    await MealEntry.insertMany(docs);

    return res.status(201).json({
      message: "Meals saved successfully",
      savedCount: docs.length,
      warnings: bypassRestrictions ? blockingIssues : undefined,
    });
  } catch (error) {
    console.error("Error saving meals:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const getDailySummary = async (req, res) => {
  try {
    const userId = req.user.userId;
    const requestedDateKey = toDateKey(req.query.dateKey);

    if (!requestedDateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    const entries = await MealEntry.find({
      user: userId,
      date_key: requestedDateKey,
    })
      .sort({ createdAt: 1 })
      .lean();

    const waterEntry = await DailyWaterEntry.findOne({
      user: userId,
      date_key: requestedDateKey,
    }).lean();

    const summary = {
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
    };

    const mealConsumedCalories = {
      breakfast: 0,
      lunch: 0,
      snack: 0,
      dinner: 0,
    };

    const mealNamesMap = {
      breakfast: [],
      lunch: [],
      snack: [],
      dinner: [],
    };

    for (const entry of entries) {
      summary.calories += numberOrZero(entry.calories);
      summary.protein += numberOrZero(entry.protein);
      summary.carbs += numberOrZero(entry.carbs);
      summary.fat += numberOrZero(entry.fat);

      if (mealConsumedCalories[entry.meal_type] != null) {
        mealConsumedCalories[entry.meal_type] += numberOrZero(entry.calories);
      }

      if (mealNamesMap[entry.meal_type] != null && entry.meal_name) {
        mealNamesMap[entry.meal_type].push(entry.meal_name);
      }
    }

    const mealNames = {
      breakfast: mealNamesMap.breakfast.join("\n"),
      lunch: mealNamesMap.lunch.join("\n"),
      snack: mealNamesMap.snack.join("\n"),
      dinner: mealNamesMap.dinner.join("\n"),
    };

    return res.status(200).json({
      dateKey: requestedDateKey,
      summary,
      mealConsumedCalories,
      mealNames,
      water: {
        consumedWaterMl: waterEntry ? numberOrZero(waterEntry.consumed_water_ml) : 0,
        dailyWaterGoalMl: waterEntry ? numberOrZero(waterEntry.daily_water_goal_ml) : null,
        lastDrinkTime: waterEntry?.last_drink_time || null,
      },
      entries,
    });
  } catch (error) {
    console.error("Error loading daily summary:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const getPeriodSummary = async (req, res) => {
  try {
    const userId = req.user.userId;
    const range = resolvePeriodRange(req.query.period);

    const mealQuery = { user: userId };
    const waterQuery = { user: userId };

    if (range.startDateKey && range.endDateKey) {
      mealQuery.date_key = { $gte: range.startDateKey, $lte: range.endDateKey };
      waterQuery.date_key = { $gte: range.startDateKey, $lte: range.endDateKey };
    }

    const [mealEntries, waterEntries] = await Promise.all([
      MealEntry.find(mealQuery).sort({ date_key: 1, createdAt: 1 }).lean(),
      DailyWaterEntry.find(waterQuery).sort({ date_key: 1 }).lean(),
    ]);

    const summary = {
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      waterConsumedMl: 0,
      mealCount: mealEntries.length,
      daysWithMeals: new Set(mealEntries.map((entry) => entry.date_key)).size,
      daysWithWater: new Set(waterEntries.map((entry) => entry.date_key)).size,
    };

    const mealTypeCounts = {
      breakfast: 0,
      lunch: 0,
      snack: 0,
      dinner: 0,
    };

    const mealTypeCalories = {
      breakfast: 0,
      lunch: 0,
      snack: 0,
      dinner: 0,
    };

    const waterSeriesMap = new Map();
    let latestWaterGoalMl = 3500;

    for (const entry of waterEntries) {
      const dateKey = entry.date_key;
      const consumedWaterMl = numberOrZero(entry.consumed_water_ml);
      summary.waterConsumedMl += consumedWaterMl;
      latestWaterGoalMl = numberOrZero(entry.daily_water_goal_ml) || latestWaterGoalMl;
      waterSeriesMap.set(dateKey, {
        dateKey,
        consumedWaterMl,
        dailyWaterGoalMl: numberOrZero(entry.daily_water_goal_ml),
      });
    }

    for (const entry of mealEntries) {
      const calories = numberOrZero(entry.calories);
      summary.calories += calories;
      summary.protein += numberOrZero(entry.protein);
      summary.carbs += numberOrZero(entry.carbs);
      summary.fat += numberOrZero(entry.fat);

      if (mealTypeCounts[entry.meal_type] != null) {
        mealTypeCounts[entry.meal_type] += 1;
      }

      if (mealTypeCalories[entry.meal_type] != null) {
        mealTypeCalories[entry.meal_type] += calories;
      }
    }

    const totalMacroGrams = summary.protein + summary.carbs + summary.fat;
    const macroPercentages = totalMacroGrams > 0
      ? {
          protein: (summary.protein / totalMacroGrams) * 100,
          carbs: (summary.carbs / totalMacroGrams) * 100,
          fat: (summary.fat / totalMacroGrams) * 100,
        }
      : {
          protein: 0,
          carbs: 0,
          fat: 0,
        };

    const waterSeries = range.period === "all"
      ? waterEntries.map((entry) => ({
          dateKey: entry.date_key,
          consumedWaterMl: numberOrZero(entry.consumed_water_ml),
          dailyWaterGoalMl: numberOrZero(entry.daily_water_goal_ml),
        }))
      : buildDateKeySeries(range.startDateKey, range.endDateKey).map((dateKey) => {
          const item = waterSeriesMap.get(dateKey);
          return {
            dateKey,
            consumedWaterMl: item?.consumedWaterMl || 0,
            dailyWaterGoalMl: item?.dailyWaterGoalMl || latestWaterGoalMl,
          };
        });

    const mealItems = mealEntries.map((entry) => ({
      mealType: entry.meal_type,
      mealName: entry.meal_name,
      calories: numberOrZero(entry.calories),
      protein: numberOrZero(entry.protein),
      carbs: numberOrZero(entry.carbs),
      fat: numberOrZero(entry.fat),
      grams: numberOrZero(entry.grams),
      dateKey: entry.date_key,
      createdAt: entry.createdAt || entry.created_at || null,
    }));

    return res.status(200).json({
      period: range.period,
      label: range.label,
      range: {
        startDateKey: range.startDateKey,
        endDateKey: range.endDateKey,
      },
      summary: {
        ...summary,
        averageCaloriesPerDay: range.period === "all"
          ? summary.daysWithMeals > 0
            ? summary.calories / summary.daysWithMeals
            : 0
          : summary.calories / (range.days || 1),
        averageWaterPerDay: range.period === "all"
          ? summary.daysWithWater > 0
            ? summary.waterConsumedMl / summary.daysWithWater
            : 0
          : summary.waterConsumedMl / (range.days || 1),
        dailyWaterGoalMl: latestWaterGoalMl,
      },
      mealTypeCounts,
      mealTypeCalories,
      macroPercentages,
      waterSeries,
      mealItems,
    });
  } catch (error) {
    console.error("Error loading period summary:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const updateDailyWater = async (req, res) => {
  try {
    const userId = req.user.userId;
    const dateKey = toDateKey(req.body.dateKey);
    const consumedWaterMl = numberOrZero(req.body.consumedWaterMl);
    const rawDailyWaterGoalMl = req.body.dailyWaterGoalMl;
    const lastDrinkTimeRaw = req.body.lastDrinkTime;

    if (!dateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    const dayDate = dateFromDateKey(dateKey);
    const parsedLastDrinkTime = lastDrinkTimeRaw ? new Date(lastDrinkTimeRaw) : null;
    const lastDrinkTime =
      parsedLastDrinkTime && !Number.isNaN(parsedLastDrinkTime.getTime())
        ? parsedLastDrinkTime
        : null;

    const existingEntry = await DailyWaterEntry.findOne({
      user: userId,
      date_key: dateKey,
    }).lean();

    const dailyWaterGoalMl = rawDailyWaterGoalMl == null
      ? numberOrZero(existingEntry?.daily_water_goal_ml || 3500)
      : numberOrZero(rawDailyWaterGoalMl) || numberOrZero(existingEntry?.daily_water_goal_ml || 3500);

    const waterEntry = await DailyWaterEntry.findOneAndUpdate(
      { user: userId, date_key: dateKey },
      {
        $set: {
          date: dayDate,
          consumed_water_ml: consumedWaterMl,
          daily_water_goal_ml: dailyWaterGoalMl,
          last_drink_time: lastDrinkTime,
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      }
    ).lean();

    return res.status(200).json({
      message: "Water updated successfully",
      water: {
        consumedWaterMl: numberOrZero(waterEntry.consumed_water_ml),
        dailyWaterGoalMl: numberOrZero(waterEntry.daily_water_goal_ml),
        lastDrinkTime: waterEntry.last_drink_time || null,
      },
    });
  } catch (error) {
    console.error("Error updating daily water:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const analyzeQuickAddMeal = async (req, res) => {
  try {
    const text = (req.body.text || "").toString().trim();
    const mealType = (req.body.mealType || "snack").toString().trim().toLowerCase();

    if (!text) {
      return res.status(400).json({ message: "text is required" });
    }

    const analysis = await analyzeQuickAddText(text, mealType);

    if (!analysis.items.length) {
      return res.status(400).json({ message: "Could not analyze foods from the text" });
    }

    return res.status(200).json({
      ...analysis,
      message: "Quick add analyzed successfully",
    });
  } catch (error) {
    console.error("Error analyzing quick add meal:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
};

const getPreviousMeals = async (req, res) => {
  try {
    const userId = req.user.userId;
    const rawLimit = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(rawLimit) && rawLimit > 0 ? Math.min(rawLimit, 100) : 50;

    // Convert userId to ObjectId for MongoDB
    const mongoose = require('mongoose');
    const userObjectId = mongoose.Types.ObjectId.isValid(userId) ? new mongoose.Types.ObjectId(userId) : userId;

    const previousMeals = await MealEntry.aggregate([
      { $match: { user: userObjectId } },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: "$meal_name",
          meal_name: { $first: "$meal_name" },
          meal_type: { $first: "$meal_type" },
          calories: { $first: "$calories" },
          protein: { $first: "$protein" },
          carbs: { $first: "$carbs" },
          fat: { $first: "$fat" },
          grams: { $first: "$grams" },
          lastUsed: { $first: "$createdAt" },
          count: { $sum: 1 },
        },
      },
      { $sort: { lastUsed: -1 } },
      { $limit: limit },
    ]).allowDiskUse(true);

    console.log(`[Previous Meals] User: ${userObjectId} | Found: ${previousMeals.length} unique meals`);

    return res.status(200).json({
      previousMeals: previousMeals.map((meal) => ({
        id: meal._id,
        mealName: meal.meal_name,
        mealType: meal.meal_type,
        calories: numberOrZero(meal.calories),
        protein: numberOrZero(meal.protein),
        carbs: numberOrZero(meal.carbs),
        fat: numberOrZero(meal.fat),
        grams: numberOrZero(meal.grams),
        timesUsed: meal.count,
        lastUsed: meal.lastUsed,
      })),
    });
  } catch (error) {
    console.error("Error loading previous meals:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const safeDeleteUploadedFile = async (filePath) => {
  if (!filePath) {
    return;
  }

  try {
    await fs.unlink(filePath);
  } catch (error) {
    if (error.code !== "ENOENT") {
      console.error("[AI Food Vision] Failed to delete uploaded file:", error.message);
    }
  }
};

const analyzePhotoAI = async (req, res) => {
  const uploadedFile = req.file;

  if (!uploadedFile) {
    return res.status(400).json({
      success: false,
      message: "Image file is required",
    });
  }

  try {
    console.log('[AI Food Vision] Uploaded file info:', {
      originalname: uploadedFile.originalname,
      path: uploadedFile.path,
      mimetype: uploadedFile.mimetype,
      size: uploadedFile.size,
    });

    console.log('[AI Food Vision] image received');

    const fileObj = {
      path: uploadedFile.path,
      mimetype: uploadedFile.mimetype,
      size: uploadedFile.size,
    };

    const data = await analyzeFoodImageWithAI(fileObj);

    console.log('[AI Food Vision] analyzeFoodImageWithAI result:', data);

    return res.status(200).json({
      success: true,
      data,
    });
  } catch (error) {
    console.error("[AI Food Vision] analyzePhotoAI failed:", error.message);
    if (error?.response) {
      console.error("[AI Food Vision] analyzePhotoAI error response:", error.response);
    }
    // If Gemini returned a quota / billing error, surface it clearly to the client
    const statusFromGemini = error?.response?.status || null;
    const geminiCode = error?.code || null;

    if (statusFromGemini === 429 || geminiCode === "insufficient_quota" || geminiCode === "RESOURCE_EXHAUSTED") {
      return res.status(402).json({
        success: false,
        message:
          "Gemini quota exceeded or billing issue: please check your Google AI Studio / Google Cloud billing settings.",
        raw: error?.response || null,
      });
    }

    return res.status(500).json({
      success: false,
      message: error.message || "Failed to analyze meal photo",
      raw: error?.response || null,
    });
  } finally {
    await safeDeleteUploadedFile(uploadedFile.path);
  }
};

// ============================================================================
// FETCH INGREDIENTS FOR MEAL (for smart ingredient recognition)
// ============================================================================

const fetchIngredientsForMeal = async (req, res) => {
  try {
    const { mealName } = req.body;

    if (
      !mealName ||
      typeof mealName !== "string" ||
      mealName.trim().length === 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Meal name is required",
        ingredients: [],
      });
    }

    const { fetchIngredientsForMeal: getIngredients } =
      require("../services/ingredientService");

    const ingredients = await getIngredients(mealName.trim());

    console.log(
      `[Fetch Ingredients] Meal: ${mealName} | Found: ${ingredients.length} ingredients`
    );

    return res.status(200).json({
      success: true,
      mealName: mealName.trim(),
      ingredients: ingredients || [],
      message:
        ingredients.length > 0
          ? `Found ${ingredients.length} ingredients for ${mealName}`
          : `No specific ingredients found for ${mealName}. Please use ingredient mode.`,
    });
  } catch (error) {
    console.error("Error fetching ingredients:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch ingredients",
      ingredients: [],
      error: error.message,
    });
  }
};

module.exports = {
  addMealsBatch,
  getDailySummary,
  getPeriodSummary,
  analyzeQuickAddMeal,
  analyzePhotoAI,
  getPreviousMeals,
  updateDailyWater,
  fetchIngredientsForMeal,
};
