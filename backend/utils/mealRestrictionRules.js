const normalizeText = (value) =>
  (value || '')
    .toString()
    .toLowerCase()
    .replace(/[^a-z0-9 ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeList = (value) => {
  if (!Array.isArray(value)) return [];
  return value.map((item) => normalizeText(item)).filter(Boolean);
};

const allergyAliases = {
  peanut: ['peanut', 'peanuts', 'groundnut', 'groundnuts'],
  milk: ['milk', 'dairy', 'cheese', 'butter', 'yogurt', 'cream', 'whey', 'casein'],
  gluten: ['gluten', 'wheat', 'flour', 'bread', 'pasta', 'barley', 'rye', 'malt', 'noodle'],
  eggs: ['egg', 'eggs', 'mayonnaise', 'mayo', 'aioli'],
  seafood: ['seafood', 'fish', 'shrimp', 'prawn', 'crab', 'lobster', 'clam', 'mussel', 'oyster', 'shellfish', 'salmon', 'tuna'],
  soy: ['soy', 'soybean', 'soybeans', 'tofu', 'tempeh', 'edamame', 'miso', 'soy sauce'],
  nuts: ['nut', 'nuts', 'almond', 'almonds', 'walnut', 'walnuts', 'cashew', 'cashews', 'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'pecan', 'pecans'],
};

const conditionRules = {
  diabetes: {
    labels: ['diabetes', 'diabetic', 'blood sugar'],
    warningTerms: ['dessert', 'soda', 'sweet', 'sugary', 'cake', 'cookie', 'cookies', 'chocolate', 'donut', 'donuts', 'ice cream', 'white rice', 'bread', 'pasta', 'noodle', 'juice'],
    blockIfCarbsAtLeast: 60,
    warningIfCarbsAtLeast: 35,
    blockedReason: 'High carbohydrate load is not a good fit for diabetes.',
    warningReason: 'This meal is relatively high in carbohydrates for diabetes.',
  },
  'high blood pressure': {
    labels: ['high blood pressure', 'hypertension', 'blood pressure'],
    warningTerms: ['salt', 'salty', 'soy sauce', 'pickles', 'pickle', 'bacon', 'sausage', 'ham', 'salami', 'processed', 'instant noodles', 'chips', 'fries'],
    blockIfCarbsAtLeast: null,
    warningIfCarbsAtLeast: null,
    blockedReason: 'This meal looks high in sodium-heavy or processed ingredients.',
    warningReason: 'This meal may be too salty for high blood pressure.',
  },
  'heart disease': {
    labels: ['heart disease', 'cardiac', 'cardiovascular'],
    warningTerms: ['fried', 'fast food', 'bacon', 'sausage', 'ham', 'butter', 'cream', 'cheese', 'burger'],
    blockIfCarbsAtLeast: null,
    warningIfCarbsAtLeast: null,
    blockedReason: 'This meal is rich in saturated fat or processed ingredients.',
    warningReason: 'This meal may be heavy for heart disease management.',
  },
  thyroid: {
    labels: ['thyroid', 'hypothyroid', 'hyperthyroid', 'hashimoto'],
    warningTerms: ['soy', 'tofu', 'tempeh', 'edamame', 'seaweed', 'kelp'],
    blockIfCarbsAtLeast: null,
    warningIfCarbsAtLeast: null,
    blockedReason: 'This meal contains ingredients that may conflict with thyroid-sensitive diets.',
    warningReason: 'This meal may not be ideal for thyroid-sensitive diets.',
  },
  pcos: {
    labels: ['pcos', 'polycystic ovary syndrome'],
    warningTerms: ['dessert', 'soda', 'sweet', 'sugary', 'cake', 'cookie', 'cookies', 'ice cream', 'juice', 'white rice', 'bread', 'pasta', 'noodle'],
    blockIfCarbsAtLeast: 65,
    warningIfCarbsAtLeast: 40,
    blockedReason: 'This meal is too carb-heavy for a PCOS-focused meal plan.',
    warningReason: 'This meal may spike blood sugar and is not ideal for PCOS.',
  },
};

const containsAny = (haystack, needles) => {
  for (const needle of needles) {
    const normalizedNeedle = normalizeText(needle);
    if (!normalizedNeedle) continue;

    for (const token of haystack) {
      if (token.includes(normalizedNeedle) || normalizedNeedle.includes(token)) {
        return true;
      }
    }
  }

  return false;
};

const buildHaystack = (mealName, ingredients = [], possibleAllergens = []) => {
  const values = [mealName, ...ingredients, ...possibleAllergens];
  return new Set(values.map(normalizeText).filter(Boolean));
};

const assessMealRestrictions = (
  {
    mealName,
    ingredients = [],
    possibleAllergens = [],
    calories = 0,
    protein = 0,
    carbs = 0,
    fat = 0,
  },
  profile = {}
) => {
  const allergies = normalizeList(profile.allergies);
  const medicalConditions = normalizeList(profile.medical_conditions);
  const haystack = buildHaystack(mealName, ingredients, possibleAllergens);
  const issues = [];

  for (const allergy of allergies) {
    if (!allergy || allergy === 'none') continue;
    const aliases = allergyAliases[allergy] || [allergy];
    if (containsAny(haystack, aliases)) {
      issues.push({
        category: 'allergy',
        label: allergy,
        reason: `This meal appears to contain ${allergy} or a close match.`,
        severity: 'blocked',
      });
    }
  }

  for (const condition of medicalConditions) {
    if (!condition || condition === 'none') continue;

    const conditionEntry = Object.values(conditionRules).find((entry) => entry.labels.includes(condition));
    if (!conditionEntry) continue;

    const matchesByName = containsAny(haystack, conditionEntry.warningTerms);
    const carbsTooHigh = conditionEntry.blockIfCarbsAtLeast != null && Number(carbs) >= conditionEntry.blockIfCarbsAtLeast;
    const carbsWarning = conditionEntry.warningIfCarbsAtLeast != null && Number(carbs) >= conditionEntry.warningIfCarbsAtLeast;

    // Conditions should only surface warnings to the user (they may add anyway).
    // Convert any name-based or carb-threshold matches into 'warning' severity
    // rather than blocking the addition. Allergies remain blocked above.
    if (matchesByName || carbsTooHigh) {
      issues.push({
        category: 'condition',
        label: condition,
        reason: conditionEntry.warningReason || conditionEntry.blockedReason,
        severity: 'warning',
      });
      continue;
    }

    if (carbsWarning) {
      issues.push({
        category: 'condition',
        label: condition,
        reason: conditionEntry.warningReason,
        severity: 'warning',
      });
    }
  }

  return {
    calories,
    protein,
    carbs,
    fat,
    issues,
    hasIssues: issues.length > 0,
    hasBlockedIssues: issues.some((issue) => issue.severity === 'blocked'),
  };
};

module.exports = {
  assessMealRestrictions,
  normalizeText,
};