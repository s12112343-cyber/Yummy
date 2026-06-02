const express = require("express");
const router = express.Router();

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

module.exports = router;