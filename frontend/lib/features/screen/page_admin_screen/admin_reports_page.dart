import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with TickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _reports = {};

  String _selectedPeriod = 'week';
  DateTime? _startDate;
  DateTime? _endDate;

  late AnimationController _contentController;
  late AnimationController _periodController;

  final List<Map<String, dynamic>> _periods = [
    {'value': 'day', 'label': 'Today', 'icon': Icons.today_rounded},
    {'value': 'week', 'label': 'This Week', 'icon': Icons.date_range_rounded},
    {
      'value': 'month',
      'label': 'This Month',
      'icon': Icons.calendar_month_rounded,
    },
    {'value': 'custom', 'label': 'Custom', 'icon': Icons.edit_calendar_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _periodController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    _loadReports();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No token found');

      String url = '${AppConfig.baseUrl}/admin/reports?period=$_selectedPeriod';
      if (_selectedPeriod == 'custom' &&
          _startDate != null &&
          _endDate != null) {
        url +=
            '&start=${_startDate!.toIso8601String()}&end=${_endDate!.toIso8601String()}';
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _reports = data['reports'] ?? {};
          _loading = false;
        });
      } else {
        _loadEmptyData();
      }
    } catch (_) {
      _loadEmptyData();
    }

    _contentController.forward(from: 0);
  }

  void _loadEmptyData() {
    setState(() {
      _reports = {
        'revenue': 0.0,
        'todayRevenue': 0.0,
        'weeklyRevenue': 0.0,
        'monthlyRevenue': 0.0,
        'totalRevenue': 0.0,
        'avgOrderValue': 0.0,
        'totalOrders': 0,
        'todayOrders': 0,
        'weeklyOrders': 0,
        'monthlyOrders': 0,
        'pendingOrders': 0,
        'deliveredOrders': 0,
        'cancelledOrders': 0,
        'topChefs': [],
        'popularMeals': [],
      };
      _loading = false;
    });
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.royalBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadReports();
    }
  }

  String _formatCurrency(double amount) => '\$${amount.toStringAsFixed(2)}';

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'day':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'custom':
        if (_startDate != null && _endDate != null) {
          return '${_startDate!.day}/${_startDate!.month} — ${_endDate!.day}/${_endDate!.month}';
        }
        return 'Custom';
      default:
        return 'This Week';
    }
  }

  num _getValue(String key, {num defaultValue = 0}) {
    final value = _reports[key];
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Period Filter Bar
          FadeTransition(
            opacity: _periodController,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, -0.5),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _periodController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withOpacity(0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      color: AppColors.royalBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Period:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBlue,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _periods.map((period) {
                            final isSelected =
                                _selectedPeriod == period['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _TapScaleWidget(
                                onTap: () {
                                  setState(() {
                                    _selectedPeriod = period['value'];
                                    if (_selectedPeriod != 'custom') {
                                      _startDate = null;
                                      _endDate = null;
                                    }
                                  });
                                  _loadReports();
                                  if (_selectedPeriod == 'custom') {
                                    _selectCustomDateRange();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.royalBlue,
                                              AppColors.mediumBlue,
                                            ],
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : AppColors.babyBlueLight,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.royalBlue
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        period['icon'] as IconData,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.blueGray,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        period['label'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.blueGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (_selectedPeriod == 'custom' &&
                        (_startDate != null || _endDate != null))
                      _TapScaleWidget(
                        onTap: _selectCustomDateRange,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.babyBlueLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: AppColors.royalBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.royalBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading reports...',
                          style: TextStyle(
                            color: AppColors.blueGray.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    color: AppColors.royalBlue,
                    child: AnimatedBuilder(
                      animation: _contentController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _contentController.value,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              20 * (1 - _contentController.value),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildRevenueCard(),
                          const SizedBox(height: 14),
                          _buildOrdersCard(),
                          const SizedBox(height: 14),
                          _buildTopChefsCard(),
                          const SizedBox(height: 14),
                          _buildPopularMealsCard(),
                          const SizedBox(height: 14),
                          _buildInfoNote(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return _ReportCard(
      title: 'Revenue',
      icon: Icons.attach_money_rounded,
      color: const Color(0xFF3B6D11),
      periodLabel: _getPeriodLabel(),
      children: [
        if (_selectedPeriod == 'day') ...[
          _ReportRow(
            'Today Revenue',
            _formatCurrency(_getValue('todayRevenue').toDouble()),
          ),
          _ReportRow('Today Orders', '${_getValue('todayOrders')}'),
        ] else if (_selectedPeriod == 'week') ...[
          _ReportRow(
            'Weekly Revenue',
            _formatCurrency(_getValue('weeklyRevenue').toDouble()),
          ),
          _ReportRow('Weekly Orders', '${_getValue('weeklyOrders')}'),
        ] else if (_selectedPeriod == 'month') ...[
          _ReportRow(
            'Monthly Revenue',
            _formatCurrency(_getValue('monthlyRevenue').toDouble()),
          ),
          _ReportRow('Monthly Orders', '${_getValue('monthlyOrders')}'),
        ] else ...[
          _ReportRow(
            'Total Revenue',
            _formatCurrency(_getValue('totalRevenue').toDouble()),
          ),
          _ReportRow('Total Orders', '${_getValue('totalOrders')}'),
        ],
        const Divider(height: 1, color: AppColors.babyBlueLight),
        _ReportRow(
          'Average Order',
          _formatCurrency(_getValue('avgOrderValue').toDouble()),
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildOrdersCard() {
    final total = _getValue('totalOrders');
    final delivered = _getValue('deliveredOrders');
    final completionRate = total > 0
        ? (delivered.toDouble() / total.toDouble() * 100).toStringAsFixed(1)
        : '0';

    return _ReportCard(
      title: 'Orders Statistics',
      icon: Icons.shopping_cart_rounded,
      color: AppColors.royalBlue,
      periodLabel: _getPeriodLabel(),
      children: [
        _ReportRow('Total Orders', '${_getValue('totalOrders')}'),
        _ReportRow('Delivered', '${_getValue('deliveredOrders')}'),
        _ReportRow('Pending', '${_getValue('pendingOrders')}'),
        _ReportRow('Cancelled', '${_getValue('cancelledOrders')}'),
        const Divider(height: 1, color: AppColors.babyBlueLight),
        _ReportRow('Completion Rate', '$completionRate%', isBold: true),
      ],
    );
  }

  Widget _buildTopChefsCard() {
    final chefs = _reports['topChefs'] as List? ?? [];

    return _ReportCard(
      title: 'Top Chefs',
      icon: Icons.emoji_events_rounded,
      color: Colors.orange,
      periodLabel: _getPeriodLabel(),
      children: chefs.isEmpty
          ? [_buildEmptySection('No chef data available yet')]
          : chefs.asMap().entries.map((e) {
              final i = e.key;
              final chef = e.value;
              return _buildTopItem(
                rank: i + 1,
                name: chef['name'] ?? 'Unknown',
                subtitle: '${chef['ordersCount'] ?? 0} orders',
                trailing: _formatCurrency((chef['revenue'] ?? 0).toDouble()),
                color: _rankColor(i),
              );
            }).toList(),
    );
  }

  Widget _buildPopularMealsCard() {
    final meals = _reports['popularMeals'] as List? ?? [];

    return _ReportCard(
      title: 'Popular Meals',
      icon: Icons.fastfood_rounded,
      color: Colors.purple,
      periodLabel: _getPeriodLabel(),
      children: meals.isEmpty
          ? [_buildEmptySection('No meal data available yet')]
          : meals.asMap().entries.map((e) {
              final i = e.key;
              final meal = e.value;
              return _buildTopItem(
                rank: i + 1,
                name: meal['name'] ?? 'Unknown',
                subtitle: '${meal['ordersCount'] ?? 0} orders',
                trailing: _formatCurrency((meal['revenue'] ?? 0).toDouble()),
                color: _rankColor(i),
                icon: Icons.restaurant_rounded,
              );
            }).toList(),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.babyBlueLight,
            AppColors.babyBlue.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.lightSky.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.royalBlue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Some data will appear after full API integration: Orders, Revenue, Top Chefs, Popular Meals.',
              style: TextStyle(fontSize: 11, color: AppColors.blueGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              msg,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Will be available after API integration',
              style: TextStyle(fontSize: 11, color: AppColors.blueGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItem({
    required int rank,
    required String name,
    required String subtitle,
    required String trailing,
    required Color color,
    IconData icon = Icons.person_rounded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepBlue,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.blueGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.royalBlue,
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.blueGrey;
      case 2:
        return Colors.brown;
      default:
        return AppColors.blueGray;
    }
  }
}

// ─── Report Card ──────────────────────────────────────────────────────────────
class _ReportCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String periodLabel;
  final List<Widget> children;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.periodLabel,
    required this.children,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withOpacity(0.12),
                        widget.color.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.periodLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: AppColors.babyBlueLight,
            indent: 16,
            endIndent: 16,
          ),
          ...widget.children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── Report Row ───────────────────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ReportRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.blueGray, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              fontSize: isBold ? 15 : 14,
              color: isBold ? AppColors.royalBlue : AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _TapScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScaleWidget({required this.child, required this.onTap});

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 110),
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
          end: 0.93,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    );
  }
}
