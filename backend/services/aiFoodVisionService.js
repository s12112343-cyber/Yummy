const fs = require("fs/promises");
const fsSync = require("fs");
const path = require("path");

const DEFAULT_RESULT = Object.freeze({
  mealName: "unknown",
  ingredients: [],
  possibleAllergens: [],
  confidence: 0,
  estimatedWeightGrams: 0,
  calories: 0,
  protein: 0,
  fat: 0,
  carbs: 0,
});

let client = null;

const getGeminiApiKey = () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured");
  }

  return apiKey;
};

const MIME_BY_EXTENSION = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
  ".gif": "image/gif",
  ".bmp": "image/bmp",
  ".tif": "image/tiff",
  ".tiff": "image/tiff",
  ".heic": "image/heic",
  ".heif": "image/heif",
};

const normalizeText = (value) => {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().replace(/\s+/g, " ");
};

const cleanIngredientName = (value) => {
  let text = normalizeText(value);

  if (!text) {
    return "";
  }

  text = text.replace(/^[\d\s./-]+/, "");
  text = text.replace(
    /^(?:about|around|approximately|approx\.?|roughly)\s+/i,
    ""
  );
  text = text.replace(
    /^(?:a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s+/i,
    ""
  );
  text = text.replace(
    /^(?:cups?|cupfuls?|tablespoons?|tbsp|teaspoons?|tsp|grams?|gram|g|kilograms?|kg|milliliters?|millilitres?|ml|liters?|litres?|ounces?|oz|pounds?|lb|pieces?|slices?|cloves?|cans?|packages?|packs?|pinches?|handfuls?)\b\s*/i,
    ""
  );
  text = text.replace(/\b(?:fresh|chopped|diced|minced|sliced|grilled|fried|baked|roasted|cooked|raw)\b/gi, "");
  text = text.replace(/[,.;:!?]+$/g, "");
  text = text.replace(/\s+/g, " ").trim();

  return text;
};

const normalizeList = (value) => {
  if (!Array.isArray(value)) {
    return [];
  }

  const seen = new Set();

  return value
    .map((item) => cleanIngredientName(item))
    .filter((item) => Boolean(item))
    .filter((item) => {
      const key = item.toLowerCase();
      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    });
};

const sanitizeMealName = (value) => {
  const text = normalizeText(value);
  if (!text) {
    return "unknown";
  }

  const lower = text.toLowerCase();
  if (lower === "unknown" || lower === "not food" || lower === "non-food") {
    return "unknown";
  }

  return text;
};

const sanitizeEstimatedWeight = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) {
    return 0;
  }

  // Keep a realistic range for a single plate meal estimate.
  return Math.max(30, Math.min(2000, Math.round(n)));
};

const getMimeType = (filePath) => {
  const extension = path.extname(filePath || "").toLowerCase();
  return MIME_BY_EXTENSION[extension] || "image/jpeg";
};

const toBase64DataUrl = (buffer, mimeType) => {
  return `data:${mimeType};base64,${buffer.toString("base64")}`;
};

const calculateNutrition = require('../utils/calcNutrition');

const parseModelContent = (content) => {
  if (typeof content !== "string" || !content.trim()) {
    return null;
  }

  try {
    return JSON.parse(content);
  } catch (_error) {
    const startIndex = content.indexOf("{");
    const endIndex = content.lastIndexOf("}");

    if (startIndex >= 0 && endIndex > startIndex) {
      try {
        return JSON.parse(content.slice(startIndex, endIndex + 1));
      } catch (_innerError) {
        return null;
      }
    }

    return null;
  }
};

