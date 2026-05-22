const nutritionDB = require('./nutritionDB');
const fetchNutritionFromAPI = require('./fetchNutritionAPI');
const Ingredient = require('../models/Ingredient');

// 🔥 mapping ذكي
const ingredientMap = {

  chicken: [
    'chicken',
    'chicken breast',
    'grilled chicken',
    'fried chicken',
    'crispy chicken',
    'chicken thighs',
    'chicken wings',
  ],

  rice: [
    'rice',
    'white rice',
    'basmati rice',
    'brown rice',
    'fried rice',
    'rice batter',
  ],

  pasta: [
    'pasta',
    'spaghetti',
    'macaroni',
    'lasagna',
    'penne',
    'fettuccine',
    'noodles',
  ],

  cheese: [
    'cheese',
    'mozzarella',
    'cheddar',
    'parmesan',
    'parmesan cheese',
    'cream cheese',
    'feta',
    'mascarpone',
  ],

  potato: [
    'potato',
    'potatoes',
    'sweet potato',
    'fries',
    'french fries',
  ],

  beef: [
    'beef',
    'meat',
    'steak',
    'burger meat',
    'minced beef',
  ],

  egg: [
    'egg',
    'eggs',
    'boiled egg',
    'fried egg',
  ],

  milk: [
    'milk',
    'whole milk',
    'skim milk',
  ],

  tomato: [
    'tomato',
    'tomatoes',
    'cherry tomato',
  ],

  cucumber: [
    'cucumber',
    'pickles',
  ],

  shrimp: [
    'shrimp',
    'prawns',
  ],

  fish: [
    'fish',
    'salmon',
    'tuna',
    'cod',
  ],

  squid: [
    'squid',
    'calamari',
  ],

  avocado: [
    'avocado',
    'guacamole',
  ],

  olive_oil: [
    'olive oil',
    'oil',
  ],

  banana: [
    'banana',
    'bananas',
  ],

  spinach: [
    'spinach',
  ],

  tofu: [
    'tofu',
  ],

  quinoa: [
    'quinoa',
  ],

  almond: [
    'almond',
    'almonds',
  ],

  chocolate: [
    'chocolate',
    'dark chocolate',
    'milk chocolate',
  ],

  flour: [
    'flour',
    'white flour',
  ],

  sugar: [
    'sugar',
    'brown sugar',
  ],

  coffee: [
    'coffee',
    'espresso',
    'latte',
  ],

  biscuits: [
    'biscuits',
    'cookies',
  ],

  matcha: [
    'matcha',
    'green tea powder',
  ],

  chickpeas: [
    'chickpeas',
    'hummus',
  ],

  zucchini: [
    'zucchini',
    'courgette',
  ],

  pesto: [
    'pesto',
  ],

  olives: [
    'olives',
    'black olives',
    'green olives',
  ],

  lamb: [
    'lamb',
    'lamb meat',
  ],

  garlic: [
    'garlic',
    'garlic cloves',
    'minced garlic',
  ],

  onion: [
    'onion',
    'onions',
    'red onion',
    'white onion',
  ],

  cream: [
    'cream',
    'cooking cream',
    'heavy cream',
    'whipping cream',
  ],

  bread: [
    'bread',
    'toast',
    'burger bun',
  ],

  salmon: [
    'salmon',
    'smoked salmon',
  ],
  garlic: {
  calories: 149,
  fat: 0.5,
  protein: 6.4,
  potassium: 401,
},

butter: {
  calories: 717,
  fat: 81,
  protein: 0.9,
  potassium: 24,
},
};

// 🔥 تنظيف النص
function normalize(text = '') {
  return text
    .toLowerCase()
    .replace(/[^a-z ]/g, '')
    .trim();
}

// 🔥 إيجاد المفتاح
function findIngredientKey(name = '') {
  const clean = normalize(name);

  // alias match
  for (const key in ingredientMap) {
    const aliases = ingredientMap[key];
    if (Array.isArray(aliases)) {
      if (aliases.some(alias => clean.includes(alias))) {
        return key;
      }
    }
  }

  // fallback DB
  for (const key of Object.keys(nutritionDB)) {
  if (
    clean.includes(key) ||
    key.includes(clean)
  ) {
    return key;
  }
}

  return null;
}

// 🔥🔥🔥 الدالة الرئيسية (ASYNC)
async function calculateNutrition(ingredients = []) {
  let calories = 0;
  let fat = 0;
  let protein = 0;
  let potassium = 0;

  const unknownIngredients = [];
  const seen = new Set(); // 🔥 منع التكرار

  for (const item of ingredients) {
    const name = item?.name?.toLowerCase().trim();
    if (!name) continue;

    // 🔥 skip duplicates
    if (seen.has(name)) continue;
    seen.add(name);

    const key = findIngredientKey(name);

    const quantity = Number(item?.quantity) || 100;
    const factor = quantity / 100;

    console.log("INGREDIENT:", name, "→ KEY:", key);

    // ✅ 1. إذا موجود في local DB
    if (key && nutritionDB[key]) {
      const data = nutritionDB[key];

      calories += data.calories * factor;
      fat += data.fat * factor;
      protein += data.protein * factor;
      potassium += data.potassium * factor;

    } else {
      // 🔥 2. CACHE (DB check)
      const existing = await Ingredient.findOne({
        name: name.toLowerCase()
      });

      if (existing) {
        console.log("⚡ CACHE HIT:", name);

        calories += existing.calories * factor;
        fat += existing.fat * factor;
        protein += existing.protein * factor;
        potassium += existing.potassium * factor;

      } else {
        // 🔥 3. API fallback
        console.log("🌐 API CALL:", name);

        const apiData = await fetchNutritionFromAPI(name);

        if (apiData && apiData.calories > 0) {

          // 🔥 خزنه في DB (cache)
          await Ingredient.create({
            name: name.toLowerCase(),
            ...apiData,
          });

          calories += apiData.calories * factor;
          fat += apiData.fat * factor;
          protein += apiData.protein * factor;
          potassium += apiData.potassium * factor;

        } else {
          console.log("❌ UNKNOWN:", name);
await Ingredient.create({
  name: name.toLowerCase(),
  calories: 0,
  fat: 0,
  protein: 0,
  potassium: 0,
});        }
      }
    }
  }

  return {
    calories: Math.round(calories),
    fat: Number(fat.toFixed(1)),
    protein: Number(protein.toFixed(1)),
    potassium: Math.round(potassium),
    unknownIngredients,
  };
}

module.exports = calculateNutrition;