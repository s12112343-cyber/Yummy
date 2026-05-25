import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'my_order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _orders = [];

  int _selectedFilter = 0; // 0 All, 1 Active, 2 History

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/my'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> orders = decoded['orders'] ?? [];

        final enrichedOrders = await Future.wait(
          orders.map((order) async => await _enrichOrder(order)),
        );

        if (!mounted) return;
        setState(() {
          _orders = enrichedOrders;
          _loading = false;
        });
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _enrichOrder(dynamic rawOrder) async {
    final order = Map<String, dynamic>.from(rawOrder as Map);

    final needsNutritionBackfill =
        _readNum(order['calories']) == 0 &&
        _readNum(order['fat']) == 0 &&
        _readNum(order['protein']) == 0 &&
        _readNum(order['carbs']) == 0;

    if (!needsNutritionBackfill) return order;

    final recipeId = order['recipeId']?.toString() ?? '';
    if (recipeId.isEmpty) return order;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/$recipeId'),
      );

      if (response.statusCode != 200) return order;

      final decoded = jsonDecode(response.body);
      final recipe = decoded['data'];
      if (recipe is! Map) return order;

      final recipeMap = Map<String, dynamic>.from(recipe);

      order['calories'] = recipeMap['calories'] ?? order['calories'] ?? 0;
      order['fat'] = recipeMap['fat'] ?? order['fat'] ?? 0;
      order['protein'] = recipeMap['protein'] ?? order['protein'] ?? 0;
      order['carbs'] =
          recipeMap['carbs'] ??
          recipeMap['carbohydrates'] ??
          recipeMap['potassium'] ??
          order['carbs'] ??
          0;

      order['size'] = order['size'] ?? '';
    } catch (_) {
      return order;
    }

    return order;
  }

  bool _isActiveStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'pending' || normalized == 'preparing';
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

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'preparing':
        return Icons.restaurant_menu_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
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

  String _chefName(dynamic chef) {
    if (chef is Map<String, dynamic>) {
      return (chef['businessName'] ?? chef['name'] ?? 'Chef').toString();
    }
    return 'Chef';
  }

  double _readNum(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<dynamic> get _activeOrders {
    return _orders.where((order) {
      final status = order['status']?.toString() ?? 'pending';
      return _isActiveStatus(status);
    }).toList();
  }

  List<dynamic> get _previousOrders {
    return _orders.where((order) {
      final status = order['status']?.toString() ?? 'completed';
      return !_isActiveStatus(status);
    }).toList();
  }

  List<dynamic> get _filteredOrders {
    if (_selectedFilter == 1) return _activeOrders;
    if (_selectedFilter == 2) return _previousOrders;
    return _orders;
  }

  String get _filterTitle {
    if (_selectedFilter == 1) return 'Current Orders';
    if (_selectedFilter == 2) return 'Order History';
    return 'All Orders';
  }

  String get _filterSubtitle {
    if (_selectedFilter == 1) {
      return 'Orders that are still pending or being prepared';
    }
    if (_selectedFilter == 2) {
      return 'Completed and cancelled orders';
    }
    return 'All your current and previous orders';
  }

  String _addressText(Map<String, dynamic> order) {
    final city = order['city']?.toString() ?? '';
    final street = order['street']?.toString() ?? '';

    final address = [city, street]
        .where((part) => part.trim().isNotEmpty)
        .join(', ')
        .trim();

    return address.isEmpty ? 'No address' : address;
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            color: AppColors.navy.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
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
                      'My Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your meals and order status easily',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _loadOrders,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _summaryBox(
                label: 'Active',
                value: _activeOrders.length.toString(),
                icon: Icons.timelapse_rounded,
              ),
              const SizedBox(width: 10),
              _summaryBox(
                label: 'History',
                value: _previousOrders.length.toString(),
                icon: Icons.history_rounded,
              ),
              const SizedBox(width: 10),
              _summaryBox(
                label: 'Total',
                value: _orders.length.toString(),
                icon: Icons.shopping_bag_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.86), size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _filterButton(title: 'All', index: 0),
          _filterButton(title: 'Active', index: 1),
          _filterButton(title: 'History', index: 2),
        ],
      ),
    );
  }

  Widget _filterButton({required String title, required int index}) {
    final selected = _selectedFilter == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = index;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _filterTitle,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepBlue,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _filterSubtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${_filteredOrders.length} orders',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final chef = order['chefId'];
    final dishName = order['dishName']?.toString() ?? 'Order';
    final dishImage = order['dishImage']?.toString() ?? '';
    final totalPrice = _readNum(order['totalPrice']);
    final quantity = (order['quantity'] is num)
        ? (order['quantity'] as num).toInt()
        : int.tryParse(order['quantity']?.toString() ?? '') ?? 1;
    final size = order['size']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        shadowColor: AppColors.deepBlue.withOpacity(0.08),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () {
            Navigator.of(context)
                .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => MyOrderDetailsScreen(order: order),
                  ),
                )
                .then((cancelled) {
                  if (cancelled == true) {
                    _loadOrders();
                  }
                });
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE8EEF7)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withOpacity(0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'order_image_${order['_id'] ?? dishName}',
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FB),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE8EEF7)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: dishImage.isNotEmpty
                              ? Image.network(
                                  dishImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.restaurant_rounded,
                                    color: AppColors.royalBlue,
                                    size: 30,
                                  ),
                                )
                              : const Icon(
                                  Icons.restaurant_rounded,
                                  color: AppColors.royalBlue,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dishName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepBlue,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 15,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _chefName(chef),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _formatDate(order['createdAt']?.toString()),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _statusChip(status),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    _simpleChip(
                      icon: Icons.shopping_bag_outlined,
                      text: 'Qty $quantity',
                    ),
                    const SizedBox(width: 8),
                    if (size.trim().isNotEmpty)
                      _simpleChip(
                        icon: Icons.straighten_rounded,
                        text: size,
                      )
                    else
                      _simpleChip(
                        icon: Icons.payments_outlined,
                        text: (order['paymentMethod'] ?? 'cash').toString(),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _miniInfoChip(
                        icon: Icons.location_on_outlined,
                        label: _addressText(order),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.royalBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.royalBlue,
                        size: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _nutritionRow(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleChip({required IconData icon, required String text}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE8EEF7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.royalBlue),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text.trim().isEmpty ? 'N/A' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfoChip({required IconData icon, required String label}) {
    final text = label.trim().isEmpty ? 'N/A' : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.royalBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Row(
        children: [
          _orderNutriBadge(
            label: 'Cal',
            value: _readNum(order['calories'] ?? order['cal']).toStringAsFixed(0),
            color: AppColors.caloriesPurple,
            bgColor: AppColors.caloriesBg,
          ),
          const SizedBox(width: 8),
          _orderNutriBadge(
            label: 'Protein',
            value: _readNum(order['protein']).toStringAsFixed(1),
            color: AppColors.proteinBlue,
            bgColor: AppColors.proteinBg,
          ),
          const SizedBox(width: 8),
          _orderNutriBadge(
            label: 'Carbs',
            value: _readNum(
              order['carbs'] ?? order['carbohydrates'],
            ).toStringAsFixed(1),
            color: AppColors.carbsGreen,
            bgColor: AppColors.carbsBg,
          ),
          const SizedBox(width: 8),
          _orderNutriBadge(
            label: 'Fat',
            value: _readNum(order['fat']).toStringAsFixed(1),
            color: AppColors.fatOrange,
            bgColor: AppColors.fatBg,
          ),
        ],
      ),
    );
  }

  Widget _orderNutriBadge({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.10)),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.85),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _headerSkeleton(),
        const SizedBox(height: 18),
        _filterTabsSkeleton(),
        const SizedBox(height: 22),
        _cardSkeleton(),
        _cardSkeleton(),
        _cardSkeleton(),
      ],
    );
  }

  Widget _headerSkeleton() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.royalBlue),
      ),
    );
  }

  Widget _filterTabsSkeleton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
    );
  }

  Widget _cardSkeleton() {
    return Container(
      height: 210,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 80),
        Container(
          width: 86,
          height: 86,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.wifi_off_rounded,
            size: 42,
            color: Colors.red.shade400,
          ),
        ),
        const Text(
          'Failed to load orders',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    String title;
    String subtitle;
    IconData icon;

    if (_selectedFilter == 1) {
      title = 'No active orders';
      subtitle = 'Your live orders will appear here once you place an order.';
      icon = Icons.inventory_2_outlined;
    } else if (_selectedFilter == 2) {
      title = 'No order history';
      subtitle = 'Completed and cancelled orders will appear here.';
      icon = Icons.history_rounded;
    } else {
      title = 'No orders yet';
      subtitle = 'Start ordering your favorite meals and track them here.';
      icon = Icons.receipt_long_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8EEF7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.royalBlue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _headerCard(),
        const SizedBox(height: 18),
        _filterTabs(),
        const SizedBox(height: 24),
        _sectionHeader(),
        const SizedBox(height: 14),
        if (_filteredOrders.isEmpty)
          _emptyState()
        else
          ..._filteredOrders.map(
            (order) => _buildOrderCard(Map<String, dynamic>.from(order as Map)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'My Orders',
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
      body: RefreshIndicator(
        color: AppColors.royalBlue,
        onRefresh: _loadOrders,
        child: _loading
            ? _loadingState()
            : _error.isNotEmpty
                ? _errorState()
                : _ordersContent(),
      ),
    );
  }
}