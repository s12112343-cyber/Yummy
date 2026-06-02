/// Shared calorie and macro targets (same logic as Home screen).
class NutritionCalculator {
  NutritionCalculator._();

  static int calculateAge(String dateOfBirth) {
    final birthDate = DateTime.tryParse(dateOfBirth);
    if (birthDate == null) return 0;
    final today = DateTime.now();

    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static int calculateCalories(Map<String, dynamic> profile) {
    final weight = (profile['weight']?['value'] ?? 0).toDouble();
    final height = (profile['height']?['value'] ?? 0).toDouble();
    final gender = profile['gender']?.toString();
    final activity = profile['activity_level']?.toString();
    final goal = profile['goal']?.toString();
    final dob = profile['date_of_birth']?.toString() ?? '';

    if (dob.isEmpty) return 0;
    final age = calculateAge(dob);
    if (age <= 0 || height <= 0 || weight <= 0) return 0;

    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    double activityFactor = 1.2;
    switch (activity) {
      case 'lightly_active':
        activityFactor = 1.375;
        break;
      case 'moderately_active':
        activityFactor = 1.55;
        break;
      case 'very_active':
        activityFactor = 1.725;
        break;
      case 'sedentary':
      default:
        activityFactor = 1.2;
    }

    double calories = bmr * activityFactor;
    if (goal == 'lose_weight') {
      calories -= 350;
    } else if (goal == 'gain_weight') {
      calories += 300;
    }

    return calories.round();
  }

  static Map<String, int> calculateMacros(
    Map<String, dynamic> profile,
    int calories,
  ) {
    if (calories <= 0) {
      return {'protein': 0, 'fat': 0, 'carbs': 0};
    }

    final weight = (profile['weight']?['value'] ?? 0).toDouble();
    final goal = profile['goal']?.toString();

    if (weight <= 0) {
      return {'protein': 0, 'fat': 0, 'carbs': 0};
    }

    double proteinPerKg;
    double fatPercentage;

    switch (goal) {
      case 'lose_weight':
        proteinPerKg = 1.6;
        fatPercentage = 0.25;
        break;
      case 'gain_weight':
        proteinPerKg = 1.8;
        fatPercentage = 0.25;
        break;
      case 'stay_healthy':
      default:
        proteinPerKg = 1.2;
        fatPercentage = 0.30;
        break;
    }

    final proteinGrams = weight * proteinPerKg;
    final proteinCalories = proteinGrams * 4;
    final fatGrams = (calories * fatPercentage) / 9;
    final fatCalories = fatGrams * 9;
    final carbsGrams = (calories - proteinCalories - fatCalories) / 4;

    return {
      'protein': proteinGrams.round(),
      'fat': fatGrams.round(),
      'carbs': carbsGrams.round() < 0 ? 0 : carbsGrams.round(),
    };
  }

  static Map<String, double> mealDistributionForGoal(String? goal) {
    switch (goal) {
      case 'lose_weight':
        return const {
          'breakfast': 0.30,
          'lunch': 0.40,
          'dinner': 0.20,
          'snack': 0.10,
        };
      case 'gain_weight':
        return const {
          'breakfast': 0.25,
          'lunch': 0.35,
          'dinner': 0.25,
          'snack': 0.15,
        };
      case 'stay_healthy':
      default:
        return const {
          'breakfast': 0.30,
          'lunch': 0.35,
          'dinner': 0.25,
          'snack': 0.10,
        };
    }
  }

  static int distributeMacro(int dailyMacro, int mealCalories, int dailyCalories) {
    if (dailyCalories <= 0 || dailyMacro <= 0 || mealCalories <= 0) {
      return 0;
    }
    return (dailyMacro * mealCalories / dailyCalories).round();
  }
}
