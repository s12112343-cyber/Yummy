import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_recipe_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'notifications_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 PREMIUM COLOR PALETTE
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
}

// ═══════════════════════════════════════════════════════════════════════════
// 📊 DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════
class DashboardStats {
  final double earnings;
  final int ordersToday;
  final double rating;
  final int totalRecipes;

  DashboardStats({
    required this.earnings,
    required this.ordersToday,
    required this.rating,
    required this.totalRecipes,
  });
}

class Order {
  final String id;
  final String dishName;
  final String dishImage;
  final double totalPrice;
  final double price;
  final String status;
  final String customerName;
  final DateTime orderTime;

  Order({
    required this.id,
    required this.dishName,
    required this.dishImage,
    required this.totalPrice,
    this.price = 0,
    required this.status,
    required this.customerName,
    required this.orderTime,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    final total = toDouble(
      json['totalPrice'] ??
          json['totalAmount'] ??
          json['total'] ??
          json['amount'] ??
          json['price'],
    );

    print(
      'ORDER PRICE DEBUG => ${json['_id']} | status=${json['status']} | total=$total',
    );

    return Order(
      id: json['_id']?.toString() ?? '',
      dishName: json['dishName']?.toString() ?? 'Dish',
      dishImage: json['dishImage']?.toString() ?? '',
      totalPrice: total,
      price: toDouble(json['price']),
      status: json['status']?.toString().toLowerCase().trim() ?? 'pending',
      customerName: json['customerName']?.toString() ?? 'Customer',
      orderTime:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String image;
  final double rating;
  final int orders;

  Recipe({
    required this.id,
    required this.name,
    required this.image,
    required this.rating,
    required this.orders,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// 🏠 FUTURISTIC PREMIUM CHEF DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class ChefDashboardScreen extends StatefulWidget {
  const ChefDashboardScreen({super.key});

  @override
  State<ChefDashboardScreen> createState() => _ChefDashboardScreenState();
}

class _ChefDashboardScreenState extends State<ChefDashboardScreen>
    with TickerProviderStateMixin {
  // ✅ FIX: Initialize controllers directly (not 'late')
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _chartController;

  String chefName = '';
  String chefImage = '';
  double totalRevenue = 0;
  double rating = 4.8;
  int totalRecipes = 0;
  int ordersToday = 0;
  int totalOrders = 0;
  bool isLoading = true;

  List<Order> recentOrders = [];
  List<Order> allOrders = [];
  List<Recipe> popularRecipes = [];
  List<double> weeklyEarnings = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();

    // ✅ CRITICAL FIX: Initialize all controllers IMMEDIATELY in initState
    // This MUST happen before any setState or build
    _initializeControllers();

    // Load data AFTER controllers are ready
    _loadDashboard();
  }

  // ✅ NEW METHOD: Separate controller initialization
  void _initializeControllers() {
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );

      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
      _pulseController.repeat(reverse: true);

      _chartController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
    } catch (e) {
      print('Error initializing controllers: $e');
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => isLoading = true);

    try {
      final token = await AuthService().getToken();
      final prefs = await SharedPreferences.getInstance();
      final tokenNonNull = token;
      String? chefId = prefs.getString('chefId');

      // If we don't have a chefId stored yet, try fetching chef info from the API
      if ((chefId == null || chefId.trim().isEmpty) && tokenNonNull != null) {
        try {
          final meRes = await http
              .get(
                Uri.parse('${AppConfig.baseUrl}/chefs/me'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $tokenNonNull',
                },
              )
              .timeout(const Duration(seconds: 8));

          if (meRes.statusCode == 200) {
            final meData = jsonDecode(meRes.body);
            final fetchedChef = meData['data'];

            final fetchedChefId = fetchedChef?['_id']?.toString() ?? '';

            if (fetchedChefId.isNotEmpty) {
              await prefs.setString('chefId', fetchedChefId);
              chefId = fetchedChefId;

              // keep a local copy of name/profile for UI
              await prefs.setString(
                'userName',
                fetchedChef?['name']?.toString() ??
                    prefs.getString('userName') ??
                    'Chef',
              );
              await prefs.setString(
                'profileImage',
                fetchedChef?['profileImage']?.toString() ??
                    prefs.getString('profileImage') ??
                    '',
              );
            }
          }
        } catch (e) {
          print('Failed to auto-fetch chefId: $e');
        }
      }

      if (chefId == null || chefId.trim().isEmpty || token == null) {
        throw Exception('Chef ID or token not found');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/chef/$chefId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DASHBOARD STATUS => ${response.statusCode}');
      print('DASHBOARD BODY => ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List ordersData = data['orders'] ?? [];

        // ✅ PARSE ORDERS
        allOrders = ordersData.map((e) {
          print('RAW ORDER => $e');
          return Order.fromJson(e);
        }).toList();

        // ✅ TOTAL REVENUE
        // ✅ TOTAL REVENUE
        double revenue = 0;

        for (var order in allOrders) {
          final status = order.status.toString().trim().toLowerCase();

          final total = order.totalPrice > 0 ? order.totalPrice : order.price;
          print('====================');
          print('ORDER => ${order.dishName}');
          print('STATUS => $status');
          print('TOTAL PRICE => $total');
          print('====================');

          // ✅ completed OR completed space fix
          if (status == 'completed' || status.contains('completed')) {
            revenue += total;
          }
        }

        print('🔥🔥 FINAL TOTAL REVENUE => $revenue');

        // ✅ TODAY ORDERS
        final today = DateTime.now();

        final todayOrders = allOrders.where((order) {
          return order.orderTime.year == today.year &&
              order.orderTime.month == today.month &&
              order.orderTime.day == today.day;
        }).toList();

        // ✅ WEEKLY EARNINGS
        weeklyEarnings = List.generate(7, (i) {
          final day = today.subtract(Duration(days: 6 - i));

          double dayRevenue = 0;

          for (var order in allOrders) {
            final sameDay =
                order.orderTime.year == day.year &&
                order.orderTime.month == day.month &&
                order.orderTime.day == day.day;

            if (sameDay && order.status.trim().toLowerCase() == 'completed') {
              dayRevenue += order.totalPrice;
            }
          }

          return dayRevenue;
        });

        // ✅ LATEST ORDERS
        recentOrders = List.from(allOrders);

        recentOrders.sort((a, b) => b.orderTime.compareTo(a.orderTime));

        recentOrders = recentOrders.take(5).toList();

        // ✅ UPDATE UI
        setState(() {
          totalRevenue = revenue;
          ordersToday = todayOrders.length;
          totalOrders = allOrders.length;

          chefName = prefs.getString('userName') ?? 'Chef';

          chefImage = prefs.getString('profileImage') ?? '';

          isLoading = false;
        });

        // ✅ START ANIMATIONS
        if (mounted) {
          _animationController.forward();
          _chartController.forward();
        }
      } else {
        throw Exception('Failed to load dashboard');
      }
    } catch (e) {
      print('DASHBOARD ERROR => $e');

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // ✅ Safe disposal with try-catch
    try {
      _animationController.dispose();
      _pulseController.dispose();
      _chartController.dispose();
    } catch (e) {
      print('Error disposing controllers: $e');
    }
    super.dispose();
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
          child: isLoading
              ? _buildLoadingState()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildGlassmorphicHeader()),
                      SliverToBoxAdapter(child: _buildStatsGrid()),
                      SliverToBoxAdapter(child: _buildWeeklyEarningsChart()),
                      SliverToBoxAdapter(child: _buildOrderStatusChart()),
                      SliverToBoxAdapter(child: _buildQuickActions()),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌟 GLASSMORPHIC HEADER WITH GRADIENT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassmorphicHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated Background Pattern
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GlowingCirclesPainter(
                    animation: _pulseController.value,
                  ),
                );
              },
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Chef Avatar with Glow
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: chefImage.isNotEmpty
                            ? Image.network(
                                chefImage.startsWith('http')
                                    ? chefImage
                                    : '${AppConfig.baseUrl.replaceAll('/api', '')}$chefImage',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildAvatarFallback(),
                              )
                            : _buildAvatarFallback(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Chef Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome Back, Chef 👨‍🍳",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chefName,
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification Bell with Badge
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        if (ordersToday > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  ordersToday > 9 ? '9+' : '$ordersToday',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.accent],
        ),
      ),
      child: Center(
        child: Text(
          chefName.isNotEmpty ? chefName[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  double _getTodayEarnings() {
    final today = DateTime.now();
    return allOrders
        .where((order) {
          return order.orderTime.year == today.year &&
              order.orderTime.month == today.month &&
              order.orderTime.day == today.day &&
              order.status == 'completed';
        })
        .fold(0.0, (sum, order) => sum + order.totalPrice);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 PREMIUM STATS GRID
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.88,
        children: [
          _buildGlowingStatCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.accent,
            value: '\$${totalRevenue.toStringAsFixed(0)}',
            label: "Total Earnings",
            trend: "+${(totalRevenue * 0.15).toStringAsFixed(0)}",
            delay: 0,
          ),
          _buildGlowingStatCard(
            icon: Icons.shopping_bag_rounded,
            iconColor: AppColors.primaryLight,
            value: "$totalOrders",
            label: "Total Orders",
            trend: "+$ordersToday today",
            delay: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String trend,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.card, AppColors.card.withOpacity(0.95)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: iconColor.withOpacity(0.2), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP ROW
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [iconColor, iconColor.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withOpacity(0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 16),
                        );
                      },
                    ),

                    const Spacer(),

                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            trend,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // VALUE
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // LABEL
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📈 WEEKLY EARNINGS CHART (Perfect for Chef)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWeeklyEarningsChart() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card, AppColors.background],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent,
                                AppColors.accent.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Flexible(
                          child: Text(
                            'Weekly Earnings',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last 7 days performance',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (context, child) {
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getMaxEarning() / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.border,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            if (value.toInt() >= 0 &&
                                value.toInt() < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  days[value.toInt()],
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(
                                      0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${value.toInt()}',
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 1),
                        left: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: _getMaxEarning() * 1.2,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.primaryDark,
                        tooltipRoundedRadius: 12,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            return LineTooltipItem(
                              '${days[spot.x.toInt()]}\n\$${spot.y.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          7,
                          (i) => FlSpot(
                            i.toDouble(),
                            weeklyEarnings[i] * _chartController.value,
                          ),
                        ),
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.primaryLight],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: AppColors.accent,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accent.withOpacity(0.3),
                              AppColors.accent.withOpacity(0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 ORDER STATUS CHART (Perfect for Chef) - Bar Chart Version
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOrderStatusChart() {
    int pendingCount = allOrders.where((o) => o.status == 'pending').length;
    int preparingCount = allOrders.where((o) => o.status == 'preparing').length;
    int completedCount = allOrders.where((o) => o.status == 'completed').length;
    int cancelledCount = allOrders.where((o) => o.status == 'cancelled').length;
    int maxCount = math.max(
      math.max(math.max(pendingCount, preparingCount), completedCount),
      math.max(cancelledCount, 1),
    );

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card, AppColors.background],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentOrange,
                      AppColors.accentOrange.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Status bars
          _buildStatusBar(
            label: 'Pending',
            count: pendingCount,
            color: AppColors.warning,
            maxCount: maxCount,
          ),
          const SizedBox(height: 20),
          _buildStatusBar(
            label: 'Preparing',
            count: preparingCount,
            color: AppColors.primaryLight,
            maxCount: maxCount,
          ),
          const SizedBox(height: 20),
          _buildStatusBar(
            label: 'Completed',
            count: completedCount,
            color: AppColors.success,
            maxCount: maxCount,
          ),
          const SizedBox(height: 20),

          _buildStatusBar(
            label: 'Cancelled',
            count: cancelledCount,
            color: AppColors.error,
            maxCount: maxCount,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar({
    required String label,
    required int count,
    required Color color,
    required int maxCount,
  }) {
    final percentage = maxCount == 0 ? 0.0 : (count / maxCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 24,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  double _getMaxEarning() {
    if (weeklyEarnings.isEmpty) return 100;
    final max = weeklyEarnings.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 LATEST ORDERS SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumOrderCard(Order order, int index) {
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    switch (order.status) {
      case "pending":
        statusColor = AppColors.warning;
        statusBgColor = AppColors.warning.withOpacity(0.1);
        statusIcon = Icons.schedule_rounded;
        break;
      case "preparing":
        statusColor = AppColors.primaryLight;
        statusBgColor = AppColors.primaryLight.withOpacity(0.1);
        statusIcon = Icons.restaurant_rounded;
        break;
      case "completed":
        statusColor = AppColors.success;
        statusBgColor = AppColors.success.withOpacity(0.1);
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusBgColor = AppColors.textSecondary.withOpacity(0.1);
        statusIcon = Icons.info_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.card, AppColors.card.withOpacity(0.95)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: order.dishImage.isNotEmpty
                          ? Image.network(
                              order.dishImage.startsWith('http')
                                  ? order.dishImage
                                  : '${AppConfig.baseUrl.replaceAll('/api', '')}${order.dishImage}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.fastfood,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.fastfood,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.dishName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                order.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${order.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚡ QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentOrange,
                      AppColors.accentOrange.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // ✅ ADD RECIPE
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_circle_rounded,
                  label: "Add Recipe",
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.8),
                    ],
                  ),

                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddRecipeScreen(),
                      ),
                    );

                    // 🔥 refresh dashboard after add recipe
                    _loadDashboard();
                  },
                ),
              ),

              const SizedBox(width: 12),

              // ✅ VIEW ORDERS
              Expanded(
                child: _buildActionButton(
                  icon: Icons.receipt_long_rounded,
                  label: "View Orders",
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryLight,
                      AppColors.primaryLight.withOpacity(0.8),
                    ],
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChefOrdersScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏳ LOADING STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.accent],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 GLOWING CIRCLES PAINTER (Background Animation)
// ═══════════════════════════════════════════════════════════════════════════
class _GlowingCirclesPainter extends CustomPainter {
  final double animation;

  _GlowingCirclesPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Animated circles
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3 + animation * 10),
      30 + animation * 5,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7 - animation * 10),
      40 + animation * 8,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.2 + animation * 5),
      25 + animation * 3,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlowingCirclesPainter oldDelegate) => true;
}
