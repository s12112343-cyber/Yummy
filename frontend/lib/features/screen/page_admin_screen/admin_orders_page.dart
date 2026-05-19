import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/chef_socket_service.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _orders = [];
  bool _loading = true;
  String _error = '';
  String _selectedTab = 'pending';
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadOrders();
    // 🔥 SOCKET: ensure socket is initialized then attach listener
    try {
      ChefSocketService.connect('admin');
      ChefSocketService.socket.on('orderStatusUpdated', (data) {
        print('ORDER STATUS UPDATED => $data');

        _loadOrders();
      });
    } catch (e) {
      print('Socket init/listen error => $e');
    }
    _loadReviewsCount();
  }

  @override
  void dispose() {
    // clean up socket listeners for admin
    try {
      ChefSocketService.socket.off('orderStatusUpdated');
      ChefSocketService.disconnect();
    } catch (_) {}

    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewsCount() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List reviews = [];

        if (decoded is List) {
          reviews = decoded;
        } else if (decoded['reviews'] != null) {
          reviews = decoded['reviews'];
        }

        if (mounted) {
          setState(() {
            _reviewsCount = reviews.length;
          });
        }
      }
    } catch (e) {
      print('REVIEWS ERROR => $e');
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders = data['orders'] ?? data['data'] ?? [];
          _loading = false;
        });
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final token = await AuthService().getToken();

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/status'),

        headers: {
          'Content-Type': 'application/json',

          'Authorization': 'Bearer $token',
        },

        body: jsonEncode({"status": status}),
      );

      print('UPDATE STATUS => ${response.body}');
    } catch (e) {
      print('STATUS ERROR => $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.royalBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<dynamic> get _filteredOrders {
    return _orders.where((order) {
      final status = order['status']?.toString().toLowerCase() ?? '';
      final chef = order['chefId'];
      final user = order['userId'];
      final chefName = (chef?['businessName'] ?? chef?['name'] ?? '')
          .toLowerCase();
      final userName = (user?['name'] ?? order['customerName'] ?? '')
          .toLowerCase();
      final orderId = order['_id'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch =
          chefName.contains(query) ||
          userName.contains(query) ||
          orderId.contains(query);

      return status == _selectedTab && matchesSearch;
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
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
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳ Pending';
      case 'preparing':
        return '🔧 Preparing';
      case 'completed':
        return '✅ Completed';
      case 'cancelled':
        return '❌ Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const SizedBox(height: 14),

          // SEARCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search customer, chef or order id',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          _buildTabs(),

          Expanded(
            child: _loading
                ? _buildLoadingShimmer()
                : _error.isNotEmpty
                ? _buildErrorWidget()
                : _filteredOrders.isEmpty
                ? _buildEmptyWidget()
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: _buildOrdersList(),
                  ),
          ),
        ],
      ),
    );
  }

  /// Fixed Tabs - Without overflow issues
  Widget _buildTabs() {
    final tabs = [
      {
        'key': 'pending',
        'label': 'Pending',
        'icon': Icons.pending_actions_rounded,
        'count': _orders
            .where((o) => o['status']?.toString().toLowerCase() == 'pending')
            .length,
      },
      {
        'key': 'preparing',
        'label': 'Preparing',
        'icon': Icons.kitchen_rounded,
        'count': _orders
            .where((o) => o['status']?.toString().toLowerCase() == 'preparing')
            .length,
      },
      {
        'key': 'completed',
        'label': 'Completed',
        'icon': Icons.check_circle_rounded,
        'count': _orders
            .where((o) => o['status']?.toString().toLowerCase() == 'completed')
            .length,
      },
      {
        'key': 'cancelled',
        'label': 'Cancelled',
        'icon': Icons.cancel_rounded,
        'count': _orders
            .where((o) => o['status']?.toString().toLowerCase() == 'cancelled')
            .length,
      },
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      height: 95,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == tab['key'];
          final count = tab['count'] as int;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = tab['key'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 105,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.royalBlue, AppColors.mediumBlue],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 22,
                      color: isSelected ? Colors.white : AppColors.royalBlue,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.deepBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(.2)
                            : AppColors.royalBlue.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppColors.royalBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(index * 0.05, 1.0, curve: Curves.easeOut),
                  ),
                ),
            child: _buildOrderCard(order),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final chef = order['chefId'];
    final user = order['userId'];
    final chefName = chef?['businessName'] ?? chef?['name'] ?? 'Unknown Chef';
    final userName = user?['name'] ?? order['customerName'] ?? 'Unknown User';
    final dishName = order['dishName'] ?? '';
    final quantity = order['quantity'] ?? 1;
    final singlePrice = (order['price'] ?? 0).toDouble();
    final totalPrice = (order['totalPrice'] ?? (singlePrice * quantity))
        .toDouble();
    final status = order['status'] ?? 'pending';
    final createdAt = order['createdAt'];

    return GestureDetector(
      onTap: () {
        _showOrderDetails(order);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TOP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '#ORD-${order['_id'].toString().substring(0, 6).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blueGray,
                ),
              ),

              /// USER
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.babyBlueLight,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.royalBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chef: $chefName',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              /// DISH INFO
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.restaurant, 'Meal', dishName),
                    const SizedBox(height: 10),
                    _infoRow(Icons.shopping_bag, 'Quantity', '$quantity'),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.attach_money,
                      'Price',
                      '\$${singlePrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.calculate,
                      'Total',
                      '\$${totalPrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.phone,
                      'Phone',
                      order['phone'] ?? 'No phone',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.location_city,
                      'City',
                      order['city'] ?? 'No city',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.home,
                      'Street',
                      order['street'] ?? 'No street',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.payment,
                      'Payment',
                      order['paymentMethod'] ?? 'Cash',
                    ),
                  ],
                ),
              ),

              if (order['specialInstructions'] != null &&
                  order['specialInstructions'].toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text(order['specialInstructions'])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              /// ACTIONS
              _buildStatusButtons(order['_id'], status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.royalBlue),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'preparing':
        return Icons.kitchen_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Widget _buildStatusButtons(String orderId, String currentStatus) {
    Color color;
    String text;
    IconData icon;

    switch (currentStatus.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        text = '⏳ Pending';
        icon = Icons.pending_actions_rounded;
        break;

      case 'preparing':
        color = Colors.blue;
        text = '👨‍🍳 Preparing';
        icon = Icons.kitchen_rounded;
        break;

      case 'completed':
      case 'delivered':
        color = Colors.green;
        text = '✅ Completed';
        icon = Icons.check_circle_rounded;
        break;

      case 'cancelled':
        color = Colors.red;
        text = '❌ Cancelled';
        icon = Icons.cancel_rounded;
        break;

      default:
        color = Colors.grey;
        text = currentStatus;
        icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(dynamic order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 48, color: AppColors.red),
          ),
          const SizedBox(height: 16),
          Text(
            _error,
            style: const TextStyle(color: AppColors.blueGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 48,
              color: AppColors.royalBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedTab orders',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.blueGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here once customers place them',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.blueGray.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order Details Bottom Sheet ─────────────────────────────────────────────
class _OrderDetailsSheet extends StatelessWidget {
  final dynamic order;

  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final quantity = order['quantity'] ?? 1;
    final price = (order['price'] ?? 0).toDouble();
    final total = (order['totalPrice'] ?? (price * quantity)).toDouble();
    final customerName = order['customerName'] ?? 'Unknown';
    final customerPhone = order['phone'] ?? 'No phone';
    final customerCity = order['city'] ?? 'No city';
    final customerStreet = order['street'] ?? 'No street';
    final paymentMethod = order['paymentMethod'] ?? 'Cash';
    final dishName = order['dishName'] ?? 'Meal';
    final createdAt = order['createdAt'];
    final status = order['status'] ?? 'pending';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '#ORD-${order['_id'].toString().substring(0, 6).toUpperCase()}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.blueGray,
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.babyBlueLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.person, 'Customer', customerName),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.phone, 'Phone', customerPhone),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.location_city, 'City', customerCity),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.home, 'Street', customerStreet),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.payment, 'Payment', paymentMethod),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.restaurant, 'Meal', dishName),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.shopping_bag, 'Quantity', '$quantity'),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    Icons.attach_money,
                    'Price',
                    '\$${price.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    Icons.calculate,
                    'Total',
                    '\$${total.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Date',
                    _formatDate(createdAt),
                  ),
                ],
              ),
            ),
            if (order['specialInstructions'] != null &&
                order['specialInstructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(child: Text(order['specialInstructions'])),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.royalBlue, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
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
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'N/A';
    }
  }
}
