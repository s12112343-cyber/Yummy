import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/meal_service.dart';
import 'food_search_panel.dart';

class PhotoAnalyzePanel extends StatefulWidget {
  final ValueChanged<AddedNutrients> onNutrientsAdded;
  final String mealType;

  const PhotoAnalyzePanel({
    super.key,
    required this.onNutrientsAdded,
    required this.mealType,
  });

  @override
  State<PhotoAnalyzePanel> createState() => _PhotoAnalyzePanelState();
}

class _PhotoAnalyzePanelState extends State<PhotoAnalyzePanel>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isLoading = false;
  bool _isPhotoScanning = false;
  String? _errorText;
  Map<String, dynamic>? _analysisResult;
  Size? _imageNaturalSize;
  final TextEditingController _descCtrl = TextEditingController();
  final MealService _mealService = MealService();

  bool _isFetchingIngredients = false;
  String? _recognizedMealName;
  List<String> _recognizedIngredients = [];
  List<String> _possibleAllergens = [];
  double? _mealConfidence;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  static const Color _navy = Color(0xFF061A40);
  static const Color _navy2 = Color(0xFF0B2A5B);
  static const Color _navy3 = Color(0xFF123A7A);
  static const Color _pageBg = Color(0xFFF8FAFD);
  static const Color _cardBorder = Color(0xFFE7EEF8);
  static const Color _mutedText = Color(0xFF66758A);
  static const Color _softNavy = Color(0xFFF1F5FB);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    setState(() {
      _errorText = null;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _descCtrl.text = '';
        _analysisResult = null;
        _isPhotoScanning = true;
      });

      try {
        final bytes = await picked.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imageNaturalSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      } catch (_) {
        _imageNaturalSize = null;
      }

      _scanController.repeat(reverse: true);

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      _scanController.stop();
      _scanController.reset();

      setState(() {
        _isPhotoScanning = false;
      });

      await _analyze();
    } catch (e) {
      setState(() {
        _errorText = 'Failed to open camera';
        _isPhotoScanning = false;
      });
    }
  }

  Future<void> _openGallery() async {
    setState(() {
      _errorText = null;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _descCtrl.text = '';
        _analysisResult = null;
        _isPhotoScanning = true;
      });

      try {
        final bytes = await picked.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imageNaturalSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      } catch (_) {
        _imageNaturalSize = null;
      }

      _scanController.repeat(reverse: true);

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      _scanController.stop();
      _scanController.reset();

      setState(() {
        _isPhotoScanning = false;
      });

      await _analyze();
    } catch (e) {
      setState(() {
        _errorText = 'Failed to pick image from gallery';
        _isPhotoScanning = false;
      });
    }
  }

  Future<void> _analyze() async {
    if (_imageFile == null) {
      setState(() {
        _errorText = 'Please take a photo first.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _isFetchingIngredients = true;
      _errorText = null;
      _analysisResult = null;
      _recognizedMealName = null;
      _recognizedIngredients = [];
      _possibleAllergens = [];
      _mealConfidence = null;
    });

    try {
      final response = await _mealService.analyzePhotoAI(
        imageFile: _imageFile!,
      );

      if (!mounted) return;

      final mealName = _normalizeIngredientLabel(
        response['mealName']?.toString() ?? '',
      );

      final ingredients = _normalizeStringList(response['ingredients']);
      final allergens = _normalizeStringList(response['possibleAllergens']);

      final mealConfidence = response['confidence'] is num
          ? (response['confidence'] as num).toDouble()
          : null;

      setState(() {
        _analysisResult = response;
        _recognizedMealName = mealName.isEmpty ? 'unknown' : mealName;
        _recognizedIngredients = ingredients;
        _possibleAllergens = allergens;
        _mealConfidence = mealConfidence;
        _isLoading = false;
        _isFetchingIngredients = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isFetchingIngredients = false;
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handlePhotoIngredientsConfirmed() {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final calories = toDouble(_analysisResult?['calories']);
    final protein = toDouble(_analysisResult?['protein']);
    final fat = toDouble(_analysisResult?['fat']);
    final carbs = toDouble(_analysisResult?['carbs']);
    final estimatedWeightGrams = toDouble(
      _analysisResult?['estimatedWeightGrams'],
    );

    final fallbackMealName = _analysisResult?['mealName']?.toString().trim();

    final mealName = (_recognizedMealName?.trim().isNotEmpty == true)
        ? _recognizedMealName!.trim()
        : fallbackMealName;

    widget.onNutrientsAdded(
      AddedNutrients(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        foodName: mealName,
        gramsAdded: estimatedWeightGrams > 0 ? estimatedWeightGrams : null,
        confidence: _mealConfidence,
        ingredients: _recognizedIngredients,
        possibleAllergens: _possibleAllergens,
      ),
    );

    _resetPhoto();
  }

  List<String> _normalizeStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    final seen = <String>{};
    final results = <String>[];

    for (final item in value) {
      final cleaned = _normalizeIngredientLabel(item?.toString() ?? '');

      if (cleaned.isEmpty) continue;

      final key = cleaned.toLowerCase();

      if (seen.add(key)) {
        results.add(cleaned);
      }
    }

    return results;
  }

  String _normalizeIngredientLabel(String value) {
    var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (text.isEmpty) {
      return '';
    }

    text = text.replaceFirst(RegExp(r'^[\d\s./-]+'), '');

    text = text.replaceFirst(
      RegExp(
        r'^(?:about|around|approximately|approx\.?|roughly)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceFirst(
      RegExp(
        r'^(?:a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceFirst(
      RegExp(
        r'^(?:cups?|cupfuls?|tablespoons?|tbsp|teaspoons?|tsp|grams?|gram|g|kilograms?|kg|milliliters?|millilitres?|ml|liters?|litres?|ounces?|oz|pounds?|lb|pieces?|slices?|cloves?|cans?|packages?|packs?|pinches?|handfuls?)\b\s*',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'\b(?:fresh|chopped|diced|minced|sliced|grilled|fried|baked|roasted|cooked|raw)\b',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(RegExp(r'[,.;:!?]+$'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  void _resetPhoto() {
    _scanController.stop();
    _scanController.reset();

    setState(() {
      _imageFile = null;
      _descCtrl.clear();
      _errorText = null;
      _analysisResult = null;
      _isPhotoScanning = false;
      _isLoading = false;
      _imageNaturalSize = null;
      _recognizedMealName = null;
      _recognizedIngredients = [];
      _possibleAllergens = [];
      _mealConfidence = null;
      _isFetchingIngredients = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _imageFile == null ? _buildEmptyState() : _buildAnalyzeContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const ValueKey('empty-photo-state'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(),
          const SizedBox(height: 18),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: _white,
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 22,
                  right: 28,
                  child: _softCircle(size: 54, opacity: 0.08),
                ),
                Positioned(
                  bottom: 20,
                  left: 24,
                  child: _softCircle(size: 72, opacity: 0.06),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_navy, _navy2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: _navy.withOpacity(0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Analyze your meal photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: Text(
                          'Take a clear plate photo and let AI detect ingredients, allergens, and nutrition.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _mutedText,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'Take Photo',
            icon: Icons.camera_alt_rounded,
            onPressed: _openCamera,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openGallery,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _navy.withOpacity(0.14)),
                backgroundColor: _white,
                foregroundColor: _navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text(
                'Upload from phone',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTipsRow(),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            _errorBox(_errorText!),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyzeContent() {
    return Container(
      key: const ValueKey('photo-selected-state'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _softNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isPhotoScanning
                      ? Icons.document_scanner_rounded
                      : Icons.restaurant_menu_rounded,
                  color: _navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPhotoScanning
                          ? 'Scanning photo...'
                          : _isFetchingIngredients
                          ? 'Analyzing ingredients...'
                          : 'Photo Analysis',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPhotoScanning
                          ? 'Detecting meal areas from your photo'
                          : _isFetchingIngredients
                          ? 'Preparing meal result and nutrition'
                          : 'Review the result before adding it',
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                    (_isLoading || _isPhotoScanning || _isFetchingIngredients)
                    ? null
                    : _resetPhoto,
                style: IconButton.styleFrom(
                  backgroundColor: _softNavy,
                  foregroundColor: _navy,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildImageWithScanAnimation(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isPhotoScanning || _isFetchingIngredients
                ? _buildScanningStatus()
                : _buildReadyForm(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            _errorBox(_errorText!),
          ],
          if (_analysisResult != null && !_isFetchingIngredients) ...[
            const SizedBox(height: 14),
            _buildAnalysisResultSection(_analysisResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildImageWithScanAnimation() {
    return Stack(
      children: [
        Container(
          height: 245,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _imageNaturalSize?.width ?? 1,
                    height: _imageNaturalSize?.height ?? 1,
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (_isPhotoScanning)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            Container(color: _navy.withOpacity(0.16)),
                            Positioned(
                              top: 245 * _scanAnimation.value,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.9),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.85),
                                    width: 1.3,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                            Positioned(left: 18, top: 18, child: _scanCorner()),
                            Positioned(
                              right: 18,
                              top: 18,
                              child: Transform.rotate(
                                angle: 1.5708,
                                child: _scanCorner(),
                              ),
                            ),
                            Positioned(
                              right: 18,
                              bottom: 18,
                              child: Transform.rotate(
                                angle: 3.1416,
                                child: _scanCorner(),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              bottom: 18,
                              child: Transform.rotate(
                                angle: -1.5708,
                                child: _scanCorner(),
                              ),
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.94),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _navy,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'AI scanning...',
                                      style: TextStyle(
                                        color: _navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (!_isPhotoScanning)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: _navy,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Photo ready',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanningStatus() {
    return Container(
      key: const ValueKey('scanning-status'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _navy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isFetchingIngredients
                  ? 'Analyzing the photo and organizing your meal result...'
                  : 'Please wait while we prepare your photo for analysis...',
              style: const TextStyle(
                color: _mutedText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyForm() {
    return Column(
      key: const ValueKey('ready-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _primaryButton(
                label: _isLoading ? 'Analyzing...' : 'Analyze Meal',
                icon: Icons.auto_awesome_rounded,
                onPressed: _isLoading ? null : _analyze,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              child: _secondaryButton(
                icon: Icons.refresh_rounded,
                onPressed: _isLoading ? null : _resetPhoto,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalysisResultSection(Map<String, dynamic> analysis) {
    final mealName =
        (_recognizedMealName ?? analysis['mealName']?.toString() ?? '').trim();

    final ingredients = _recognizedIngredients.isNotEmpty
        ? _recognizedIngredients
        : _normalizeStringList(analysis['ingredients']);

    final allergens = _possibleAllergens.isNotEmpty
        ? _possibleAllergens
        : _normalizeStringList(analysis['possibleAllergens']);

    final confidence =
        _mealConfidence ??
        (analysis['confidence'] is num
            ? (analysis['confidence'] as num).toDouble()
            : null);

    final calories = _toNumOrNull(analysis['calories']);
    final protein = _toNumOrNull(analysis['protein']);
    final carbs = _toNumOrNull(analysis['carbs']);
    final fat = _toNumOrNull(analysis['fat']);
    final weight = _toNumOrNull(analysis['estimatedWeightGrams']);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _premiumSectionHeader(),
            const SizedBox(height: 14),
            _premiumMealCard(
              mealName: mealName.isEmpty ? 'Unknown meal' : mealName,
              confidence: confidence,
            ),
            const SizedBox(height: 14),
            _premiumCaloriesCard(calories),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _animatedMacroTile(
                    delay: 80,
                    icon: Icons.fitness_center_rounded,
                    label: 'Protein',
                    value: '${_formatNutritionValue(protein, digits: 1)}g',
                    accentColor: AppColors.proteinBlue,
                    accentBackground: AppColors.proteinBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _animatedMacroTile(
                    delay: 140,
                    icon: Icons.grain_rounded,
                    label: 'Carbs',
                    value: '${_formatNutritionValue(carbs, digits: 1)}g',
                    accentColor: AppColors.carbsGreen,
                    accentBackground: AppColors.carbsBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _animatedMacroTile(
                    delay: 200,
                    icon: Icons.water_drop_rounded,
                    label: 'Fat',
                    value: '${_formatNutritionValue(fat, digits: 1)}g',
                    accentColor: AppColors.fatOrange,
                    accentBackground: AppColors.fatBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _animatedMacroTile(
                    delay: 260,
                    icon: Icons.scale_rounded,
                    label: 'Weight',
                    value: '${_formatNutritionValue(weight)}g',
                    accentColor: AppColors.royalBlue,
                    accentBackground: AppColors.babyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _premiumInfoCard(
              title: 'Detected Ingredients',
              subtitle: '${ingredients.length} items found',
              icon: Icons.eco_rounded,
              child: ingredients.isEmpty
                  ? _premiumEmptyMessage(
                      icon: Icons.info_outline_rounded,
                      text: 'No ingredients detected.',
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        ingredients.length,
                        (index) => _staggeredChip(
                          index: index,
                          child: _premiumIngredientChip(ingredients[index]),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _premiumInfoCard(
              title: 'Possible Allergens',
              subtitle: allergens.isEmpty
                  ? 'No warning detected'
                  : '${allergens.length} warning items',
              icon: Icons.health_and_safety_rounded,
              child: allergens.isEmpty
                  ? _safeAllergenMessage()
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        allergens.length,
                        (index) => _staggeredChip(
                          index: index,
                          child: _premiumAllergenChip(allergens[index]),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: ingredients.isEmpty
                    ? null
                    : _handlePhotoIngredientsConfirmed,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _navy.withOpacity(0.45),
                  elevation: 0,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  num? _toNumOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  String _formatNutritionValue(num? value, {int digits = 0}) {
    if (value == null || value <= 0) return '--';
    return value.toStringAsFixed(digits);
  }

  Widget _premiumSectionHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy, _navy2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Meal Result',
                style: TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Smart analysis summary',
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _premiumMealCard({
    required String mealName,
    required double? confidence,
  }) {
    final safeConfidence = confidence == null
        ? null
        : confidence.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navy2, _navy3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -28,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -42,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Meal',
                      style: TextStyle(
                        color: Color(0xFFD6E4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mealName,
                      softWrap: true,
                      maxLines: 10,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (safeConfidence != null) ...[
                const SizedBox(width: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: safeConfidence),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: value,
                            strokeWidth: 5,
                            backgroundColor: Colors.white.withOpacity(0.16),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumCaloriesCard(num? calories) {
    final endValue = calories == null ? 0.0 : calories.toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: endValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _softNavy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: _navy,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Calories',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      calories == null || calories <= 0
                          ? '-- kcal'
                          : '${value.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _softNavy,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _animatedMacroTile({
    required int delay,
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required Color accentBackground,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Curves.easeOutBack,
      builder: (context, progress, child) {
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.92 + (0.08 * progress), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.035),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentBackground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumInfoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _softNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _navy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _staggeredChip({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 70)),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: Transform.scale(scale: 0.9 + (0.1 * value), child: child),
          ),
        );
      },
      child: child,
    );
  }

  Widget _premiumIngredientChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _softNavy,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: _navy, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumAllergenChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB91C1C),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeAllergenMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'No likely allergens detected.',
              style: TextStyle(
                color: Color(0xFF15803D),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumEmptyMessage({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _mutedText, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCorner() {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _ScanCornerPainter()),
    );
  }

  Widget _buildHeaderBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _softNavy,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _navy.withOpacity(0.08)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: _navy, size: 15),
              SizedBox(width: 6),
              Text(
                'AI Photo Meal',
                style: TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _cardBorder),
          ),
          child: const Text(
            'Beta',
            style: TextStyle(
              color: _navy,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: _navy, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: clear light and a full plate view gives better nutrition results.',
              style: TextStyle(
                color: _mutedText,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _navy,
          disabledBackgroundColor: _navy.withOpacity(0.55),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: _navy.withOpacity(0.24),
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Analyzing...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _navy,
          side: BorderSide(color: _navy.withOpacity(0.12)),
          backgroundColor: _white,
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD6DA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFC62828),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _cardBorder),
      boxShadow: [
        BoxShadow(
          color: _navy.withOpacity(0.06),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  Widget _softCircle({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _navy.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScanCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.65)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.65, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
