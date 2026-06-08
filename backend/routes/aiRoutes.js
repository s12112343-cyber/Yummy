const express = require("express");
const { verifyToken } = require("../middleware/authMiddleware");
const router = express.Router();

const uniqueNonEmpty = (values) => {
  const seen = new Set();
  return values
    .map((value) => (value || "").toString().trim())
    .filter((value) => {
      if (!value || seen.has(value)) return false;
      seen.add(value);
      return true;
    });
};

const getGeminiConfig = () => {
  const apiKey =
    process.env.GEMINI_API_KEY_PRIMARY || process.env.GEMINI_API_KEY;

  const models = uniqueNonEmpty([
    process.env.GEMINI_MODEL_PRIMARY ||
      process.env.GEMINI_MODEL ||
      "gemini-2.5-flash",
    process.env.GEMINI_MODEL_FALLBACK,
    process.env.GEMINI_MODEL_SECONDARY,
    "gemini-2.0-flash",
    "gemini-1.5-flash",
  ]);

  return { apiKey, models };
};

const isTemporaryGeminiError = (data, message) => {
  const text = `${message || ""} ${data?.error?.status || ""} ${
    data?.error?.message || ""
  }`.toLowerCase();

  return (
    text.includes("high demand") ||
    text.includes("overloaded") ||
    text.includes("unavailable") ||
    text.includes("resource_exhausted") ||
    text.includes("too many requests") ||
    text.includes("rate limit") ||
    text.includes("quota")
  );
};

const extractJsonObject = (text) => {
  const cleaned = String(text || "")
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();

  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");

  if (start >= 0 && end > start) {
    return cleaned.slice(start, end + 1);
  }

  return cleaned;
};

const callGemini = async ({
  systemText,
  userText,
  temperature = 0.45,
  maxOutputTokens = 8192,
}) => {
  const { apiKey, models } = getGeminiConfig();

  if (!apiKey) {
    const err = new Error("Missing GEMINI API key");
    err.status = 500;
    throw err;
  }

  const payload = {
    systemInstruction: {
      parts: [{ text: systemText }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: userText }],
      },
    ],
    generationConfig: {
      temperature,
      maxOutputTokens,
      responseMimeType: "application/json",
    },
  };

  let lastError = null;

  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (response.ok) {
      return (
        data?.candidates?.[0]?.content?.parts
          ?.map((part) => part.text)
          .join("") || ""
      );
    }

    const geminiMessage = data?.error?.message || "Gemini request failed";
    const err = new Error(geminiMessage);
    err.status = 500;
    err.data = data;
    err.model = model;
    lastError = err;

    if (!isTemporaryGeminiError(data, geminiMessage)) {
      throw err;
    }

    console.warn(
      `[Gemini] temporary error on ${model}, trying fallback: ${geminiMessage}`
    );
  }

  const err = new Error(
    "Gemini is temporarily busy. Please try again in a few minutes."
  );
  err.status = 503;
  err.data = lastError?.data;
  throw err;
};

const parseMealPlanJson = (answer) => {
  const plan = JSON.parse(extractJsonObject(answer));

  if (!Array.isArray(plan?.days) || plan.days.length === 0) {
    const err = new Error("AI returned an empty meal plan");
    err.status = 502;
    throw err;
  }

  return plan;
};

const normalizePlanType = (value) => (value === "weekly" ? "weekly" : "daily");

const buildMealPlanPrompt = ({
  planType,
  profile,
  targets,
  mealTargets,
}) => {
  const daysCount = planType === "weekly" ? 7 : 1;

  const mealTargetText = (Array.isArray(mealTargets) ? mealTargets : [])
    .map(
      (meal) =>
        `- ${meal.label}: ${meal.calories} kcal, ${meal.carbs}g carbs, ${meal.protein}g protein, ${meal.fat}g fat`
    )
    .join("\n");

  return `
Create a personalized ${planType} nutrition plan for this user.

User profile:
- Name: ${profile?.name || "User"}
- Goal: ${profile?.goalLabel || "--"}
- Gender: ${profile?.genderLabel || "--"}
- Age: ${profile?.age || "unknown"}
- Height: ${profile?.heightText || "--"}
- Weight: ${profile?.weightText || "--"}
- Activity level: ${profile?.activityLabel || "--"}
- Allergies / restrictions: ${profile?.allergiesText || "None"}
- Medical conditions: ${profile?.medicalConditionsText || "None"}

Daily targets:
- Calories: ${targets?.dailyCalories || 0} kcal
- Carbs: ${targets?.dailyCarbs || 0}g
- Protein: ${targets?.dailyProtein || 0}g
- Fat: ${targets?.dailyFat || 0}g
- Water goal: ${targets?.dailyWaterGoalL || 0} L

Meal targets per day:
${mealTargetText}

Rules:
1. Generate exactly ${daysCount} day(s).
2. Each day must include exactly Breakfast, Lunch, Snack, Dinner.
3. Avoid every listed allergy/restriction.
4. Respect medical conditions with safer food choices.
5. Keep each meal close to its listed calories and macros. Daily totals should stay within 10% of the daily targets.
6. Use realistic foods and portions.
7. This is wellness meal-planning, not medical treatment. Do not recommend medication or clinical interventions.
8. Return ONLY valid JSON. No markdown, no explanation.

JSON shape:
{
  "days": [
    {
      "day": "Day 1",
      "total_calories": 0,
      "total_carbs": 0,
      "total_protein": 0,
      "total_fat": 0,
      "meals": [
        {
          "meal": "Breakfast",
          "name": "Meal name",
          "description": "Short portions and foods",
          "calories": 0,
          "carbs": 0,
          "protein": 0,
          "fat": 0
        }
      ]
    }
  ]
}
`;
};

