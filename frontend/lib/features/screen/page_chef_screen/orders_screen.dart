import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/chef_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/config/app_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 COLOR PALETTE - Premium Food App Theme
// ═══════════════════════════════════════════════════════════════════════════
class AppColors {
  static const primaryDark = Color(0xFF001F3F);
  static const primary = Color(0xFF005EB2);
  static const primaryLight = Color(0xFF3B82F6);
  static const accent = Color(0xFF10B981);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentRed = Color(0xFFEF4444);
  static const background = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

// ═══════════════════════════════════════════════════════════════════════════
// 📊 DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════
enum OrderStatus { pending, preparing, completed, cancelled }

class OrderItem {
  final String id;
  final String dishName;
  final String dishImage;
  final String customerName;
  final String customerAvatar;
  final double price;
  final int quantity;
  final DateTime orderTime;
  OrderStatus status;
  final String? phone;
  final String? city;
  final String? street;
  final String? paymentMethod;
  final double totalPrice;
  final String? specialInstructions;

  OrderItem({
    required this.id,
    required this.dishName,
    required this.dishImage,
    required this.customerName,
    required this.customerAvatar,
    required this.price,
    required this.quantity,
    required this.orderTime,
    required this.status,
    this.phone,
    this.city,
    this.street,
    this.paymentMethod,
    required this.totalPrice,
    this.specialInstructions,
  });
  static OrderStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;

      case 'preparing':
        return OrderStatus.preparing;

      case 'completed':
        return OrderStatus.completed;

      case 'cancelled':
        return OrderStatus.cancelled;

      default:
        return OrderStatus.pending;
    }
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['_id'] ?? '',

      dishName: json['dishName'] ?? '',

      dishImage: json['dishImage'] ?? '',

      customerName: json['customerName'] ?? 'Unknown',

      customerAvatar: json['customerAvatar'] ?? '',

      quantity: json['quantity'] ?? 1,

      price: (json['price'] ?? 0).toDouble(),

      totalPrice: (json['totalPrice'] ?? 0).toDouble(),

      phone: json['phone']?.toString(),

      city: json['city']?.toString(),

      street: json['street']?.toString(),

      paymentMethod: json['paymentMethod']?.toString(),

      specialInstructions: json['specialInstructions'] ?? '',

