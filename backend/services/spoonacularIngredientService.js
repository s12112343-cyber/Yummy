const axios = require('axios');

const SPOONACULAR_BASE_URL = 'https://api.spoonacular.com/food/ingredients';

function _cleanQuery(value) {
  return (value ?? '').toString().trim();
}

function _buildImageUrl(image) {
  const cleanedImage = _cleanQuery(image);

  if (!cleanedImage) {
    return null;
  }

  if (cleanedImage.startsWith('http://') || cleanedImage.startsWith('https://')) {
    return cleanedImage;
  }

  return `https://spoonacular.com/cdn/ingredients_100x100/${cleanedImage}`;
}

async function searchSpoonacularIngredients(query, limit = 10) {
  const apiKey = process.env.SPOONACULAR_API_KEY;
  const normalizedQuery = _cleanQuery(query);

  if (!apiKey || !normalizedQuery) {
    return [];
  }

  try {
    const response = await axios.get(`${SPOONACULAR_BASE_URL}/autocomplete`, {
      params: {
        query: normalizedQuery,
        number: limit,
        metaInformation: true,
        apiKey,
      },
      timeout: 10000,
    });

    const results = Array.isArray(response.data) ? response.data : [];

    return results
      .map((item) => {
        const name = _cleanQuery(item?.name);

        if (!name) {
          return null;
        }

        return {
          name,
          imageUrl: _buildImageUrl(item?.image),
          source: 'spoonacular',
        };
      })
      .filter(Boolean);
  } catch (error) {
    console.warn(
      'Spoonacular ingredient search failed:',
      error.response?.data?.message || error.message
    );
    return [];
  }
}

module.exports = {
  searchSpoonacularIngredients,
};