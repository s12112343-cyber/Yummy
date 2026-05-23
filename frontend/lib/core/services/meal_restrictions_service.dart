enum MealRestrictionSeverity { warning, blocked }

class MealRestrictionIssue {
  final String category;
  final String label;
  final String reason;
  final MealRestrictionSeverity severity;
  final List<String> matchedTerms;

  const MealRestrictionIssue({
    required this.category,
    required this.label,
    required this.reason,
    required this.severity,
    this.matchedTerms = const [],
  });
}

class MealRestrictionProfile {
  final List<String> allergies;
  final List<String> medicalConditions;

  const MealRestrictionProfile({
    required this.allergies,
    required this.medicalConditions,
  });

  factory MealRestrictionProfile.fromUser(Map<String, dynamic>? user) {
    final profile = user == null
        ? const <String, dynamic>{}
        : (user['profile'] as Map<String, dynamic>? ??
              const <String, dynamic>{});

    return MealRestrictionProfile(
      allergies: _stringList(profile['allergies']),
      medicalConditions: _stringList(profile['medical_conditions']),
    );
  }

  bool get isEmpty => allergies.isEmpty && medicalConditions.isEmpty;
}

class MealRestrictionAssessment {
  final List<MealRestrictionIssue> issues;

  const MealRestrictionAssessment(this.issues);

  bool get hasIssues => issues.isNotEmpty;
  bool get hasBlockedIssues =>
      issues.any((issue) => issue.severity == MealRestrictionSeverity.blocked);
}

class MealRestrictionsService {
  static const Map<String, Set<String>> _allergyAliases = {
    'peanut': {'peanut', 'peanuts', 'groundnut', 'groundnuts'},
    'milk': {
      'milk',
      'dairy',
      'cheese',
      'butter',
      'yogurt',
      'cream',
      'whey',
      'casein',
    },
    'gluten': {
      'gluten',
      'wheat',
      'flour',
      'bread',
      'pasta',
      'barley',
      'rye',
      'malt',
      'noodle',
    },
    'eggs': {'egg', 'eggs', 'mayonnaise', 'mayo', 'aioli'},
    'seafood': {
      'seafood',
      'fish',
      'shrimp',
      'prawn',
      'crab',
      'lobster',
      'clam',
      'mussel',
      'oyster',
      'shellfish',
      'salmon',
      'tuna',
    },
    'soy': {
      'soy',
      'soybean',
      'soybeans',
      'tofu',
      'tempeh',
      'edamame',
      'miso',
      'soy sauce',
    },
    'nuts': {
      'nut',
      'nuts',
      'almond',
      'almonds',
      'walnut',
      'walnuts',
      'cashew',
      'cashews',
      'pistachio',
      'pistachios',
      'hazelnut',
      'hazelnuts',
      'pecan',
      'pecans',
    },
  };

  static const Map<String, _ConditionRule> _conditionRules = {
    'diabetes': _ConditionRule(
      labels: {'diabetes', 'diabetic', 'blood sugar'},
      warningTerms: {
        'dessert',
        'soda',
        'sweet',
        'sugary',
        'cake',
        'cookie',
        'cookies',
        'chocolate',
        'donut',
        'donuts',
        'ice cream',
        'white rice',
        'bread',
        'pasta',
        'noodle',
        'juice',
      },
      blockIfCarbsAtLeast: 60,
      warningIfCarbsAtLeast: 35,
      blockedReason: 'High carbohydrate load is not a good fit for diabetes.',
      warningReason:
          'This meal is relatively high in carbohydrates for diabetes.',
    ),
    'high blood pressure': _ConditionRule(
      labels: {'high blood pressure', 'hypertension', 'blood pressure'},
      warningTerms: {
        'salt',
        'salty',
        'soy sauce',
        'pickles',
        'pickle',
        'bacon',
        'sausage',
        'ham',
        'salami',
        'processed',
        'instant noodles',
        'chips',
        'fries',
      },
      blockIfCarbsAtLeast: null,
      warningIfCarbsAtLeast: null,
      blockedReason:
          'This meal looks high in sodium-heavy or processed ingredients.',
      warningReason: 'This meal may be too salty for high blood pressure.',
    ),
    'heart disease': _ConditionRule(
      labels: {'heart disease', 'cardiac', 'cardiovascular'},
      warningTerms: {
        'fried',
        'fast food',
        'bacon',
        'sausage',
        'ham',
        'butter',
        'cream',
        'cheese',
        'burger',
      },
      blockIfCarbsAtLeast: null,
      warningIfCarbsAtLeast: null,
      blockedReason:
          'This meal is rich in saturated fat or processed ingredients.',
      warningReason: 'This meal may be heavy for heart disease management.',
    ),
    'thyroid': _ConditionRule(
      labels: {'thyroid', 'hypothyroid', 'hyperthyroid', 'hashimoto'},
      warningTerms: {'soy', 'tofu', 'tempeh', 'edamame', 'seaweed', 'kelp'},
      blockIfCarbsAtLeast: null,
      warningIfCarbsAtLeast: null,
      blockedReason:
          'This meal contains ingredients that may conflict with thyroid-sensitive diets.',
      warningReason: 'This meal may not be ideal for thyroid-sensitive diets.',
    ),
    'pcos': _ConditionRule(
      labels: {'pcos', 'polycystic ovary syndrome'},
      warningTerms: {
        'dessert',
        'soda',
        'sweet',
        'sugary',
        'cake',
        'cookie',
        'cookies',
        'ice cream',
        'juice',
        'white rice',
        'bread',
        'pasta',
        'noodle',
      },
      blockIfCarbsAtLeast: 65,
      warningIfCarbsAtLeast: 40,
      blockedReason:
          'This meal is too carb-heavy for a PCOS-focused meal plan.',
      warningReason:
          'This meal may spike blood sugar and is not ideal for PCOS.',
    ),
  };

