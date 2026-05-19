import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/back_button_widget.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();

  static const Map<String, String> _goalOptions = {
    "lose_weight": "Lose weight",
    "gain_weight": "Gain weight",
    "stay_healthy": "Stay healthy",
  };

  static const Map<String, String> _genderOptions = {
    "male": "Male",
    "female": "Female",
  };

  static const Map<String, String> _activityOptions = {
    "sedentary": "Sedentary",
    "lightly_active": "Lightly Active",
    "moderately_active": "Moderately Active",
    "very_active": "Very Active",
  };

  static const List<Map<String, dynamic>> _allergyOptionItems = [
    {
      "label": "Peanut",
      "asset": "assets/icons/peanut.png",
      "color": Color(0xFFE67E80),
    },
    {
      "label": "Milk",
      "asset": "assets/icons/milk.png",
      "color": Color(0xFF5A9BD8),
    },
    {
      "label": "Gluten",
      "asset": "assets/icons/gluten.png",
      "color": Color(0xFFD2A44B),
    },
    {
      "label": "Eggs",
      "asset": "assets/icons/eggs.png",
      "color": Color(0xFFF0A95F),
    },
    {
      "label": "Seafood",
      "asset": "assets/icons/seafood.png",
      "color": Color(0xFF4BA7A1),
    },
    {
      "label": "Soy",
      "asset": "assets/icons/soy.png",
      "color": Color(0xFF7AA35A),
    },
    {
      "label": "Nuts",
      "asset": "assets/icons/nuts.png",
      "color": Color(0xFFB67A54),
    },
    {
      "label": "None",
      "asset": "assets/icons/none.png",
      "color": Color(0xFF8D99AE),
    },
  ];

  static const List<Map<String, dynamic>> _conditionOptionItems = [
    {
      "label": "Diabetes",
      "asset": "assets/icons/diabetes.png",
      "color": Color(0xFF8E7CF0),
    },
    {
      "label": "High Blood Pressure",
      "asset": "assets/icons/blood_pressure.png",
      "color": Color(0xFFE06B6E),
    },
    {
      "label": "Heart Disease",
      "asset": "assets/icons/heart.png",
      "color": Color(0xFFE15B84),
    },
    {
      "label": "Thyroid",
      "asset": "assets/icons/thyroid.png",
      "color": Color(0xFF4EAAB8),
    },
    {
      "label": "PCOS",
      "asset": "assets/icons/pcos.png",
      "color": Color(0xFFB07CC6),
    },
    {
      "label": "None",
      "asset": "assets/icons/none.png",
      "color": Color(0xFF8D99AE),
    },
  ];

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? user;
  File? _selectedImageFile;
  String? _profileImageUrl;
  DateTime? _selectedBirthDate;
  String _selectedGoal = "";
  String _selectedGender = "";
  String _selectedActivity = "";
  String _heightUnit = "cm";
  String _weightUnit = "kg";
  List<String> _selectedAllergies = [];
  List<String> _selectedConditions = [];

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
    fetchUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _recoverLostImage() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;

    final List<XFile>? files = response.files;
    if (files != null && files.isNotEmpty) {
      final convertedFile = await _convertXFileToJpg(files.first);
      setState(() {
        _selectedImageFile = convertedFile ?? File(files.first.path);
      });
    }
  }

  Future<File?> _convertXFileToJpg(XFile pickedFile) async {
    try {
      final inputBytes = await pickedFile.readAsBytes();
      final decodedImage = img.decodeImage(inputBytes);

      if (decodedImage == null) {
        return null;
      }

      final normalizedImage = img.bakeOrientation(decodedImage);
      final jpgBytes = img.encodeJpg(normalizedImage, quality: 90);

      final sourceDir = p.dirname(pickedFile.path);
      final sourceName = p.basenameWithoutExtension(pickedFile.path);
      final outputPath = p.join(
        sourceDir,
        '${sourceName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpgBytes, flush: true);
      return outputFile;
    } catch (error) {
      print('Image conversion to JPG failed: $error');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
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

  DateTime? _safeParseDate(dynamic value) {
    if (value == null) return null;

    try {
      final parsed = DateTime.parse(value.toString());
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  String _numberText(dynamic value) {
    if (value == null) return "";

    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }

    return value.toString();
  }

  String _safeOptionValue(dynamic value, Map<String, String> options) {
    final candidate = value?.toString() ?? "";
    return options.containsKey(candidate) ? candidate : "";
  }

  String _toReadableListItem(String item) {
    final normalized = item
        .trim()
        .replaceAll("_", " ")
        .replaceAll(RegExp(r"\s+"), " ")
        .toLowerCase();

    if (normalized.isEmpty) return "";

    return normalized
        .split(" ")
        .map(
          (word) => word.isEmpty
              ? word
              : "${word[0].toUpperCase()}${word.substring(1)}",
        )
        .join(" ");
  }

  String _normalizeLookup(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = value?.toString() ?? "";
    if (raw.isEmpty) return null;

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? "${baseUri.host}:${baseUri.port}"
        : baseUri.host;
    final origin = "${baseUri.scheme}://$authority";

    if (raw.startsWith("/")) {
      return "$origin$raw";
    }

    return "$origin/$raw";
  }

  List<String> _extractSelectedOptions(
    dynamic rawList,
    List<Map<String, dynamic>> optionItems,
  ) {
    final optionLookup = <String, String>{
      for (final item in optionItems)
        _normalizeLookup(item["label"] as String): item["label"] as String,
    };

    if (rawList is! List) {
      return optionLookup.containsValue("None") ? ["None"] : [];
    }

    final selected = <String>[];

    for (final raw in rawList) {
      final readable = _toReadableListItem(raw.toString());
      final mapped = optionLookup[_normalizeLookup(readable)];
      if (mapped != null && !selected.contains(mapped)) {
        selected.add(mapped);
      }
    }

    if (selected.isEmpty && optionLookup.containsValue("None")) {
      return ["None"];
    }

    return selected;
  }

  List<String> _toApiList(List<String> values) {
    if (values.any((value) => value.toLowerCase() == "none")) {
      return [];
    }

    return values
        .map(
          (value) => value
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r"\s+"), "_")
              .replaceAll(RegExp(r"_+"), "_"),
        )
        .where((value) => value.isNotEmpty && value != "none")
        .toList();
  }

  void _toggleSelectableOption({
    required List<String> selected,
    required String value,
  }) {
    if (value == "None") {
      if (selected.contains("None")) {
        selected.remove("None");
      } else {
        selected
          ..clear()
          ..add("None");
      }
      return;
    }

    selected.remove("None");

    if (selected.contains(value)) {
      selected.remove(value);
      if (selected.isEmpty) {
        selected.add("None");
      }
      return;
    }

    selected.add(value);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 22, 1, 1);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedBirthDate = DateUtils.dateOnly(pickedDate);
      _dobCtrl.text = _formatDate(_selectedBirthDate!);
      _ageCtrl.text = _calculateAge(_selectedBirthDate!).toString();
    });
  }

  Future<void> fetchUser() async {
    try {
      setState(() => _isLoading = true);

      final provider = context.read<UserProvider>();
      await provider.fetchUser();
      final fetchedUser = provider.user;

      if (fetchedUser == null) {
        setState(() => _isLoading = false);
        _showSnack("Failed to load user data");
        return;
      }

      final profile = Map<String, dynamic>.from(fetchedUser["profile"] ?? {});
      final height = profile["height"] is Map
          ? Map<String, dynamic>.from(profile["height"])
          : <String, dynamic>{};
      final weight = profile["weight"] is Map
          ? Map<String, dynamic>.from(profile["weight"])
          : <String, dynamic>{};

      final parsedBirthDate = _safeParseDate(profile["date_of_birth"]);
      final goalValue = _safeOptionValue(profile["goal"], _goalOptions);
      final genderValue = _safeOptionValue(profile["gender"], _genderOptions);
      final activityValue = _safeOptionValue(
        profile["activity_level"],
        _activityOptions,
      );

      setState(() {
        user = fetchedUser;

        _nameCtrl.text = fetchedUser["name"]?.toString() ?? "";
        _emailCtrl.text = fetchedUser["email"]?.toString() ?? "";
        _heightCtrl.text = _numberText(height["value"]);
        _weightCtrl.text = _numberText(weight["value"]);
        _heightUnit = (height["unit"]?.toString().isNotEmpty ?? false)
            ? height["unit"].toString()
            : "cm";
        _weightUnit = (weight["unit"]?.toString().isNotEmpty ?? false)
            ? weight["unit"].toString()
            : "kg";
        _selectedBirthDate = parsedBirthDate;
        _dobCtrl.text = parsedBirthDate != null
            ? _formatDate(parsedBirthDate)
            : "";
        _ageCtrl.text = parsedBirthDate != null
            ? _calculateAge(parsedBirthDate).toString()
            : "";
        _selectedGoal = goalValue;
        _selectedGender = genderValue;
        _selectedActivity = activityValue;
        _selectedAllergies = _extractSelectedOptions(
          profile["allergies"],
          _allergyOptionItems,
        );
        _selectedConditions = _extractSelectedOptions(
          profile["medical_conditions"],
          _conditionOptionItems,
        );

        final rawImageValue =
            profile["image_url"] ??
            profile["image"] ??
            profile["imageUrl"] ??
            fetchedUser["imageUrl"];
        _profileImageUrl = _resolveImageUrl(rawImageValue);
        _selectedImageFile = null;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Error: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      final convertedFile = await _convertXFileToJpg(image);

      setState(() {
        _selectedImageFile = convertedFile ?? File(image.path);
      });
    } catch (e) {
      _showSnack("Failed to pick image");
    }
  }

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Choose Profile Picture",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _imageOption(
                        icon: Icons.photo_library_rounded,
                        title: "Gallery",
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _imageOption(
                        icon: Icons.camera_alt_rounded,
                        title: "Camera",
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedHeight = int.tryParse(_heightCtrl.text.trim());
    final parsedWeight = double.tryParse(_weightCtrl.text.trim());

    if (parsedHeight == null || parsedHeight < 50 || parsedHeight > 300) {
      _showSnack("Height must be between 50 and 300");
      return;
    }

    if (parsedWeight == null || parsedWeight < 10 || parsedWeight > 600) {
      _showSnack("Weight must be between 10 and 600");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Round weight to 2 decimal places
      final roundedWeight = (parsedWeight * 100).round() / 100.0;

      final response = await context.read<UserProvider>().saveProfile(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        imageFile: _selectedImageFile,
        goal: _selectedGoal,
        gender: _selectedGender,
        dateOfBirth: _selectedBirthDate?.toIso8601String() ?? "",
        heightValue: parsedHeight,
        heightUnit: _heightUnit,
        weightValue: roundedWeight,
        weightUnit: _weightUnit,
        activityLevel: _selectedActivity,
        allergies: _toApiList(_selectedAllergies),
        medicalConditions: _toApiList(_selectedConditions),
      );

      if (!mounted) return;

      final hasError = response["error"] == true;
      final hasUpdatedData =
          response["profile"] != null && response["user"] != null;

      if (hasError || !hasUpdatedData) {
        _showSnack(
          response["message"]?.toString() ?? "Failed to update profile",
        );
        setState(() => _isSaving = false);
        return;
      }

      await fetchUser();

      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccessDialog();
      }
    } catch (error) {
      if (mounted) {
        _showSnack("Error: ${error.toString()}");
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Lottie.asset(
                    'assets/lottie/Verification.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.deepBlue,
                        size: 68,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profile updated successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepBlue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ImageProvider? _buildAvatarImage() {
    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      // Print for debugging
      print('📸 Loading image from: $_profileImageUrl');
      return NetworkImage(_profileImageUrl!);
    }

    print('⚠️ No image URL available');
    return null;
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return "U";
    final parts = name.trim().split(" ");

    // Handle single word name
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    // Handle multi-word name - safely access indices
    final firstInitial = parts[0].isNotEmpty ? parts[0][0] : '';
    final secondInitial = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0]
        : '';

    return "$firstInitial$secondInitial".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _nameCtrl.text.isEmpty ? "User" : _nameCtrl.text;
    final avatarImage = _buildAvatarImage();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) {
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * 18),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipPath(
                                    clipper: _HeaderWaveClipper(),
                                    child: Container(
                                      height: 138,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.navy.withValues(
                                              alpha: 0.93,
                                            ),
                                            AppColors.deepBlue.withValues(
                                              alpha: 0.82,
                                            ),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    left: 12,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.white.withValues(
                                          alpha: 0.90,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const AppBackButton(
                                        backgroundColor: Colors.transparent,
                                        showBorder: false,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 16,
                                    left: 72,
                                    right: 72,
                                    child: const Text(
                                      "Personal Details",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: -66,
                                    child: Center(
                                      child: Transform.scale(
                                        scale: 0.92 + (0.08 * t),
                                        child: GestureDetector(
                                          onTap: _showImageSourceSheet,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: 140,
                                                height: 140,
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.white,
                                                  border: Border.all(
                                                    color: AppColors.navy,
                                                    width: 4.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.deepBlue
                                                          .withValues(
                                                            alpha: 0.14,
                                                          ),
                                                      blurRadius: 22,
                                                      offset: const Offset(
                                                        0,
                                                        8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: CircleAvatar(
                                                  radius: 64,
                                                  backgroundColor:
                                                      AppColors.background,
                                                  backgroundImage: avatarImage,
                                                  onBackgroundImageError:
                                                      avatarImage == null
                                                      ? null
                                                      : (
                                                          exception,
                                                          stackTrace,
                                                        ) {
                                                          print(
                                                            '❌ Image load error: $exception',
                                                          );
                                                          print(
                                                            '📍 URL was: $_profileImageUrl',
                                                          );
                                                          if (!mounted) return;
                                                          setState(() {
                                                            _profileImageUrl =
                                                                null;
                                                          });
                                                        },
                                                  child: avatarImage == null
                                                      ? Text(
                                                          getInitials(
                                                            currentName,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 36,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: AppColors
                                                                    .deepBlue,
                                                              ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              Positioned(
                                                bottom: -2,
                                                right: -2,
                                                child: Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.deepBlue,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.camera_alt_rounded,
                                                    size: 18,
                                                    color: AppColors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 70),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 780),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * 14),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.65),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                            child: Column(
                              children: [
                                Text(
                                  currentName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _emailCtrl.text,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.deepBlue.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _buildSectionHeader("Basic Info"),
                                _buildSectionCard(
                                  children: [
                                    _buildTextField(
                                      controller: _nameCtrl,
                                      label: "Full Name",
                                      icon: Icons.person_outline_rounded,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return "Please enter your name";
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextField(
                                      controller: _emailCtrl,
                                      label: "Email",
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return "Please enter your email";
                                        }
                                        if (!value.contains("@")) {
                                          return "Enter a valid email";
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDropdownField(
                                      label: "Gender",
                                      icon: Icons.wc_rounded,
                                      value: _selectedGender,
                                      options: _genderOptions,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGender = value ?? "";
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTwoColumnRow(
                                      left: _buildTextField(
                                        controller: _dobCtrl,
                                        label: "Date of Birth",
                                        icon: Icons.calendar_month_rounded,
                                        readOnly: true,
                                        onTap: _pickBirthDate,
                                      ),
                                      right: _buildTextField(
                                        controller: _ageCtrl,
                                        label: "Age",
                                        icon: Icons.cake_outlined,
                                        readOnly: true,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),
                                _buildSectionHeader("Body Info"),
                                _buildSectionCard(
                                  children: [
                                    _buildTwoColumnRow(
                                      left: _buildTextField(
                                        controller: _heightCtrl,
                                        label: "Height",
                                        icon: Icons.height_rounded,
                                        keyboardType: TextInputType.number,
                                      ),
                                      right: _buildTextField(
                                        controller: _weightCtrl,
                                        label: "Weight",
                                        icon: Icons.monitor_weight_outlined,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDropdownField(
                                      label: "Activity Level",
                                      icon: Icons.directions_run_rounded,
                                      value: _selectedActivity,
                                      options: _activityOptions,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedActivity = value ?? "";
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDropdownField(
                                      label: "Goal",
                                      icon: Icons.flag_outlined,
                                      value: _selectedGoal,
                                      options: _goalOptions,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGoal = value ?? "";
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),
                                _buildSectionHeader("Health Info"),
                                _buildSectionCard(
                                  children: [
                                    _buildOptionsSectionTitle(
                                      title: "Allergies / Restrictions",
                                      icon: Icons.no_food_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildVisualOptionGrid(
                                      optionItems: _allergyOptionItems,
                                      selectedValues: _selectedAllergies,
                                      onTapOption: (value) {
                                        setState(() {
                                          _toggleSelectableOption(
                                            selected: _selectedAllergies,
                                            value: value,
                                          );
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildOptionsSectionTitle(
                                      title: "Medical Conditions",
                                      icon: Icons.medical_information_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildVisualOptionGrid(
                                      optionItems: _conditionOptionItems,
                                      selectedValues: _selectedConditions,
                                      onTapOption: (value) {
                                        setState(() {
                                          _toggleSelectableOption(
                                            selected: _selectedConditions,
                                            value: value,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : saveUserData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.deepBlue,
                                      disabledBackgroundColor: AppColors
                                          .deepBlue
                                          .withValues(alpha: 0.65),
                                      foregroundColor: AppColors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: AppColors.royalBlue.withValues(
                                            alpha: 0.30,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Save Changes",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
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
            ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildOptionsSectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.royalBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.deepBlue, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildVisualOptionGrid({
    required List<Map<String, dynamic>> optionItems,
    required List<String> selectedValues,
    required ValueChanged<String> onTapOption,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: optionItems.map((item) {
        final label = item["label"] as String;
        final asset = item["asset"] as String;
        final color = item["color"] as Color;
        final isSelected = selectedValues.contains(label);

        return _buildAppleStyleCard(
          label: label,
          asset: asset,
          accentColor: color,
          isSelected: isSelected,
          onTap: () => onTapOption(label),
        );
      }).toList(),
    );
  }

  Widget _buildAppleStyleCard({
    required String label,
    required String asset,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 56, maxWidth: 178),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? AppColors.lightBlue.withValues(alpha: 0.28)
                : AppColors.background,
            border: Border.all(
              color: isSelected
                  ? AppColors.deepBlue.withValues(alpha: 0.45)
                  : AppColors.royalBlue.withValues(alpha: 0.16),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.image_not_supported_outlined,
                    color: isSelected ? AppColors.deepBlue : accentColor,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.deepBlue
                        : AppColors.darkBlue.withValues(alpha: 0.82),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 11.2,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? hintText,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.deepBlue,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(
          icon,
          color: AppColors.deepBlue.withValues(alpha: 0.88),
        ),
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.75),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        labelStyle: TextStyle(
          color: AppColors.blueGray.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.royalBlue.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final selectedLabel = options[value];
    final hasValue = value.isNotEmpty && selectedLabel != null;

    return PopupMenuButton<String>(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      tooltip: "",
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (selectedValue) => onChanged(selectedValue),
      itemBuilder: (context) {
        return options.entries.map((entry) {
          final isSelected = entry.key == value;
          return PopupMenuItem<String>(
            value: entry.key,
            child: Text(
              entry.value,
              style: TextStyle(
                color: isSelected ? AppColors.navy : AppColors.deepBlue,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.royalBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.deepBlue.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.deepBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.blueGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? selectedLabel : "Select $label",
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.deepBlue.withValues(alpha: 0.95)
                          : AppColors.blueGray.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.deepBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.deepBlue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 10);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height - 1,
      size.width * 0.5,
      size.height - 5,
    );
    path.quadraticBezierTo(
      size.width * 0.76,
      size.height - 9,
      size.width,
      size.height - 7,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
