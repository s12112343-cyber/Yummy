import 'dart:async';
import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import 'food_search_panel.dart';

class BarcodeScanPanel extends StatefulWidget {
  final ValueChanged<AddedNutrients> onNutrientsAdded;

  const BarcodeScanPanel({super.key, required this.onNutrientsAdded});

  @override
  State<BarcodeScanPanel> createState() => _BarcodeScanPanelState();
}

class _BarcodeScanPanelState extends State<BarcodeScanPanel> {
  static const Duration _analysisDelay = Duration(milliseconds: 1200);
  static const Duration _barcodeHoldDelay = Duration(milliseconds: 1800);

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    torchEnabled: false,
  );

  final _OpenFoodFactsService _service = _OpenFoodFactsService();
  final TextEditingController _gramsController = TextEditingController(
    text: '100',
  );

  bool _isLoading = false;
  bool _isScanning = true;
  bool _hasAskedPermissionDialog = false;

  String? _errorText;
  String? _barcode;
  String _statusText = 'Point the camera at a barcode';
  _OpenFoodFactsProduct? _product;

  Timer? _barcodeHoldTimer;
  String? _pendingBarcode;
  String _pendingStatusText = '';

  @override
  void initState() {
    super.initState();
    _gramsController.addListener(_onGramsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  void dispose() {
    _barcodeHoldTimer?.cancel();
    _gramsController.removeListener(_onGramsChanged);
    _gramsController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onGramsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _startCamera() async {
    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) return;

    try {
      await _scannerController.start();
      if (!mounted) return;

      setState(() {
        _errorText = null;
        _statusText = 'Point the camera at a barcode';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to open camera preview. Please try again.';
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    try {
      var status = await Permission.camera.status;

      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _errorText = null;
          });
        }
        return true;
      }

      if (!_hasAskedPermissionDialog) {
        if (!mounted) return false;
        _hasAskedPermissionDialog = true;

        final allow = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Camera permission'),
              content: const Text(
                'To scan barcodes, allow access to your camera.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );

        if (allow != true) {
          if (mounted) {
            setState(() {
              _errorText =
                  'Camera permission was not granted. You can enable it anytime.';
            });
          }
          return false;
        }
      }

      status = await Permission.camera.request();

      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _errorText = null;
            _statusText = 'Camera permission granted';
          });
        }
        return true;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        if (!mounted) return false;

        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Permission required'),
              content: const Text(
                'Camera access is blocked. Open app settings and allow camera permission.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await openAppSettings();
                  },
                  child: const Text('Open settings'),
                ),
              ],
            );
          },
        );
      } else if (mounted) {
        setState(() {
          _errorText =
              'Camera permission denied. Please allow it to scan barcodes.';
        });
      }

      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _errorText =
            'Failed to request camera permission. Please restart the app and try again.';
      });
      return false;
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isLoading || !_isScanning || _product != null) return;

    final rawCode = capture.barcodes
        .map((item) => item.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (rawCode.isEmpty) return;

    final normalizedCode = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedCode.length < 8) return;

    if (_pendingBarcode == normalizedCode &&
        _barcodeHoldTimer?.isActive == true) {
      return;
    }

    _barcodeHoldTimer?.cancel();
    _pendingBarcode = normalizedCode;

    setState(() {
      _errorText = null;
      _pendingStatusText = 'Hold steady... reading barcode';
      _statusText = 'Hold the barcode steady for a moment';
    });

    _barcodeHoldTimer = Timer(_barcodeHoldDelay, () async {
      if (!mounted) return;
      if (_pendingBarcode != normalizedCode) return;

      await _confirmAndAnalyzeBarcode(normalizedCode);
    });
  }

  Future<void> _confirmAndAnalyzeBarcode(String code) async {
    if (_isLoading || !_isScanning || _product != null) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _barcode = code;
      _statusText = 'Analyzing barcode...';
      _pendingStatusText = '';
    });

    await _scannerController.stop();

    await Future.delayed(_analysisDelay);
    if (!mounted) return;

    try {
      final product = await _service.fetchByBarcode(code);
      if (!mounted) return;

      setState(() {
        _product = product;
        _isScanning = false;
        _statusText = 'Analysis complete';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _product = null;
        _errorText = error.toString().replaceFirst('Exception: ', '');
        _isScanning = false;
        _statusText = 'Analysis failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanAgain() async {
    _barcodeHoldTimer?.cancel();

    setState(() {
      _errorText = null;
      _barcode = null;
      _product = null;
      _pendingBarcode = null;
      _pendingStatusText = '';
      _isScanning = true;
      _isLoading = false;
      _statusText = 'Point the camera at a barcode';
      _gramsController.text = '100';
    });

    await _startCamera();
  }

  double _servingGrams() {
    final parsed = double.tryParse(_gramsController.text.trim());
    if (parsed == null || parsed <= 0) return 100;
    return parsed.clamp(1, 3000).toDouble();
  }

  double _scaledValue(double per100g, double grams) {
    return per100g * (grams / 100);
  }

  void _addToMeal() {
    final product = _product;
    if (product == null) return;

    final grams = _servingGrams();

    widget.onNutrientsAdded(
      AddedNutrients(
        calories: _scaledValue(product.caloriesPer100g, grams),
        protein: _scaledValue(product.proteinPer100g, grams),
        carbs: _scaledValue(product.carbsPer100g, grams),
        fat: _scaledValue(product.fatPer100g, grams),
        foodName: product.displayName,
        gramsAdded: grams,
        ingredients: product.ingredients,
        possibleAllergens: product.possibleAllergens,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.displayName} added to meal'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _scanAgain();
  }

  Widget _macroChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$title $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bw.Barcode _barcodeTypeFor(String code) {
    final clean = code.replaceAll(RegExp(r'[^0-9]'), '');

    if (clean.length == 13) {
      return bw.Barcode.ean13();
    }

    if (clean.length == 8) {
      return bw.Barcode.ean8();
    }

    return bw.Barcode.code128();
  }

  Widget _barcodePreviewCard(String code) {
    final clean = code.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightBlue.withOpacity(0.45)),
            ),
            child: bw.BarcodeWidget(
              barcode: _barcodeTypeFor(clean),
              data: clean,
              drawText: false,
              height: 82,
              color: AppColors.navy,
              backgroundColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            clean,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withOpacity(0.82),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final grams = _servingGrams();

    final liveCalories = product == null
        ? 0.0
        : _scaledValue(product.caloriesPer100g, grams);
    final liveProtein = product == null
        ? 0.0
        : _scaledValue(product.proteinPer100g, grams);
    final liveCarbs = product == null
        ? 0.0
        : _scaledValue(product.carbsPer100g, grams);
    final liveFat = product == null
        ? 0.0
        : _scaledValue(product.fatPer100g, grams);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Barcode Scanner',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText,
            style: TextStyle(
              color: AppColors.navy.withOpacity(0.75),
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
          if (_pendingStatusText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _pendingStatusText,
              style: TextStyle(
                color: AppColors.mediumBlue.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],

          if (_isScanning || _isLoading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isScanning)
                      MobileScanner(
                        fit: BoxFit.cover,
                        controller: _scannerController,
                        onDetect: _handleDetect,
                        errorBuilder: (context, error, child) {
                          return Container(
                            color: const Color(0xFF111827),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Camera preview failed. Check camera permission.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.28),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Analyzing barcode...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hold steady while we read the product.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (_isScanning && !_isLoading) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Open camera'),
            ),
          ],

          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3CEC8)),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: Color(0xFFB33C2E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _scanAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Scan again'),
              ),
            ),
          ],

          if (product != null) ...[
            const SizedBox(height: 14),
            _barcodePreviewCard(_barcode ?? product.barcode),
            const SizedBox(height: 12),
            Text(
              product.displayName,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (product.brand != null && product.brand!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  product.brand!,
                  style: TextStyle(
                    color: AppColors.navy.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _macroChip(
                  'Calories',
                  liveCalories.toStringAsFixed(0),
                  AppColors.caloriesPurple,
                ),
                _macroChip(
                  'Protein',
                  '${liveProtein.toStringAsFixed(1)}g',
                  AppColors.proteinBlue,
                ),
                _macroChip(
                  'Carbs',
                  '${liveCarbs.toStringAsFixed(1)}g',
                  AppColors.carbsGreen,
                ),
                _macroChip(
                  'Fat',
                  '${liveFat.toStringAsFixed(1)}g',
                  AppColors.fatOrange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Calculated for ${grams.toStringAsFixed(0)} g',
              style: TextStyle(
                color: AppColors.navy.withOpacity(0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gramsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Serving grams',
                hintText: '100',
                fillColor: AppColors.babyBlueLight,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.lightBlue.withOpacity(0.65),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _macroChip(
                  'Cal/100g',
                  product.caloriesPer100g.toStringAsFixed(0),
                  AppColors.caloriesPurple.withOpacity(0.85),
                ),
                _macroChip(
                  'P/100g',
                  '${product.proteinPer100g.toStringAsFixed(1)}g',
                  AppColors.proteinBlue.withOpacity(0.85),
                ),
                _macroChip(
                  'C/100g',
                  '${product.carbsPer100g.toStringAsFixed(1)}g',
                  AppColors.carbsGreen.withOpacity(0.85),
                ),
                _macroChip(
                  'F/100g',
                  '${product.fatPer100g.toStringAsFixed(1)}g',
                  AppColors.fatOrange.withOpacity(0.85),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan another'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addToMeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mediumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add to meal'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenFoodFactsService {
  static const _host = 'world.openfoodfacts.org';

  List<String> _splitIngredients(String raw) {
    return raw
        .split(RegExp(r'[;,]|\b(?:and|or)\b'))
        .map((value) => value.trim())
        .map((value) => value.replaceAll(RegExp(r'^[a-z]{2}:'), ''))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<_OpenFoodFactsProduct> fetchByBarcode(String barcode) async {
    final cleanCode = barcode.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleanCode.isEmpty) {
      throw Exception('Invalid barcode');
    }

    final candidates = <String>{
      cleanCode,
      if (cleanCode.length == 12) '0$cleanCode',
      if (cleanCode.length == 13 && cleanCode.startsWith('0'))
        cleanCode.substring(1),
    }.toList(growable: false);

    Map<String, dynamic>? lastErrorData;

    for (final candidate in candidates) {
      final uri = Uri.https(_host, '/api/v0/product/$candidate.json', {
        'fields':
            'code,product_name,brands,nutriments,quantity,serving_size,ingredients_text,allergens',
      });

      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'yummy-app/1.0 (contact: local-dev)'},
      );

      if (response.statusCode == 429) {
        throw Exception(
          'Open Food Facts rate limit reached. Please try again later.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastErrorData = {
          'statusCode': response.statusCode,
          'body': response.body,
          'candidate': candidate,
        };
        continue;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as int? ?? 0;

      if (status != 1) {
        lastErrorData = {
          'statusCode': response.statusCode,
          'body':
              data['status_verbose'] ?? data['message'] ?? 'Product not found',
          'candidate': candidate,
        };
        continue;
      }

      final product =
          (data['product'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final nutriments =
          (product['nutriments'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final calories = _firstNumeric(nutriments, const [
        'energy-kcal_100g',
        'energy-kcal',
      ]);

      final energyKj = _firstNumeric(nutriments, const [
        'energy-kj_100g',
        'energy-kj',
        'energy_100g',
        'energy',
      ]);

      final caloriesPer100g = calories > 0 ? calories : energyKj / 4.184;

      final proteinPer100g = _firstNumeric(nutriments, const [
        'proteins_100g',
        'proteins',
      ]);

      final carbsPer100g = _firstNumeric(nutriments, const [
        'carbohydrates_100g',
        'carbohydrates',
      ]);

      final fatPer100g = _firstNumeric(nutriments, const ['fat_100g', 'fat']);

      final displayName =
          (product['product_name'] ?? '').toString().trim().isNotEmpty
          ? (product['product_name'] ?? '').toString().trim()
          : 'Scanned food ($candidate)';

      return _OpenFoodFactsProduct(
        barcode: candidate,
        displayName: displayName,
        brand: (product['brands'] ?? '').toString().trim(),
        caloriesPer100g: caloriesPer100g,
        proteinPer100g: proteinPer100g,
        carbsPer100g: carbsPer100g,
        fatPer100g: fatPer100g,
        ingredients: _splitIngredients(
          (product['ingredients_text'] ?? '').toString(),
        ),
        possibleAllergens: _splitIngredients(
          (product['allergens'] ?? '').toString(),
        ),
      );
    }

    final details = lastErrorData == null
        ? 'Product not found for this barcode'
        : 'Product not found for this barcode (${lastErrorData['candidate']})';

    throw Exception(details);
  }

  double _firstNumeric(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw == null) continue;

      if (raw is num) {
        final value = raw.toDouble();
        if (value.isFinite && value >= 0) return value;
        continue;
      }

      final parsed = double.tryParse(raw.toString());
      if (parsed != null && parsed.isFinite && parsed >= 0) {
        return parsed;
      }
    }

    return 0;
  }
}

class _OpenFoodFactsProduct {
  final String barcode;
  final String displayName;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final List<String> ingredients;
  final List<String> possibleAllergens;

  const _OpenFoodFactsProduct({
    required this.barcode,
    required this.displayName,
    required this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.ingredients = const [],
    this.possibleAllergens = const [],
  });
}
