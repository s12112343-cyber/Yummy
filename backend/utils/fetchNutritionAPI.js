const axios = require('axios');

const APP_ID = process.env.EDAMAM_ID;
const APP_KEY = process.env.EDAMAM_KEY;

async function fetchNutritionFromAPI(name) {
  try {
    const response = await axios.get(
      `https://api.edamam.com/api/nutrition-data`,
      {
        params: {
          app_id: APP_ID,
          app_key: APP_KEY,
          ingr: `100g ${name}`,
        },
      }
    );

    const data = response.data;

    return {
      calories: data.calories || 0,
      fat: data.totalNutrients?.FAT?.quantity || 0,
      protein: data.totalNutrients?.PROCNT?.quantity || 0,
      potassium: data.totalNutrients?.K?.quantity || 0,
    };
  } catch (e) {
    console.log("❌ API FAIL:", name);
    return null;
  }
}

module.exports = fetchNutritionFromAPI;