import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/app_background.dart';
import '../../../shared/back_button_widget.dart';
import '../../../core/services/auth_service.dart';
import '../home/home_screen.dart';

class SignUpFlowScreen extends StatefulWidget {
  final String userId;

  const SignUpFlowScreen({super.key, required this.userId});

  @override
  State<SignUpFlowScreen> createState() => _SignUpFlowScreenState();
}

class _SignUpFlowScreenState extends State<SignUpFlowScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameCtrl = TextEditingController();

  static const int _totalSteps = 9;

  final AuthService _authService = AuthService();

  int _currentStep = 0;
  String? _selectedGoal;
  String? _gender;
  String? _selectedActivity;
  List<String> _selectedAllergies = [];
  List<String> _selectedConditions = [];

  DateTime? _selectedBirthDate;
  int? _selectedAge;
  double _selectedWeight = 60;
  final PageController _heightController = PageController(
    viewportFraction: 0.34,
    initialPage: 35,
  );

  final List<int> _heightValues = List.generate(71, (index) => 140 + index);
  int _selectedHeight = 175;

  bool _saving = false;

  double get _progressValue => (_currentStep + 1) / _totalSteps;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    await _pageController.animateToPage(
      _currentStep - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );

    setState(() => _currentStep--);
  }

  Future<void> _skip() async {
    if (_currentStep < _totalSteps - 1) {
      FocusScope.of(context).unfocus();

      await _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

      setState(() => _currentStep++);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 23, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.mediumBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.darkBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = _calculateAge(picked);

      setState(() {
        _selectedBirthDate = picked;
        _selectedAge = age;
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  String _mapGoal(String? value) {
    switch (value) {
      case "Lose weight":
        return "lose_weight";
      case "Gain weight":
        return "gain_weight";
      case "Stay healthy":
        return "stay_healthy";
      default:
        return "";
    }
  }

  String _mapGender(String? value) {
    switch (value) {
      case "Male":
        return "male";
      case "Female":
        return "female";
      default:
        return "";
    }
  }

  String _mapActivity(String? value) {
    switch (value) {
      case "Sedentary":
        return "sedentary";
      case "Lightly Active":
        return "lightly_active";
      case "Moderately Active":
        return "moderately_active";
      case "Very Active":
        return "very_active";
      default:
        return "";
    }
  }

  List<String> _cleanList(List<String> values) {
    if (values.contains("None")) return [];
    return values.map((e) => e.toLowerCase().replaceAll(" ", "_")).toList();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Lottie.asset(
                    'assets/lottie/true.json',
                    fit: BoxFit.contain,
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.successPrimary,
                        size: 64,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Account Created",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your account has been created successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishProfile() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final updateNameResult = await _authService.updateUserName(name: name);

      if (updateNameResult['user'] == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updateNameResult['message'] ?? 'Failed to save name'),
          ),
        );
        return;
      }

      final profileResult = await _authService.saveProfile(
        name: _nameCtrl.text.trim(),
        goal: _mapGoal(_selectedGoal),
        gender: _mapGender(_gender),
        dateOfBirth: _selectedBirthDate?.toIso8601String() ?? "",
        heightValue: _selectedHeight,
        heightUnit: "cm",
        weightValue: _selectedWeight,
        weightUnit: "kg",
        activityLevel: _mapActivity(_selectedActivity),
        allergies: _cleanList(_selectedAllergies),
        medicalConditions: _cleanList(_selectedConditions),
      );

      if (!mounted) return;

      setState(() => _saving = false);

      if (profileResult['profile'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileResult['message'] ?? 'Failed to save profile'),
          ),
        );
        return;
      }

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    }
  }

  Future<void> _next() async {
    if (_currentStep == 0 && _nameCtrl.text.trim().isEmpty) return;
    if (_currentStep == 1 && _selectedGoal == null) return;
    if (_currentStep == 2 && _gender == null) return;
    if (_currentStep == 3 && _selectedBirthDate == null) return;
    if (_currentStep == 4 && _selectedHeight <= 0) return;
    if (_currentStep == 5 && _selectedWeight <= 0) return;
    if (_currentStep == 6 && _selectedActivity == null) return;

    if (_currentStep < _totalSteps - 1) {
      FocusScope.of(context).unfocus();

      await _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

      setState(() => _currentStep++);
    } else {
      await _finishProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    AppBackButton(onTap: _back),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _skip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.dark.withOpacity(0.08),
                          ),
                        ),
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepScaffold(child: _NameStep(nameCtrl: _nameCtrl)),
                    _StepScaffold(
                      child: _GoalStep(
                        selectedGoal: _selectedGoal,
                        onSelected: (value) {
                          setState(() => _selectedGoal = value);
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _GenderStep(
                        selectedGender: _gender,
                        onSelected: (value) {
                          setState(() => _gender = value);
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _BirthStep(
                        selectedAge: _selectedAge,
                        selectedBirthDate: _selectedBirthDate,
                        onTapPickDate: _pickBirthDate,
                      ),
                    ),
                    _StepScaffold(
                      child: _HeightStep(
                        selectedHeight: _selectedHeight,
                        heightValues: _heightValues,
                        controller: _heightController,
                        onHeightChanged: (value) {
                          setState(() => _selectedHeight = value);
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _WeightStep(
                        selectedWeight: _selectedWeight,
                        onWeightChanged: (value) {
                          setState(() => _selectedWeight = value);
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _ActivityStep(
                        selectedActivity: _selectedActivity,
                        onSelected: (value) {
                          setState(() => _selectedActivity = value);
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _AllergiesStep(
                        selectedAllergies: _selectedAllergies,
                        onToggle: (value) {
                          setState(() {
                            if (value == "None") {
                              if (_selectedAllergies.contains("None")) {
                                _selectedAllergies.remove("None");
                              } else {
                                _selectedAllergies = ["None"];
                              }
                            } else {
                              _selectedAllergies.remove("None");

                              if (_selectedAllergies.contains(value)) {
                                _selectedAllergies.remove(value);
                              } else {
                                _selectedAllergies.add(value);
                              }
                            }
                          });
                        },
                      ),
                    ),
                    _StepScaffold(
                      child: _ConditionsStep(
                        selectedConditions: _selectedConditions,
                        onToggle: (value) {
                          setState(() {
                            if (value == "None") {
                              if (_selectedConditions.contains("None")) {
                                _selectedConditions.remove("None");
                              } else {
                                _selectedConditions = ["None"];
                              }
                            } else {
                              _selectedConditions.remove("None");

                              if (_selectedConditions.contains(value)) {
                                _selectedConditions.remove(value);
                              } else {
                                _selectedConditions.add(value);
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: GestureDetector(
                  onTap: _saving ? null : _next,
                  child: SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: _progressValue),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return SizedBox(
                              width: 82,
                              height: 82,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 3.4,
                                backgroundColor: AppColors.mediumBlue
                                    .withOpacity(0.18),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.mediumBlue,
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.deepBlue,
                          ),
                          child: _saving
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final Widget child;

  const _StepScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: child,
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String stepText;
  final String titleDark;
  final String titleBlue;
  final String subtitle;

  const _StepHeader({
    required this.stepText,
    required this.titleDark,
    required this.titleBlue,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 70),
        Text(
          stepText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.blueGray,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: titleDark,
                style: const TextStyle(color: AppColors.darkBlue),
              ),
              TextSpan(
                text: titleBlue,
                style: const TextStyle(color: AppColors.mediumBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.dark.withOpacity(0.58),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController nameCtrl;

  const _NameStep({required this.nameCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          const _StepHeader(
            stepText: "1 / 9",
            titleDark: "What is your ",
            titleBlue: "name?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 110),
          Container(
            width: double.infinity,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.navy, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: TextFormField(
              controller: nameCtrl,
              textAlign: TextAlign.center,
              scrollPadding: const EdgeInsets.only(bottom: 140),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkBlue,
              ),
              decoration: const InputDecoration(
                hintText: "Enter your full name",
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: AppColors.labelGray,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  final String? selectedGoal;
  final ValueChanged<String> onSelected;

  const _GoalStep({required this.selectedGoal, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _StepHeader(
            stepText: "2 / 9",
            titleDark: "What is your ",
            titleBlue: "goal?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 34),
          _GoalCard(
            title: "Lose weight",
            image: "assets/icons/lose_weight.png",
            selected: selectedGoal == "Lose weight",
            onTap: () => onSelected("Lose weight"),
          ),
          const SizedBox(height: 16),
          _GoalCard(
            title: "Gain weight",
            image: "assets/icons/gain_weight.png",
            selected: selectedGoal == "Gain weight",
            onTap: () => onSelected("Gain weight"),
          ),
          const SizedBox(height: 16),
          _GoalCard(
            title: "Stay healthy",
            image: "assets/icons/stay_healthy.png",
            selected: selectedGoal == "Stay healthy",
            onTap: () => onSelected("Stay healthy"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.title,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightBlue.withOpacity(0.35)
              : AppColors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.mediumBlue
                : AppColors.dark.withOpacity(0.05),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.navy
                      : AppColors.darkBlue.withOpacity(0.85),
                ),
              ),
            ),
            Image.asset(image, height: 60, width: 70, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}

class _GenderStep extends StatelessWidget {
  final String? selectedGender;
  final ValueChanged<String> onSelected;

  const _GenderStep({required this.selectedGender, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepHeader(
          stepText: "3 / 9",
          titleDark: "What is your ",
          titleBlue: "gender?",
          subtitle:
              "We will use this data to give you\na better diet plan for your life.",
        ),
        const SizedBox(height: 70),
        Row(
          children: [
            Expanded(
              child: _GenderCard(
                label: "Male",
                image: "assets/icons/male.png",
                selected: selectedGender == "Male",
                onTap: () => onSelected("Male"),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _GenderCard(
                label: "Female",
                image: "assets/icons/female.png",
                selected: selectedGender == "Female",
                onTap: () => onSelected("Female"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String image;

  const _GenderCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightBlue.withOpacity(0.35)
              : AppColors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.navy.withOpacity(0.30)
                : AppColors.dark.withOpacity(0.06),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(image, height: 80),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: selected
                    ? AppColors.navy
                    : AppColors.dark.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthStep extends StatelessWidget {
  final int? selectedAge;
  final DateTime? selectedBirthDate;
  final VoidCallback onTapPickDate;

  const _BirthStep({
    required this.selectedAge,
    required this.selectedBirthDate,
    required this.onTapPickDate,
  });

  String _formatDate(DateTime date) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${months[date.month - 1]}  /  ${date.day}  /  ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepHeader(
          stepText: "4 / 9",
          titleDark: "Your ",
          titleBlue: "date of birth",
          subtitle:
              "We will use this data to give you\na better diet plan for your life.",
        ),
        const SizedBox(height: 58),
        Container(
          width: double.infinity,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.babyBlue,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            selectedAge?.toString() ?? "--",
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTapPickDate,
          child: Container(
            width: double.infinity,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.dark.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedBirthDate != null
                        ? _formatDate(selectedBirthDate!)
                        : "Select your birth date",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selectedBirthDate != null
                          ? AppColors.darkBlue
                          : AppColors.blueGray,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.mediumBlue,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeightStep extends StatelessWidget {
  final int selectedHeight;
  final List<int> heightValues;
  final PageController controller;
  final ValueChanged<int> onHeightChanged;

  const _HeightStep({
    required this.selectedHeight,
    required this.heightValues,
    required this.controller,
    required this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepHeader(
          stepText: "5 / 9",
          titleDark: "How ",
          titleBlue: "tall are you?",
          subtitle:
              "We will use this data to give you\na better diet plan for your life.",
        ),
        const SizedBox(height: 26),
        const _UnitPill(label: "cm"),
        const SizedBox(height: 26),
        const Icon(
          Icons.arrow_drop_down_rounded,
          size: 30,
          color: AppColors.mediumBlue,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: _HeightCarousel(
            controller: controller,
            values: heightValues,
            selectedValue: selectedHeight,
            onChanged: onHeightChanged,
          ),
        ),
        const SizedBox(height: 10),
        _HeightRuler(selectedHeight: selectedHeight),
      ],
    );
  }
}

class _HeightCarousel extends StatelessWidget {
  final PageController controller;
  final List<int> values;
  final int selectedValue;
  final ValueChanged<int> onChanged;

  const _HeightCarousel({
    required this.controller,
    required this.values,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: values.length,
      onPageChanged: (index) {
        onChanged(values[index]);
      },
      itemBuilder: (context, index) {
        final value = values[index];
        final isSelected = value == selectedValue;

        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: isSelected ? 112 : 82,
            height: isSelected ? 146 : 120,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.babyBlue
                  : AppColors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(isSelected ? 28 : 24),
            ),
            alignment: Alignment.center,
            child: Text(
              "$value",
              style: TextStyle(
                fontSize: isSelected ? 38 : 22,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? AppColors.darkBlue
                    : AppColors.darkBlue.withOpacity(0.55),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeightRuler extends StatelessWidget {
  final int selectedHeight;

  const _HeightRuler({required this.selectedHeight});

  @override
  Widget build(BuildContext context) {
    final int lowerTen = (selectedHeight ~/ 10) * 10;
    final int upperTen = lowerTen + 10;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(41, (index) {
              final int value = selectedHeight - 20 + index;

              final bool isCenter = value == selectedHeight;
              final bool isMajor = value == lowerTen || value == upperTen;

              return Container(
                width: isCenter ? 2.2 : 1.2,
                height: isCenter
                    ? 28
                    : isMajor
                    ? 22
                    : 12,
                decoration: BoxDecoration(
                  color: isCenter
                      ? AppColors.mediumBlue
                      : AppColors.darkBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$lowerTen",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue,
                ),
              ),
              Text(
                "$selectedHeight",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBlue,
                ),
              ),
              Text(
                "$upperTen",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightStep extends StatelessWidget {
  final double selectedWeight;
  final ValueChanged<double> onWeightChanged;

  const _WeightStep({
    required this.selectedWeight,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _StepHeader(
            stepText: "6 / 9",
            titleDark: "What is your ",
            titleBlue: "weight?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 18),
          const _UnitPill(label: "kg"),
          const SizedBox(height: 16),
          const Icon(
            Icons.arrow_drop_down_rounded,
            size: 30,
            color: AppColors.mediumBlue,
          ),
          const SizedBox(height: 8),
          _WeightValueCard(value: selectedWeight.round()),
          const SizedBox(height: 8),
          _WeightSemiCirclePicker(
            value: selectedWeight,
            onChanged: onWeightChanged,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _UnitPill extends StatelessWidget {
  final String label;

  const _UnitPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _WeightValueCard extends StatelessWidget {
  final int value;

  const _WeightValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.babyBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.center,
      child: Text(
        "$value",
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: AppColors.darkBlue,
        ),
      ),
    );
  }
}

class _WeightSemiCirclePicker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _WeightSemiCirclePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final int lowerTen = (value ~/ 10) * 10;
    final int upperTen = lowerTen + 10;

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final next = (value - details.delta.dx * 0.25).clamp(30.0, 150.0);
            onChanged(next);
          },
          child: SizedBox(
            width: 340,
            height: 160,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  child: CustomPaint(
                    size: const Size(340, 140),
                    painter: _WeightSemiCirclePainter(value: value),
                  ),
                ),
                Positioned(
                  top: 18,
                  child: Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.mediumBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$lowerTen",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue.withOpacity(0.70),
                ),
              ),
              Text(
                "${value.round()}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkBlue,
                ),
              ),
              Text(
                "$upperTen",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue.withOpacity(0.70),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightSemiCirclePainter extends CustomPainter {
  final double value;

  _WeightSemiCirclePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 46);
    final radius = size.width * 0.52;

    final tickPaint = Paint()
      ..color = AppColors.darkBlue.withOpacity(0.14)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = AppColors.darkBlue.withOpacity(0.28)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final highlightPaint = Paint()
      ..color = AppColors.mediumBlue.withOpacity(0.22)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const double visibleStart = math.pi;
    const double visibleSweep = math.pi;

    final double indicatorAngle = math.pi + (visibleSweep / 2);
    final double rotationOffset = ((value - 30) / 120) * visibleSweep;
    for (int i = -30; i <= 70; i++) {
      final double baseT = i / 40;
      final double angle =
          visibleStart + (baseT * visibleSweep) - rotationOffset;
      if (angle < visibleStart - 0.15 ||
          angle > visibleStart + visibleSweep + 0.15) {
        continue;
      }
      final bool isMajor = i % 5 == 0;
      final bool isNearIndicator = (angle - indicatorAngle).abs() < 0.08;

      final double outerR = radius;
      final double innerR = radius - (isMajor ? 22 : 11);

      final p1 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );

      final p2 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );

      canvas.drawLine(
        p1,
        p2,
        isNearIndicator
            ? highlightPaint
            : (isMajor ? majorTickPaint : tickPaint),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightSemiCirclePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _ActivityStep extends StatelessWidget {
  final String? selectedActivity;
  final ValueChanged<String> onSelected;

  const _ActivityStep({
    required this.selectedActivity,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _StepHeader(
            stepText: "7 / 9",
            titleDark: "How ",
            titleBlue: "active are you?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 34),
          _ActivityCard(
            title: "Sedentary",
            subtitle: "Little or no exercise",
            icon: "assets/icons/sedentary.png",
            selected: selectedActivity == "Sedentary",
            onTap: () => onSelected("Sedentary"),
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            title: "Lightly Active",
            subtitle: "1-3 workouts per week",
            icon: "assets/icons/light_active.png",
            selected: selectedActivity == "Lightly Active",
            onTap: () => onSelected("Lightly Active"),
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            title: "Moderately Active",
            subtitle: "3-5 workouts per week",
            icon: "assets/icons/moderate_active.png",
            selected: selectedActivity == "Moderately Active",
            onTap: () => onSelected("Moderately Active"),
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            title: "Very Active",
            subtitle: "6-7 workouts per week",
            icon: "assets/icons/very_active.png",
            selected: selectedActivity == "Very Active",
            onTap: () => onSelected("Very Active"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightBlue.withOpacity(0.35)
              : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.mediumBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Image.asset(
                  icon,
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBlue.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkBlue.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergiesStep extends StatelessWidget {
  final List<String> selectedAllergies;
  final ValueChanged<String> onToggle;

  const _AllergiesStep({
    required this.selectedAllergies,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _StepHeader(
            stepText: "8 / 9",
            titleDark: "Do you have any ",
            titleBlue: "food allergies?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _AllergyOptionChip(
                title: "Peanut",
                image: "assets/icons/peanut.png",
                selected: selectedAllergies.contains("Peanut"),
                onTap: () => onToggle("Peanut"),
              ),
              _AllergyOptionChip(
                title: "Milk",
                image: "assets/icons/milk.png",
                selected: selectedAllergies.contains("Milk"),
                onTap: () => onToggle("Milk"),
              ),
              _AllergyOptionChip(
                title: "Gluten",
                image: "assets/icons/gluten.png",
                selected: selectedAllergies.contains("Gluten"),
                onTap: () => onToggle("Gluten"),
              ),
              _AllergyOptionChip(
                title: "Eggs",
                image: "assets/icons/eggs.png",
                selected: selectedAllergies.contains("Eggs"),
                onTap: () => onToggle("Eggs"),
              ),
              _AllergyOptionChip(
                title: "Seafood",
                image: "assets/icons/seafood.png",
                selected: selectedAllergies.contains("Seafood"),
                onTap: () => onToggle("Seafood"),
              ),
              _AllergyOptionChip(
                title: "Soy",
                image: "assets/icons/soy.png",
                selected: selectedAllergies.contains("Soy"),
                onTap: () => onToggle("Soy"),
              ),
              _AllergyOptionChip(
                title: "Nuts",
                image: "assets/icons/nuts.png",
                selected: selectedAllergies.contains("Nuts"),
                onTap: () => onToggle("Nuts"),
              ),
              _AllergyOptionChip(
                title: "None",
                image: "assets/icons/none.png",
                selected: selectedAllergies.contains("None"),
                onTap: () => onToggle("None"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AllergyOptionChip extends StatelessWidget {
  final String title;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _AllergyOptionChip({
    required this.title,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 100,
        height: 110,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightBlue.withOpacity(0.35)
              : AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.mediumBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      image,
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBlue.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.mediumBlue : Colors.white,
                  border: Border.all(
                    color: selected
                        ? AppColors.mediumBlue
                        : AppColors.darkBlue.withOpacity(0.20),
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionsStep extends StatelessWidget {
  final List<String> selectedConditions;
  final ValueChanged<String> onToggle;

  const _ConditionsStep({
    required this.selectedConditions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _StepHeader(
            stepText: "9 / 9",
            titleDark: "Do you have any ",
            titleBlue: "medical conditions?",
            subtitle:
                "We will use this data to give you\na better diet plan for your life.",
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _ConditionChip(
                title: "Diabetes",
                image: "assets/icons/diabetes.png",
                selected: selectedConditions.contains("Diabetes"),
                onTap: () => onToggle("Diabetes"),
              ),
              _ConditionChip(
                title: "High Blood Pressure",
                image: "assets/icons/blood_pressure.png",
                selected: selectedConditions.contains("High Blood Pressure"),
                onTap: () => onToggle("High Blood Pressure"),
              ),
              _ConditionChip(
                title: "Heart Disease",
                image: "assets/icons/heart.png",
                selected: selectedConditions.contains("Heart Disease"),
                onTap: () => onToggle("Heart Disease"),
              ),
              _ConditionChip(
                title: "Thyroid",
                image: "assets/icons/thyroid.png",
                selected: selectedConditions.contains("Thyroid"),
                onTap: () => onToggle("Thyroid"),
              ),
              _ConditionChip(
                title: "PCOS",
                image: "assets/icons/pcos.png",
                selected: selectedConditions.contains("PCOS"),
                onTap: () => onToggle("PCOS"),
              ),
              _ConditionChip(
                title: "None",
                image: "assets/icons/none.png",
                selected: selectedConditions.contains("None"),
                onTap: () => onToggle("None"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String title;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.title,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 100,
        height: 110,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightBlue.withOpacity(0.35)
              : AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.mediumBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(image, width: 40, height: 40),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBlue.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.mediumBlue : Colors.white,
                  border: Border.all(
                    color: selected
                        ? AppColors.mediumBlue
                        : AppColors.darkBlue.withOpacity(0.25),
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