router.post("/gemini", async (req, res) => {
  try {
    const userMessage = (req.body?.userMessage ?? "").toString();
    const history = Array.isArray(req.body?.history) ? req.body.history : [];
    const userProfileContext = (req.body?.userProfileContext ?? "").toString();

    const apiKey =
      process.env.GEMINI_API_KEY_PRIMARY || process.env.GEMINI_API_KEY;

    const model =
      process.env.GEMINI_MODEL_PRIMARY ||
      process.env.GEMINI_MODEL ||
      "gemini-2.5-flash";

    if (!apiKey) {
      return res.status(500).json({
        success: false,
        message: "Missing GEMINI API key",
      });
    }

    const contents = [];

    for (const item of history) {
      const role = item?.role === "assistant" ? "model" : "user";
      const text = (item?.text ?? "").toString();

      if (!text.trim()) continue;

      contents.push({
        role,
        parts: [{ text }],
      });
    }

    if (userMessage.trim()) {
      contents.push({
        role: "user",
        parts: [{ text: userMessage }],
      });
    }

    const payload = {
      systemInstruction: {
        parts: [
          {
            text:
              "You are Yummy AI assistant. Be helpful and concise.\n\n" +
              "User profile:\n" +
              (userProfileContext || "No profile data"),
          },
        ],
      },
      contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 4096,
      },
    };

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (!response.ok) {
      return res.status(500).json({
        success: false,
        message: "Gemini request failed",
        data,
      });
    }

    const answer =
      data?.candidates?.[0]?.content?.parts
        ?.map((p) => p.text)
        .join("") || "";

    return res.json({
      success: true,
      answer,
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: err.message || "Server error",
    });
  }
});

router.post("/meal-plan", verifyToken, async (req, res) => {
  try {
    const planType = normalizePlanType(req.body?.planType);
    const profile = req.body?.profile || {};
    const targets = req.body?.targets || {};
    const mealTargets = Array.isArray(req.body?.mealTargets)
      ? req.body.mealTargets
      : [];

    if (!mealTargets.length) {
      return res.status(400).json({
        success: false,
        message: "mealTargets are required",
      });
    }

    const dailyCalories = Number(targets?.dailyCalories || 0);
    const dailyProtein = Number(targets?.dailyProtein || 0);
    const dailyCarbs = Number(targets?.dailyCarbs || 0);

    if (dailyCalories <= 0 || dailyProtein <= 0 || dailyCarbs <= 0) {
      return res.status(400).json({
        success: false,
        message: "Complete profile targets are required",
      });
    }

    const prompt = buildMealPlanPrompt({
      planType,
      profile,
      targets,
      mealTargets,
    });
    const maxOutputTokens = planType === "weekly" ? 16384 : 8192;

    let plan;
    try {
      const answer = await callGemini({
        systemText:
          "You are Yummy's nutrition meal-plan generator. Create practical food plans that follow user restrictions and numeric nutrition targets. Return strict JSON only.",
        userText: prompt,
        maxOutputTokens,
      });

      plan = parseMealPlanJson(answer);
    } catch (firstError) {
      try {
        const retryAnswer = await callGemini({
          systemText:
            "Return only valid JSON for a Yummy meal plan. No markdown. No trailing comments. The response must parse with JSON.parse.",
          userText:
            prompt +
            "\n\nPrevious response was invalid. Regenerate the complete meal plan as strict JSON only.",
          temperature: 0.25,
          maxOutputTokens,
        });

        plan = parseMealPlanJson(retryAnswer);
      } catch (retryError) {
        const message =
          retryError?.message ||
          firstError?.message ||
          "AI returned invalid meal plan JSON";

        return res.status(retryError?.status || firstError?.status || 502).json({
          success: false,
          message,
          data: retryError?.data || firstError?.data,
        });
      }
    }

    const expectedDays = planType === "weekly" ? 7 : 1;
    if (plan.days.length !== expectedDays) {
      return res.status(502).json({
        success: false,
        message: `AI returned ${plan.days.length} day(s), expected ${expectedDays}`,
      });
    }

    return res.json({
      success: true,
      planType,
      plan,
    });
  } catch (err) {
    return res.status(err.status || 500).json({
      success: false,
      message: err.message || "Server error",
      data: err.data,
    });
  }
});

module.exports = router;
