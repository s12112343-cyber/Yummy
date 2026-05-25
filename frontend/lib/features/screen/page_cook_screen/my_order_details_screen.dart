import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/meal_service.dart';
import '../../../../core/theme/app_colors.dart';

class MyOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const MyOrderDetailsScreen({super.key, required this.order});

  @override
  State<MyOrderDetailsScreen> createState() => _MyOrderDetailsScreenState();
}

class _MyOrderDetailsScreenState extends State<MyOrderDetailsScreen> {
  String? _mealHistoryMessage;
  bool _mealHistoryAdded = false;

  String get _orderMealHistoryKey {
    final orderId = widget.order['_id']?.toString() ?? '';
    return 'meal_history_added_order_$orderId';
  }

  @override
  void initState() {
    super.initState();
    _loadMealHistoryState();
  }

  Future<void> _loadMealHistoryState() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAdded = prefs.getBool(_orderMealHistoryKey) ?? false;
    if (!mounted) return;
    setState(() {
      _mealHistoryAdded = alreadyAdded;
      if (alreadyAdded) {
        _mealHistoryMessage = 'Added to Meal History';
      }
    });
  }

  Future<void> _markMealHistoryAdded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orderMealHistoryKey, true);
  }

  String _stringValue(String key, {String fallback = 'N/A'}) {
    final value = widget.order[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _doubleValue(String key, {double fallback = 0}) {
    final value = widget.order[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<Map<String, dynamic>> _loadRecipeFallback() async {
    final recipeId = widget.order['recipeId']?.toString() ?? '';
    if (recipeId.isEmpty) return {};

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/$recipeId'),
      );
      if (response.statusCode != 200) return {};
      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    } catch (_) {
      return {};
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(value).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return 'N/A';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.royalBlue;
    }
  }

  Color _statusBgColor(String status) {
    return _statusColor(status).withValues(alpha: 0.12);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _chefName() {
    final chef = widget.order['chefId'];
    if (chef is Map<String, dynamic>) {
      return (chef['businessName'] ?? chef['name'] ?? 'Chef').toString();
    }
    return 'Chef';
  }

  bool get _canCancel =>
      _stringValue('status', fallback: 'pending').toLowerCase() == 'pending';

  Future<void> _cancelOrder(BuildContext context) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/orders/${widget.order['_id']}/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        return;
      }
    } catch (_) {
      return;
    }
  }

  Future<String?> _pickMealType(BuildContext context) async {
    String selected = 'lunch';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final items = <Map<String, Object>>[
              {'type': 'breakfast', 'icon': Icons.free_breakfast_rounded},
              {'type': 'lunch', 'icon': Icons.lunch_dining_rounded},
              {'type': 'dinner', 'icon': Icons.dinner_dining_rounded},
              {'type': 'snack', 'icon': Icons.cookie_rounded},
            ];

            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: 20 + MediaQuery.of(dialogContext).padding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7DDE8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Choose meal type',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select where this order should be saved in Meal History.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 2.7,
                            ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final type = item['type'] as String;
                          final icon = item['icon'] as IconData;
                          final isSelected = selected == type;

                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setLocalState(() => selected = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.royalBlue.withValues(
                                        alpha: 0.10,
                                      )
                                    : const Color(0xFFF7F9FC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.royalBlue
                                      : const Color(0xFFE6EBF3),
                                  width: isSelected ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.royalBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.royalBlue
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 10,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 20,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.deepBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      type[0].toUpperCase() + type.substring(1),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? AppColors.deepBlue
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: AppColors.royalBlue,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(null),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.deepBlue,
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(selected),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.royalBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addToMealHistory(
    BuildContext context,
    double calories,
    double fat,
    double protein,
    double carbs,
    int quantity,
  ) async {
    try {
      if (_mealHistoryAdded) return;

      if (mounted) {
        setState(() {
          _mealHistoryMessage = null;
        });
      }

      final mealType = await _pickMealType(context);
      if (mealType == null) return;

      final mealService = MealService();
      final servings = quantity <= 0 ? 1 : quantity;
      await mealService.addMealsBatch(
        mealType: mealType,
        date: DateTime.now(),
        bypassRestrictions: true,
        meals: [
          {
            'mealName': _stringValue('dishName', fallback: 'Order'),
            'calories': (calories * servings).round(),
            'fat': fat * servings,
            'protein': protein * servings,
            'carbs': carbs * servings,
            'grams': servings,
          },
        ],
      );

      if (!context.mounted) return;

      setState(() {
        _mealHistoryMessage = 'Added to Meal History';
        _mealHistoryAdded = true;
      });

      await _markMealHistoryAdded();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to Meal History: $e')),
      );
    }
  }

  String _shortOrderId() {
    final id = _stringValue('_id', fallback: '');
    if (id.isEmpty) return 'N/A';
    return '#${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _statusBgColor(status),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0F7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.royalBlue, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _priceRow({
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.deepBlue : Colors.grey.shade600,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: isTotal ? 22 : 15,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _stringValue('status', fallback: 'pending');
    final dishName = _stringValue('dishName', fallback: 'Order');
    final dishImage = _stringValue('dishImage', fallback: '');
    final quantity = widget.order['quantity'] ?? 1;
    final price = _doubleValue('price');
    final totalPrice = _doubleValue('totalPrice', fallback: price * quantity);

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadRecipeFallback(),
      builder: (context, snapshot) {
        final recipe = snapshot.data ?? {};

        double nutritionValue(String key, {List<String> fallbacks = const []}) {
          final current = _doubleValue(key);
          if (current != 0) return current;

          for (final fallbackKey in fallbacks) {
            final value = recipe[fallbackKey];
            if (value is num && value.toDouble() != 0) {
              return value.toDouble();
            }
            final parsed = double.tryParse(value?.toString() ?? '');
            if (parsed != null && parsed != 0) return parsed;
          }

          return current;
        }

        final calories = nutritionValue(
          'calories',
          fallbacks: ['calories', 'cal'],
        );
        final fat = nutritionValue('fat');
        final protein = nutritionValue('protein');
        final carbs = nutritionValue(
          'carbs',
          fallbacks: ['carbs', 'carbohydrates', 'potassium'],
        );
        final size = _stringValue('size', fallback: '');

        final addressParts = [
          _stringValue('city', fallback: ''),
          _stringValue('street', fallback: ''),
        ].where((part) => part.trim().isNotEmpty).join(', ');

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            title: const Text(
              'Order Details',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFFF5F7FB),
            foregroundColor: AppColors.deepBlue,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.deepBlue,
                        AppColors.navy,
                        AppColors.royalBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.28),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag:
                                'order_image_${widget.order['_id'] ?? dishName}',
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: dishImage.isNotEmpty
                                    ? Image.network(
                                        dishImage,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.restaurant_rounded,
                                                  color: Colors.white,
                                                  size: 34,
                                                ),
                                      )
                                    : const Icon(
                                        Icons.restaurant_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _statusChip(status),
                                const SizedBox(height: 12),
                                Text(
                                  dishName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    height: 1.08,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _chefName(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.86,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order ID',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _shortOrderId(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quantity',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$quantity item',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_canCancel) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelOrder(context),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: const Text(
                        'Cancel Order',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        backgroundColor: Colors.red.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],

                if (status.toLowerCase() == 'completed') ...[
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_mealHistoryMessage != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _mealHistoryMessage!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _mealHistoryAdded
                              ? null
                              : () => _addToMealHistory(
                                  context,
                                  calories,
                                  fat,
                                  protein,
                                  carbs,
                                  quantity is num
                                      ? quantity.toInt()
                                      : int.tryParse(quantity.toString()) ?? 1,
                                ),
                          icon: const Icon(Icons.restaurant_menu_rounded),
                          label: Text(
                            _mealHistoryAdded
                                ? 'Added to Meal History'
                                : 'Add to Meal History',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mealHistoryAdded
                                ? Colors.green
                                : AppColors.royalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                _sectionTitle('Order Information'),
                _whiteCard(
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Placed At',
                        value: _formatDate(
                          widget.order['createdAt']?.toString(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (size.isNotEmpty) ...[
                        _infoTile(
                          icon: Icons.straighten_outlined,
                          label: 'Size',
                          value: size,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _infoTile(
                        icon: Icons.payments_outlined,
                        label: 'Payment Method',
                        value: _stringValue('paymentMethod', fallback: 'cash'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _sectionTitle('Nutrition Facts'),
                _whiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _nutritionCard(
                            label: 'Calories',
                            value: calories.toStringAsFixed(0),
                            unit: 'cal',
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.caloriesPurple,
                            bg: AppColors.caloriesBg,
                          ),
                          const SizedBox(width: 10),
                          _nutritionCard(
                            label: 'Protein',
                            value: protein.toStringAsFixed(1),
                            unit: 'g',
                            icon: Icons.fitness_center_rounded,
                            color: AppColors.proteinBlue,
                            bg: AppColors.proteinBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _nutritionCard(
                            label: 'Carbs',
                            value: carbs.toStringAsFixed(1),
                            unit: 'g',
                            icon: Icons.grain_rounded,
                            color: AppColors.carbsGreen,
                            bg: AppColors.carbsBg,
                          ),
                          const SizedBox(width: 10),
                          _nutritionCard(
                            label: 'Fat',
                            value: fat.toStringAsFixed(1),
                            unit: 'g',
                            icon: Icons.opacity_rounded,
                            color: AppColors.fatOrange,
                            bg: AppColors.fatBg,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _sectionTitle('Delivery Details'),
                _whiteCard(
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Delivery Address',
                        value: addressParts.trim().isEmpty
                            ? 'N/A'
                            : addressParts,
                      ),
                      const SizedBox(height: 12),
                      _infoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: _stringValue('phone', fallback: 'N/A'),
                      ),
                      const SizedBox(height: 12),
                      _infoTile(
                        icon: Icons.notes_outlined,
                        label: 'Special Instructions',
                        value: _stringValue(
                          'specialInstructions',
                          fallback: 'None',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _sectionTitle('Payment Summary'),
                _whiteCard(
                  child: Column(
                    children: [
                      _priceRow(
                        label: 'Price',
                        value: '\$${price.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _priceRow(label: 'Quantity', value: 'x$quantity'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: Color(0xFFE8EEF7)),
                      ),
                      _priceRow(
                        label: 'Total',
                        value: '\$${totalPrice.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