      orderTime: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),

      status: _parseStatus(json['status'] ?? 'pending'),
    );
  }
  String get timeAgo {
    final difference = DateTime.now().difference(orderTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🏠 MAIN ORDERS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ChefOrdersScreen extends StatefulWidget {
  const ChefOrdersScreen({super.key});

  @override
  State<ChefOrdersScreen> createState() => _ChefOrdersScreenState();
}

class _ChefOrdersScreenState extends State<ChefOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  OrderStatus _selectedFilter = OrderStatus.pending;
  List<OrderItem> _allOrders = [];
  bool _socketConnected = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    loadOrders();

    setupSocket();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedFilter = OrderStatus.pending;
              break;

            case 1:
              _selectedFilter = OrderStatus.pending;
              break;

            case 2:
              _selectedFilter = OrderStatus.preparing;
              break;

            case 3:
              _selectedFilter = OrderStatus.completed;
              break;
          }
        });
      }
    });
  }

  Future<void> loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final chefId = prefs.getString("chefId");
      print("CHEF ID => $chefId");
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/chef/$chefId'),
      );
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List orders = data['orders'];

        setState(() {
          _allOrders = orders.map((e) => OrderItem.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print("LOAD ORDERS ERROR => $e");
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/status'),

        headers: {
          'Content-Type': 'application/json',

          'Authorization': 'Bearer $token',
        },

        body: jsonEncode({"status": status}),
      );

      print("UPDATE STATUS => ${response.body}");
    } catch (e) {
      print("UPDATE ERROR => $e");
    }
  }

  Future<void> setupSocket() async {
    final prefs = await SharedPreferences.getInstance();

    final chefId = prefs.getString("chefId") ?? "";

    print("JOIN ROOM => $chefId");

    ChefSocketService.connect(chefId);

    Future.delayed(const Duration(seconds: 1), () {
      ChefSocketService.socket.emit("joinChefRoom", chefId);

      print("ROOM JOINED");

      _socketConnected = true;
    });

    listenForOrders();
  }

  void showNewOrderNotification(OrderItem order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,

        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white),

            SizedBox(width: 10),

            Expanded(child: Text("🔥 New order from ${order.customerName}")),
          ],
        ),
      ),
    );
  }

  void listenForOrders() {
    ChefSocketService.socket.on("newOrder", (data) {
      final newOrder = OrderItem.fromJson(data);

      setState(() {
        _allOrders.insert(0, newOrder);
      });

      showNewOrderNotification(newOrder);
    });
  }

  @override
  void dispose() {
    ChefSocketService.socket.dispose();

    _tabController.dispose();

    super.dispose();
  }

  List<OrderItem> get _filteredOrders {
    if (_tabController.index == 0) return _allOrders;
    return _allOrders
        .where((order) => order.status == _selectedFilter)
        .toList();
  }

  int _getOrderCount(OrderStatus status) {
    return _allOrders.where((order) => order.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildModernTabs(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingShimmer()
                    : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔝 APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Manage your incoming orders',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 MODERN TABS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildModernTabs() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        isScrollable: true,
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('All'),
                const SizedBox(width: 6),
                _buildBadge(_allOrders.length),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending'),
                const SizedBox(width: 6),
                _buildBadge(_getOrderCount(OrderStatus.pending)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Preparing'),
                const SizedBox(width: 6),
                _buildBadge(_getOrderCount(OrderStatus.preparing)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Done'),
                const SizedBox(width: 6),
                _buildBadge(_getOrderCount(OrderStatus.completed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            _tabController.index == 0 ||
                (_tabController.index == 1 &&
                    count == _getOrderCount(OrderStatus.pending)) ||
                (_tabController.index == 2 &&
                    count == _getOrderCount(OrderStatus.preparing)) ||
                (_tabController.index == 3 &&
                    count == _getOrderCount(OrderStatus.completed))
            ? Colors.white.withOpacity(0.3)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color:
              _tabController.index == 0 ||
                  (_tabController.index == 1 &&
                      count == _getOrderCount(OrderStatus.pending)) ||
                  (_tabController.index == 2 &&
                      count == _getOrderCount(OrderStatus.preparing)) ||
                  (_tabController.index == 3 &&
                      count == _getOrderCount(OrderStatus.completed))
              ? Colors.white
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 ORDERS LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersList() {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _filteredOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: OrderCard(
            order: _filteredOrders[index],
            onAccept: () => _handleAcceptOrder(_filteredOrders[index]),
            onReject: () => _handleRejectOrder(_filteredOrders[index]),
            onMarkReady: () => _handleMarkReady(_filteredOrders[index]),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📭 EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    String message;
    String emoji;
    switch (_tabController.index) {
      case 1:
        message = 'No pending orders at the moment';
        emoji = '⏳';
        break;
      case 2:
        message = 'No orders being prepared';
        emoji = '👨‍🍳';
        break;
      case 3:
        message = 'No completed orders yet';
        emoji = '✅';
        break;
      default:
        message = 'No orders yet';
        emoji = '📦';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 56)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New orders will appear here',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏳ LOADING SHIMMER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => const ShimmerOrderCard(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _handleAcceptOrder(OrderItem order) async {
    HapticFeedback.mediumImpact();

    await updateOrderStatus(order.id, "preparing");

    setState(() {
      _allOrders.firstWhere((o) => o.id == order.id).status =
          OrderStatus.preparing;
    });

    _showSnackBar('Order ${order.id} accepted ✅', AppColors.success);
  }

  Future<void> _handleRejectOrder(OrderItem order) async {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Order?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to reject order ${order.id}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _allOrders.removeWhere((o) => o.id == order.id);
              });
              _showSnackBar('Order ${order.id} rejected', AppColors.error);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkReady(OrderItem order) async {
    HapticFeedback.mediumImpact();

    await updateOrderStatus(order.id, "completed");

    await loadOrders();

    setState(() {
      _allOrders.firstWhere((o) => o.id == order.id).status =
          OrderStatus.completed;
    });

    _showSnackBar('Order ${order.id} marked as ready 🎉', AppColors.success);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.success
                  ? Icons.check_circle_rounded
                  : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎴 ORDER CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class OrderCard extends StatelessWidget {
  final OrderItem order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onMarkReady;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onMarkReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // Customer Avatar
                Container(
                  width: 48,
                  height: 48,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    border: Border.all(
                      color: _getStatusColor(order.status).withOpacity(0.3),
                      width: 2,
                    ),
                  ),

                  child: ClipOval(
                    child: order.customerAvatar.isNotEmpty
                        ? Image.network(
                            order.customerAvatar,

                            fit: BoxFit.cover,

                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: AppColors.primary.withOpacity(0.1),

                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: AppColors.primary.withOpacity(0.1),

                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.timeAgo,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Order ID & Status
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "#${order.id.substring(0, 6)}",

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: StatusChip(status: order.status),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),

                        child: Image.network(
                          order.dishImage,

                          fit: BoxFit.cover,

                          width: double.infinity,
                          height: double.infinity,

                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.background,

                            child: const Icon(
                              Icons.fastfood,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dish Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.dishName,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.shopping_cart_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Qty: ${order.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Price
                    FittedBox(
                      child: Text(
                        '\$${(order.price * order.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                // Special Instructions
                if (order.specialInstructions != null &&
                    order.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          color: Colors.orange,
                          size: 18,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            order.specialInstructions!,

                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 🔥 CUSTOMER INFO CARD
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: AppColors.background,

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(color: AppColors.border),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 18,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              order.customerName,

                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _infoRow(Icons.phone, "Phone", order.phone ?? 'No phone'),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.location_city,
                        "City",
                        order.city ?? 'No city',
                      ),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.home,
                        "Street",
                        order.street ?? 'No street',
                      ),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.payment,
                        "Payment",
                        order.paymentMethod ?? 'Cash',
                      ),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.shopping_bag,
                        "Quantity",
                        order.quantity.toString(),
                      ),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.attach_money,
                        "Price",
                        "\$${order.price.toStringAsFixed(2)}",
                      ),

                      const SizedBox(height: 10),

                      _infoRow(
                        Icons.calculate,
                        "Total",
                        "\$${(order.price * order.quantity).toStringAsFixed(2)}",
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                const SizedBox(height: 16),

                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (order.status) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Reject',
                icon: Icons.close_rounded,
                color: AppColors.error,
                onTap: onReject,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildActionButton(
                label: 'Accept Order',
                icon: Icons.check_rounded,
                color: AppColors.success,
                onTap: onAccept,
                isPrimary: true,
              ),
            ),
          ],
        );

      case OrderStatus.preparing:
        return _buildActionButton(
          label: 'Mark as Ready',
          icon: Icons.done_all_rounded,
          color: AppColors.primary,
          onTap: onMarkReady,
          isPrimary: true,
        );

      case OrderStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Order Completed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary ? color : color.withOpacity(0.3),
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),

        const SizedBox(width: 10),

        Text(
          "$title:",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🏷️ STATUS CHIP WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class StatusChip extends StatelessWidget {
  final OrderStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case OrderStatus.pending:
        color = AppColors.warning;
        label = 'Pending';
        icon = Icons.schedule_rounded;
        break;
      case OrderStatus.preparing:
        color = AppColors.info;
        label = 'Preparing';
        icon = Icons.restaurant_rounded;
        break;
      case OrderStatus.completed:
        color = AppColors.success;
        label = 'Completed';
        icon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        label = 'Cancelled';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✨ SHIMMER LOADING CARD
// ═══════════════════════════════════════════════════════════════════════════
class ShimmerOrderCard extends StatefulWidget {
  const ShimmerOrderCard({super.key});

  @override
  State<ShimmerOrderCard> createState() => _ShimmerOrderCardState();
}

class _ShimmerOrderCardState extends State<ShimmerOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildShimmerBox(48, 48, circular: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShimmerBox(100, 16),
                          const SizedBox(height: 8),
                          _buildShimmerBox(60, 12),
                        ],
                      ),
                    ),
                    _buildShimmerBox(80, 24),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildShimmerBox(64, 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShimmerBox(double.infinity, 16),
                          const SizedBox(height: 8),
                          _buildShimmerBox(80, 12),
                        ],
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

  Widget _buildShimmerBox(
    double width,
    double height, {
    bool circular = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.border,
            AppColors.border.withOpacity(0.5),
            AppColors.border,
          ],
          stops: [
            _controller.value - 0.3,
            _controller.value,
            _controller.value + 0.3,
          ],
        ),
        borderRadius: circular
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(8),
      ),
    );
  }
}
