import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';

import 'admin_orders_page.dart';
import 'admin_reviews_page.dart';
import 'admin_chefs_page.dart';
import 'admin_users_page.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage>
    with TickerProviderStateMixin {
  int _users = 0;
  int _chefs = 0;
  int _banners = 0;
  int _orders = 0;
  bool _loading = true;
  String _error = '';
  double _revenue = 0;
  List<dynamic> _weeklyOrders = [];
  Map<String, dynamic>? _topChef;
  late AnimationController _staggerController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _shimmerAnimation;

  // Dynamic data from API
  List<CategoryData> _categoryData = [];
  List<OrderStatusData> _orderStatusData = [];

  // Color palette for categories
  static const List<Color> _categoryColors = [
    Color(0xFFE94B3C), // Red
    Color(0xFFFFA500), // Orange
    Color(0xFF3B6D11), // Green
    Color(0xFF854F0B), // Brown
    Color(0xFF005EB2), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
  ];

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _loadStats();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _calculateCategoryData(List<dynamic> allRecipes) {
    final Map<String, int> categoryCount = {};

    // 🔥 COUNT CATEGORIES
    for (var recipe in allRecipes) {
      final category = (recipe['category'] ?? 'Other').toString();

      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    // 🔥 COLORS
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    // 🔥 SORT TOP 5
    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();

    // 🔥 TOTAL OF TOP 5
    final total = top5.fold<int>(0, (sum, item) => sum + item.value);

    // 🔥 CREATE DATA
    final List<CategoryData> finalData = [];

    for (int i = 0; i < top5.length; i++) {
      final item = top5[i];

      final percentage = ((item.value / total) * 100).round();

      finalData.add(
        CategoryData(
          name: item.key,
          percentage: percentage,
          color: colors[i % colors.length],
        ),
      );
    }

    setState(() {
      _categoryData = finalData;
    });
  }

  void _calculateOrderStatusData(List<dynamic> allOrders) {
    final Map<String, int> statusCount = {
      'pending': 0,
      'preparing': 0,
      'completed': 0,
      'cancelled': 0,
    };

    // COUNT ORDERS
    for (var order in allOrders) {
      final status = (order['status'] ?? '').toString().toLowerCase();

      if (statusCount.containsKey(status)) {
        statusCount[status] = statusCount[status]! + 1;
      }
    }

    final statuses = [
      OrderStatusData(
        status: 'Pending',
        count: statusCount['pending'] ?? 0,

        color: AppColors.royalBlue,

        icon: Icons.schedule_rounded,
      ),

      OrderStatusData(
        status: 'Preparing',
        count: statusCount['preparing'] ?? 0,

        color: const Color(0xFFFFA500),

        icon: Icons.restaurant_rounded,
      ),

      OrderStatusData(
        status: 'Completed',
        count: statusCount['completed'] ?? 0,

        color: const Color(0xFF3B6D11),

        icon: Icons.check_circle_rounded,
      ),

      OrderStatusData(
        status: 'Cancelled',
        count: statusCount['cancelled'] ?? 0,

        color: AppColors.red,

        icon: Icons.cancel_rounded,
      ),
    ];

    setState(() {
      _orderStatusData = statuses;
    });
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();

      if (token == null) {
        throw Exception('No token found');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        http.get(Uri.parse('${AppConfig.baseUrl}/users/all'), headers: headers),

        http.get(Uri.parse('${AppConfig.baseUrl}/chefs'), headers: headers),

        http.get(Uri.parse('${AppConfig.baseUrl}/banners'), headers: headers),

        http.get(
          Uri.parse('${AppConfig.baseUrl}/orders/all'),
          headers: headers,
        ),

        // 🔥 RECIPES
        http.get(Uri.parse('${AppConfig.baseUrl}/recipes'), headers: headers),
      ]);

      // USERS
      if (results[0].statusCode == 200) {
        final usersData = jsonDecode(results[0].body);
        _users = (usersData['users'] ?? []).length;
      }

      // CHEFS
      List<dynamic> allChefs = [];
      if (results[1].statusCode == 200) {
        final chefsData = jsonDecode(results[1].body);
        allChefs = chefsData['data'] ?? chefsData['chefs'] ?? [];
        _chefs = allChefs.length;
        // Calculate categories from chefs data
        // 🔥 RECIPES
        if (results[4].statusCode == 200) {
          final recipesData = jsonDecode(results[4].body);

          final recipes = recipesData['recipes'] ?? recipesData['data'] ?? [];

          _calculateCategoryData(recipes);
        }
      }

      // BANNERS
      if (results[2].statusCode == 200) {
        final bannersData = jsonDecode(results[2].body);
        _banners = (bannersData['banners'] ?? []).length;
      }

      // ORDERS
      List<dynamic> allOrders = [];
      if (results[3].statusCode == 200) {
        final ordersData = jsonDecode(results[3].body);
        allOrders = ordersData['orders'] ?? [];
        _orders = allOrders.length;

        // Calculate order status data
        _calculateOrderStatusData(allOrders);

        // WEEKLY
        _weeklyOrders = List.generate(7, (i) {
          final day = DateTime.now().subtract(Duration(days: 6 - i));
          return allOrders.where((o) {
            final created = DateTime.tryParse(o['createdAt'] ?? '');
            if (created == null) return false;
            return created.day == day.day && created.month == day.month;
          }).length;
        });
      }

      setState(() {
        _loading = false;
      });

      _staggerController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Animation<double> _cardAnimation(int index) {
    final start = index * 0.15;
    final end = start + 0.55;
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.blueGray),
            ),
            const SizedBox(height: 16),
            _AnimatedRetryButton(onTap: _loadStats),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back, Admin!',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.blueGray.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats Grid
            _loading
                ? _buildShimmerGrid()
                : AnimatedBuilder(
                    animation: _staggerController,
                    builder: (context, child) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimation(0),
                                  child: _EnhancedStatCard(
                                    label: 'Total Users',
                                    value: _users,
                                    icon: Icons.people_rounded,
                                    color: AppColors.royalBlue,
                                    pulseController: _pulseController,
                                    trend: '+12%',
                                    trendUp: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimation(1),
                                  child: _EnhancedStatCard(
                                    label: 'Total Chefs',
                                    value: _chefs,
                                    icon: Icons.restaurant_rounded,
                                    color: const Color(0xFF3B6D11),
                                    pulseController: _pulseController,
                                    trend: '+5%',
                                    trendUp: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimation(2),
                                  child: _EnhancedStatCard(
                                    label: 'Total Orders',
                                    value: _orders,
                                    icon: Icons.receipt_long_rounded,
                                    color: const Color(0xFF854F0B),
                                    pulseController: _pulseController,
                                    trend: '+28%',
                                    trendUp: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimation(3),
                                  child: _EnhancedStatCard(
                                    label: 'Banners',
                                    value: _banners,
                                    icon: Icons.campaign_rounded,
                                    color: AppColors.mediumBlue,
                                    pulseController: _pulseController,
                                    trend: '—',
                                    trendUp: null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
            const SizedBox(height: 28),

            _buildCharts(),

            const SizedBox(height: 28),

            // NEW: Most Ordered Categories Section
            if (_categoryData.isNotEmpty || _orderStatusData.isNotEmpty)
              _buildCategoriesAndOrderStatus(),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // WEEKLY ORDERS CHART
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Orders This Week',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last 7 days overview',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.blueGray.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.royalBlue.withOpacity(0.1),
                            AppColors.mediumBlue.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.royalBlue.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: AppColors.royalBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_weeklyOrders.isEmpty ? 0 : _weeklyOrders.reduce((a, b) => a + b)} Total',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.royalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_weeklyOrders.isEmpty)
                  SizedBox(
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 48,
                            color: AppColors.blueGray.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No data available',
                            style: TextStyle(
                              color: AppColors.blueGray.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            (_weeklyOrders.isEmpty
                                ? 10
                                : _weeklyOrders
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble()) *
                            1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                AppColors.deepBlue.withOpacity(0.95),
                            tooltipRoundedRadius: 12,
                            tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toInt()} orders\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(
                                    text: _getWeekDayName(groupIndex),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
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
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    _getWeekDayName(value.toInt()),
                                    style: TextStyle(
                                      color: AppColors.blueGray.withOpacity(
                                        0.7,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: AppColors.blueGray.withOpacity(0.6),
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
                            bottom: BorderSide(
                              color: AppColors.blueGray.withOpacity(0.1),
                            ),
                            left: BorderSide(
                              color: AppColors.blueGray.withOpacity(0.1),
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 5,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppColors.blueGray.withOpacity(0.08),
                              strokeWidth: 1,
                              dashArray: [8, 4],
                            );
                          },
                        ),
                        barGroups: _weeklyOrders.asMap().entries.map((e) {
                          final value = e.value.toDouble();
                          final isHighest =
                              value ==
                              _weeklyOrders
                                  .reduce((a, b) => a > b ? a : b)
                                  .toDouble();
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: value,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isHighest
                                      ? [
                                          const Color(0xFF3B6D11),
                                          const Color(0xFF5A9B1C),
                                        ]
                                      : [
                                          AppColors.royalBlue,
                                          AppColors.mediumBlue,
                                        ],
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY:
                                      (_weeklyOrders.isEmpty
                                          ? 10
                                          : _weeklyOrders
                                                .reduce((a, b) => a > b ? a : b)
                                                .toDouble()) *
                                      1.2,
                                  color: AppColors.babyBlueLight,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  /// Categories and Order Status Section
  Widget _buildCategoriesAndOrderStatus() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE94B3C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFFE94B3C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Most Ordered Categories Card
          if (_categoryData.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most Ordered Categories',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Top food categories by chefs',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.blueGray.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Donut Chart
                      SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections: _categoryData.asMap().entries.map((
                                  e,
                                ) {
                                  final data = e.value;
                                  return PieChartSectionData(
                                    value: data.percentage.toDouble(),

                                    color: data.color,

                                    radius: 70,

                                    title: '${data.percentage}%',

                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),

                                    titlePositionPercentageOffset: 0.6,
                                  );
                                }).toList(),
                                centerSpaceRadius: 45,
                                sectionsSpace: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Category Legend
                      Column(
                        children: _categoryData.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: cat.color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.deepBlue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${cat.percentage}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cat.color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),

          // Order Status Card
          if (_orderStatusData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current orders breakdown',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.blueGray.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Status Items
                  Column(
                    children: _orderStatusData.map((status) {
                      final total = _orderStatusData.fold<int>(
                        0,
                        (sum, item) => sum + item.count,
                      );
                      final percentage = total > 0
                          ? ((status.count / total) * 100).toStringAsFixed(1)
                          : '0.0';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: status.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    status.icon,
                                    size: 16,
                                    color: status.color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        status.status,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.deepBlue,
                                        ),
                                      ),
                                      Text(
                                        '${status.count} orders',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.blueGray.withOpacity(
                                            0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: status.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total > 0 ? status.count / total : 0,
                                backgroundColor: status.color.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(
                                  status.color,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.babyBlueLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.deepBlue,
        ),
      ),
    );
  }

  String _getWeekDayName(int index) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index % 7];
  }

  Widget _quickCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.royalBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: AppColors.royalBlue),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({
    required Animation<double> animation,
    required Widget child,
  }) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  Widget _buildShimmerGrid() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ShimmerCard(progress: _shimmerAnimation.value),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShimmerCard(progress: _shimmerAnimation.value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShimmerCard(progress: _shimmerAnimation.value),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShimmerCard(progress: _shimmerAnimation.value),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Data Models ───────────────────────────────────────────────────────────

class CategoryData {
  final String name;
  final int percentage;
  final Color color;

  CategoryData({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

class OrderStatusData {
  final String status;
  final int count;
  final Color color;
  final IconData icon;

  OrderStatusData({
    required this.status,
    required this.count,
    required this.color,
    required this.icon,
  });
}

// ─── Enhanced Stat Card ───────────────────────────────────────────────────────
class _EnhancedStatCard extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final AnimationController pulseController;
  final String trend;
  final bool? trendUp;

  const _EnhancedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.pulseController,
    required this.trend,
    required this.trendUp,
  });

  @override
  State<_EnhancedStatCard> createState() => _EnhancedStatCardState();
}

class _EnhancedStatCardState extends State<_EnhancedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _counterController;
  late Animation<int> _counterAnimation;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _counterAnimation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOutCubic),
    );
    _counterController.forward();
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedBuilder(
                animation: widget.pulseController,
                builder: (context, child) {
                  return Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(
                        0.1 + 0.05 * widget.pulseController.value,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  );
                },
              ),
              if (widget.trendUp != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (widget.trendUp!
                                ? const Color(0xFF3B6D11)
                                : AppColors.red)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.trendUp!
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: widget.trendUp!
                            ? const Color(0xFF3B6D11)
                            : AppColors.red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.trend,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.trendUp!
                              ? const Color(0xFF3B6D11)
                              : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _counterAnimation,
            builder: (context, child) => Text(
              '${_counterAnimation.value}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.deepBlue,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.blueGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: math.min(widget.value / 100.0, 1.0)),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                backgroundColor: widget.color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(widget.color),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer Card ─────────────────────────────────────────────────────────────
class _ShimmerCard extends StatelessWidget {
  final double progress;
  const _ShimmerCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(progress - 1, 0),
          end: Alignment(progress, 0),
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
    );
  }
}

// ─── Animated Retry Button ────────────────────────────────────────────────────
class _AnimatedRetryButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedRetryButton({required this.onTap});

  @override
  State<_AnimatedRetryButton> createState() => _AnimatedRetryButtonState();
}

class _AnimatedRetryButtonState extends State<_AnimatedRetryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(
          begin: 1.0,
          end: 0.94,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.royalBlue, AppColors.mediumBlue],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalBlue.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Text(
            'Retry',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