  static MealRestrictionAssessment assess({
    required MealRestrictionProfile profile,
    required String mealName,
    List<String> ingredients = const [],
    List<String> possibleAllergens = const [],
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) {
    final haystack = _normalizeTokens([
      mealName,
      ...ingredients,
      ...possibleAllergens,
    ]);

    final issues = <MealRestrictionIssue>[];

    for (final allergy in profile.allergies) {
      final normalizedAllergy = _normalize(allergy);
      if (normalizedAllergy.isEmpty || normalizedAllergy == 'none') continue;

      final aliases = _allergyAliases[normalizedAllergy] ?? {normalizedAllergy};
      final matchedTerms = _findMatches(haystack, aliases);
      if (matchedTerms.isNotEmpty) {
        issues.add(
          MealRestrictionIssue(
            category: 'allergy',
            label: allergy,
            reason: 'This meal appears to contain $allergy or a close match.',
            severity: MealRestrictionSeverity.blocked,
            matchedTerms: matchedTerms,
          ),
        );
      }
    }

    for (final condition in profile.medicalConditions) {
      final normalizedCondition = _normalize(condition);
      if (normalizedCondition.isEmpty || normalizedCondition == 'none')
        continue;

      _ConditionRule? conditionEntry;
      for (final entry in _conditionRules.values) {
        if (entry.labels.contains(normalizedCondition)) {
          conditionEntry = entry;
          break;
        }
      }

      if (conditionEntry == null) continue;

      final matchesByName = _containsAny(haystack, conditionEntry.warningTerms);
      final carbsTooHigh =
          conditionEntry.blockIfCarbsAtLeast != null &&
          carbs >= conditionEntry.blockIfCarbsAtLeast!;
      final carbsWarning =
          conditionEntry.warningIfCarbsAtLeast != null &&
          carbs >= conditionEntry.warningIfCarbsAtLeast!;

      if (matchesByName || carbsTooHigh) {
        issues.add(
          MealRestrictionIssue(
            category: 'condition',
            label: condition,
            reason: conditionEntry.blockedReason,
            severity: MealRestrictionSeverity.blocked,
          ),
        );
        continue;
      }

      if (carbsWarning) {
        issues.add(
          MealRestrictionIssue(
            category: 'condition',
            label: condition,
            reason: conditionEntry.warningReason,
            severity: MealRestrictionSeverity.warning,
          ),
        );
      }
    }

    return MealRestrictionAssessment(issues);
  }

  static String summarizeIssues(MealRestrictionAssessment assessment) {
    if (!assessment.hasIssues) return '';

    final buffer = StringBuffer();
    for (final issue in assessment.issues) {
      buffer.writeln('- ${issue.label}: ${issue.reason}');
    }
    return buffer.toString().trim();
  }

  static bool _containsAny(Set<String> haystack, Set<String> needles) {
    for (final needle in needles) {
      final normalizedNeedle = _normalize(needle);
      if (normalizedNeedle.isEmpty) continue;

      for (final token in haystack) {
        if (token.contains(normalizedNeedle) ||
            normalizedNeedle.contains(token)) {
          return true;
        }
      }
    }

    return false;
  }

  static List<String> _findMatches(Set<String> haystack, Set<String> needles) {
    final matches = <String>[];

    for (final needle in needles) {
      final normalizedNeedle = _normalize(needle);
      if (normalizedNeedle.isEmpty) continue;

      for (final token in haystack) {
        if (token.contains(normalizedNeedle) ||
            normalizedNeedle.contains(token)) {
          if (!matches.contains(token)) {
            matches.add(token);
          }
        }
      }
    }

    return matches;
  }

  static Set<String> _normalizeTokens(Iterable<String> values) {
    final tokens = <String>{};
    for (final value in values) {
      final normalized = _normalize(value);
      if (normalized.isNotEmpty) {
        tokens.add(normalized);
      }
    }
    return tokens;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ConditionRule {
  final Set<String> labels;
  final Set<String> warningTerms;
  final double? blockIfCarbsAtLeast;
  final double? warningIfCarbsAtLeast;
  final String blockedReason;
  final String warningReason;

  const _ConditionRule({
    required this.labels,
    required this.warningTerms,
    required this.blockIfCarbsAtLeast,
    required this.warningIfCarbsAtLeast,
    required this.blockedReason,
    required this.warningReason,
  });
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}