const analyzeFoodImageWithAI = async (fileOrPath) => {
  if (!fileOrPath) return DEFAULT_RESULT;

  // Accept either a string path or an object { path, buffer, mimetype, size }
  let imageBuffer;
  let mimeType;
  let imagePath = null;

  if (typeof fileOrPath === "string") {
    imagePath = fileOrPath;
    imageBuffer = await fs.readFile(imagePath);
    mimeType = getMimeType(imagePath);
  } else if (fileOrPath && typeof fileOrPath === "object") {
    if (fileOrPath.buffer && Buffer.isBuffer(fileOrPath.buffer)) {
      imageBuffer = fileOrPath.buffer;
      mimeType = fileOrPath.mimetype || "image/jpeg";
    } else if (fileOrPath.path) {
      imagePath = fileOrPath.path;
      imageBuffer = await fs.readFile(imagePath);
      // If multer gave a generic 'application/octet-stream', prefer extension-based MIME
      const provided = (fileOrPath.mimetype || "").toLowerCase();
      const byExt = getMimeType(imagePath);
      if (!provided || provided === "application/octet-stream") {
        mimeType = byExt;
      } else {
        mimeType = provided;
      }
      console.log('[AI Food Vision] chosen mime type:', mimeType, { provided, byExt });
    } else {
      return DEFAULT_RESULT;
    }
  } else {
    return DEFAULT_RESULT;
  }

  console.log('[AI Food Vision] image received');
  console.log('[AI Food Vision] image size:', imageBuffer.length);
  console.log('[AI Food Vision] mime type:', mimeType);
  console.log('[AI Food Vision] preparing Gemini request');

  const prompt =
    'Analyze this food image and return only valid JSON in this exact shape: {"mealName":"string","ingredients":["ingredient name only"],"possibleAllergens":["allergen name only"],"confidence":0.0,"estimatedWeightGrams":0}. Ingredients must be names only, without quantities, weights, or descriptions. estimatedWeightGrams must be a single numeric estimate for the total edible portion in the image (in grams). If the image is not food, return {"mealName":"unknown","ingredients":[],"possibleAllergens":[],"confidence":0.0,"estimatedWeightGrams":0}.';

  const payload = {
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: mimeType,
              data: imageBuffer.toString("base64"),
            },
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
    },
  };

  try {
    const apiKey = getGeminiApiKey();
    const model = process.env.GEMINI_MODEL || "gemini-2.5-flash";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const responseJson = await response.json().catch(() => null);

    if (!response.ok) {
      const message = responseJson?.error?.message || `Gemini request failed with status ${response.status}`;
      const error = new Error(message);
      error.code = responseJson?.error?.status || `http_${response.status}`;
      error.response = responseJson;
      throw error;
    }

    const contentParts = responseJson?.candidates?.[0]?.content?.parts || [];
    const content = contentParts
      .map((part) => (typeof part?.text === "string" ? part.text : ""))
      .join("\n")
      .trim();

    console.log('[AI Food Vision] Gemini success');

    const parsed = parseModelContent(content) || {};
    const confidenceValue = Number(parsed.confidence);
    const confidence = Number.isFinite(confidenceValue)
      ? Math.max(0, Math.min(1, confidenceValue))
      : 0;

    const normalizedResult = {
      mealName: sanitizeMealName(parsed.mealName),
      ingredients: normalizeList(parsed.ingredients),
      possibleAllergens: normalizeList(parsed.possibleAllergens),
      confidence,
      estimatedWeightGrams: sanitizeEstimatedWeight(parsed.estimatedWeightGrams),
    };

    if (
      normalizedResult.mealName === "unknown" &&
      normalizedResult.ingredients.length === 0 &&
      normalizedResult.possibleAllergens.length === 0
    ) {
      return DEFAULT_RESULT;
    }

    // Estimate nutrition (calories, fat, protein, carbs)
    try {
      const ingredientCount = normalizedResult.ingredients.length;
      const totalEstimatedWeight = normalizedResult.estimatedWeightGrams;
      const perIngredientWeight =
        ingredientCount > 0 && totalEstimatedWeight > 0
          ? totalEstimatedWeight / ingredientCount
          : 100;

      const ingredientObjects = normalizedResult.ingredients.map((name) => ({
        name,
        quantity: perIngredientWeight,
      }));
      const nutrition = await calculateNutrition(ingredientObjects);

      const calories = Number(nutrition.calories) || 0;
      const fat = Number(nutrition.fat) || 0;
      const protein = Number(nutrition.protein) || 0;

      // Estimate carbs grams from calories if possible
      let carbs = 0;
      const estimated = calories - (protein * 4 + fat * 9);
      if (Number.isFinite(estimated) && estimated > 0) {
        carbs = Number((estimated / 4).toFixed(1));
      }

      normalizedResult.calories = Math.round(calories);
      normalizedResult.protein = Number(protein.toFixed(1));
      normalizedResult.fat = Number(fat.toFixed(1));
      normalizedResult.carbs = Number(carbs.toFixed(1));
    } catch (nutritionErr) {
      console.error('[AI Food Vision] nutrition estimation failed:', nutritionErr?.message || nutritionErr);
      normalizedResult.calories = 0;
      normalizedResult.protein = 0;
      normalizedResult.fat = 0;
      normalizedResult.carbs = 0;
    }

    return normalizedResult;
  } catch (err) {
    console.error('[AI Food Vision] Gemini error:', err?.message);
    try {
      const stats = fsSync.statSync(imagePath);
      console.error('[AI Food Vision] Gemini request failed for image:', imagePath, 'size:', stats.size);
    } catch (e) {
      console.error('[AI Food Vision] Gemini request failed; could not stat file:', imagePath);
    }

    console.error('[AI Food Vision] Gemini request error message:', err?.message);
    try {
      console.error('[AI Food Vision] error code:', err.code || null);
      if (err?.response) {
        console.error('[AI Food Vision] error response data:', JSON.stringify(err.response, null, 2));
      }
    } catch (logErr) {
      console.error('[AI Food Vision] failed to log error.response details:', logErr?.message || logErr);
    }

    throw err;
  }
};

module.exports = {
  analyzeFoodImageWithAI,
};