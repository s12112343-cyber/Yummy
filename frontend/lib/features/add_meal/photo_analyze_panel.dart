import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

import '../../core/services/meal_service.dart';
import '../../core/theme/app_colors.dart';
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
  List<String> _detectedNames = [];
  List<Map<String, dynamic>> _detectedItems = [];
  Size? _imageNaturalSize;
  int _selectedIndex = -1;
  final TextEditingController _descCtrl = TextEditingController();
  final MealService _mealService = MealService();

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  // palette for detected item boxes
  final List<Color> _boxColors = [
    Colors.redAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
  ];

  static const Color _navy = Color(0xFF061A40);
  static const Color _pageBg = Color(0xFFF6F8FC);
  static const Color _cardBorder = Color(0xFFE2EAF5);
  static const Color _mutedText = Color(0xFF6B7A90);

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

      // get natural image size for mapping bboxes
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

      // automatically analyze after scan animation completes
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

      // get natural image size for mapping bboxes
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

      // automatically analyze after scan animation completes
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
      _errorText = null;
      _analysisResult = null;
    });

    try {
      final response = await _mealService.analyzeImageAI(
        imageFile: _imageFile!,
        mealType: widget.mealType,
        note: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = response;
        // extract names from model predictions and show only those
        final items = (response['items'] as List<dynamic>?) ?? <dynamic>[];
        _detectedItems = items
            .whereType<Map<String, dynamic>>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _detectedNames = _detectedItems
            .map(
              (m) => (m['name'] ?? m['class'] ?? m['label'] ?? '').toString(),
            )
            .where((s) => s.trim().isNotEmpty)
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
      _detectedItems = [];
      _detectedNames = [];
      _imageNaturalSize = null;
    });
  }

  void _openPreview(int index) {
    if (index < 0 || index >= _detectedItems.length) return;
    final item = _detectedItems[index];
    final name = (item['name'] ?? item['class'] ?? item['label'] ?? '')
        .toString();

    // show only the image preview when tapping a bbox (no add controls here)
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: math.min(MediaQuery.of(context).size.height * 0.85, 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Detected item' : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(child: Image.file(_imageFile!)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addDetectedItem(int index) {
    // support when items are coming from _analysisResult (initial render)
    final sourceItems = _detectedItems.isNotEmpty
        ? _detectedItems
        : ((_analysisResult?['items'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList() ??
              <Map<String, dynamic>>[]);

    if (index < 0 || index >= sourceItems.length) return;
    final item = sourceItems[index];
    final name = (item['name'] ?? item['class'] ?? item['label'] ?? '')
        .toString();

    // Currently no nutrient estimates from model — add as zero-valued entry
    widget.onNutrientsAdded(
      AddedNutrients(
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        foodName: name.isEmpty ? null : name,
        gramsAdded: null,
      ),
    );

    // update detected lists in state so UI reflects removal
    setState(() {
      if (_detectedItems.isEmpty) {
        // create a mutable copy from analysis and remove the selected
        _detectedItems = sourceItems.toList();
      }
      if (index >= 0 && index < _detectedItems.length) {
        _detectedItems.removeAt(index);
      }
      _detectedNames = _detectedItems
          .map((m) => (m['name'] ?? m['class'] ?? m['label'] ?? '').toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    });
  }

  void _addAllDetectedItems() {
    final sourceItems = _detectedItems.isNotEmpty
        ? _detectedItems
        : ((_analysisResult?['items'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList() ??
              <Map<String, dynamic>>[]);

    if (sourceItems.isEmpty) return;

    for (final item in sourceItems) {
      final name = (item['name'] ?? item['class'] ?? item['label'] ?? '')
          .toString();
      widget.onNutrientsAdded(
        AddedNutrients(
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          foodName: name.isEmpty ? null : name,
          gramsAdded: null,
        ),
      );
    }

    // clear detected items from UI after adding
    setState(() {
      _detectedItems = [];
      _detectedNames = [];
      _analysisResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(14),
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
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(),
          const SizedBox(height: 18),
          Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _cardBorder),
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
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _navy.withOpacity(0.22),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 42,
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
                          'Take a clear plate photo and let the AI detect items, estimate quantities, and calculate nutrition.',
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
                side: BorderSide(color: _navy.withOpacity(0.12)),
                backgroundColor: const Color(0xFFF8FAFD),
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                  color: _navy.withOpacity(0.08),
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
                      _isPhotoScanning ? 'Scanning photo...' : 'Photo Analysis',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_isPhotoScanning)
                      const Text(
                        'Detecting meal areas from your photo',
                        style: TextStyle(
                          color: _mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading || _isPhotoScanning ? null : _resetPhoto,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F5FA),
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
            child: _isPhotoScanning
                ? _buildScanningStatus()
                : _buildReadyForm(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            _errorBox(_errorText!),
          ],
          if (_analysisResult != null) ...[
            const SizedBox(height: 14),
            _buildAnalysisResultSection(_analysisResult!),
          ],
          // bottom Add button (moved here from Detected header)
          if ((_detectedItems.isNotEmpty) ||
              (((_analysisResult?['items'] as List<dynamic>?)?.isNotEmpty) ??
                  false))
            const SizedBox(height: 12),
          if ((_detectedItems.isNotEmpty) ||
              (((_analysisResult?['items'] as List<dynamic>?)?.isNotEmpty) ??
                  false))
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _addAllDetectedItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add to my meal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final displayW = constraints.maxWidth;
              final displayH = 245.0;

              final natural = _imageNaturalSize;
              double renderW = displayW;
              double renderH = displayH;
              double dx = 0, dy = 0;

              if (natural != null && natural.width > 0 && natural.height > 0) {
                final scale = math.min(
                  displayW / natural.width,
                  displayH / natural.height,
                );
                renderW = natural.width * scale;
                renderH = natural.height * scale;
                dx = (displayW - renderW) / 2.0;
                dy = (displayH - renderH) / 2.0;
              }

              // prepare entries list for rendering detected boxes
              var entries = <MapEntry<int, dynamic>>[];
              if (_detectedItems.isNotEmpty && _imageNaturalSize != null) {
                final all = _detectedItems.asMap().entries.toList();
                entries = (_selectedIndex != -1 && _selectedIndex < all.length)
                    ? [all[_selectedIndex]]
                    : all;
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _imageNaturalSize?.width ?? displayW,
                        height: _imageNaturalSize?.height ?? displayH,
                        child: Image.file(_imageFile!, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  // tap outside boxes to clear selection
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_selectedIndex != -1) {
                          setState(() {
                            _selectedIndex = -1;
                          });
                        }
                      },
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  // draw detected bounding boxes if available
                  if (entries.isNotEmpty)
                    ...entries.expand((e) sync* {
                      final idx = e.key;
                      final item = e.value;
                      final bboxRaw = (item['bbox'] as List<dynamic>?) ?? [];
                      if (bboxRaw.length < 4) return;
                      double x1 = (bboxRaw[0] as num).toDouble();
                      double y1 = (bboxRaw[1] as num).toDouble();
                      double x2 = (bboxRaw[2] as num).toDouble();
                      double y2 = (bboxRaw[3] as num).toDouble();

                      final naturalW = _imageNaturalSize!.width;
                      final naturalH = _imageNaturalSize!.height;

                      // handle normalized coords (0..1) or absolute
                      if (x1 <= 1 && y1 <= 1 && x2 <= 1 && y2 <= 1) {
                        x1 *= naturalW;
                        x2 *= naturalW;
                        y1 *= naturalH;
                        y2 *= naturalH;
                      }

                      final scale = math.min(
                        displayW / naturalW,
                        displayH / naturalH,
                      );
                      final left = dx + x1 * scale;
                      final top = dy + y1 * scale;
                      final w = (x2 - x1) * scale;
                      final h = (y2 - y1) * scale;
                      final boxColor = _boxColors[idx % _boxColors.length]
                          .withOpacity(0.95);
                      final bgColor = boxColor.withOpacity(0.12);

                      // label position: try to place above the box, but keep inside bounds
                      const labelHeight = 22.0;
                      final labelTop = (top - labelHeight - 6).clamp(
                        0.0,
                        displayH,
                      );

                      // yield the box then the label (label painted above)
                      yield Positioned(
                        left: left.clamp(0, displayW),
                        top: top.clamp(0, displayH),
                        width: w.clamp(8, displayW),
                        height: h.clamp(8, displayH),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = idx;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: boxColor, width: 2),
                              color: bgColor,
                            ),
                          ),
                        ),
                      );

                      final name =
                          (item['name'] ?? item['class'] ?? item['label'] ?? '')
                              .toString();

                      // if a box is selected, ensure label still shows above it
                      yield Positioned(
                        left: left.clamp(0, displayW),
                        top: labelTop,
                        width: math.min(w.clamp(8, displayW), displayW - left),
                        height: labelHeight,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: boxColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                name.isEmpty ? 'Item' : name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              );
            },
          ),
        ),
        if (_isPhotoScanning && _selectedIndex == -1)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Container(color: _navy.withOpacity(0.18)),
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
                            borderRadius: BorderRadius.circular(18),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
        if (!_isPhotoScanning && _selectedIndex == -1)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: _navy, size: 16),
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
    );
  }

  Widget _buildScanningStatus() {
    return Container(
      key: const ValueKey('scanning-status'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: _navy, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Please wait while we prepare your photo for analysis...',
              style: TextStyle(
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _navy.withOpacity(0.07),
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
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _cardBorder),
          ),
          child: const Text(
            'Beta',
            style: TextStyle(
              color: _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
        color: const Color(0xFFF8FAFD),
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

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAnalysisResultSection(Map<String, dynamic> analysis) {
    // prefer cached detected items from analysis; fall back to raw analysis data
    final items = _detectedItems.isNotEmpty
        ? _detectedItems
        : (analysis['items'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList() ??
              <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detected',
                style: TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Add button moved to bottom of the panel per UX
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty) ...[
            Text(
              'No items detected.',
              style: TextStyle(color: _mutedText, fontWeight: FontWeight.w700),
            ),
          ] else ...[
            Column(
              children: items.take(8).toList().asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                final name =
                    (item['name'] ?? item['class'] ?? item['label'] ?? '')
                        .toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Detected item' : name,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // per-item buttons removed — use Add All above
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
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
            borderRadius: BorderRadius.circular(18),
          ),
          shadowColor: _navy.withOpacity(0.3),
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
          backgroundColor: const Color(0xFFF2F7FB),
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _cardBorder),
      boxShadow: [
        BoxShadow(
          color: _navy.withOpacity(0.07),
          blurRadius: 28,
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
