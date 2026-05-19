import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage>
    with TickerProviderStateMixin {
  List<dynamic> _reviews = [];
  bool _loading = true;
  String _selectedStatus = 'all';
  String _searchQuery = '';
  String _error = '';

  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadReviews();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No token found');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${res.statusCode}');
      print('Response body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _reviews = data['data'] ?? [];
          _loading = false;
        });
        _listController.forward(from: 0);
      } else {
        throw Exception('Failed to load reviews: ${res.statusCode}');
      }
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approveReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Approve Review',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to approve this review?',
            style: TextStyle(color: AppColors.blueGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.blueGray),
              ),
            ),
            _TapScaleWidget(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Approve',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final res = await http.put(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/approve/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        _showToast('Review approved successfully');
        await _loadReviews();
      } else {
        _showToast('Failed to approve review', isError: true);
      }
    } catch (e) {
      _showToast('Error approving review', isError: true);
    }
  }

  Future<void> _rejectReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Reject Review',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to reject this review?',
            style: TextStyle(color: AppColors.blueGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.blueGray),
              ),
            ),
            _TapScaleWidget(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final res = await http.put(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/reject/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        _showToast('Review rejected successfully');
        await _loadReviews();
      } else {
        _showToast('Failed to reject review', isError: true);
      }
    } catch (e) {
      _showToast('Error rejecting review', isError: true);
    }
  }

  Future<void> _deleteReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Review',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this review?\nThis action cannot be undone.',
            style: TextStyle(color: AppColors.blueGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.blueGray),
              ),
            ),
            _TapScaleWidget(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        _showToast('Review deleted successfully');
        await _loadReviews();
      } else {
        _showToast('Failed to delete review', isError: true);
      }
    } catch (_) {
      _showToast('Error deleting review', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.red : const Color(0xFF3B6D11),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.blueGray;
    }
  }

  double get _averageRating {
    final approvedReviews = _reviews.where((r) => r['status'] == 'approved');
    if (approvedReviews.isEmpty) return 0;
    final sum = approvedReviews.fold<double>(
      0,
      (sum, r) => sum + (r['rating'] ?? 0),
    );
    return sum / approvedReviews.length;
  }

  List<dynamic> get _filteredReviews {
    var filtered = _reviews;

    if (_selectedStatus != 'all') {
      filtered = filtered
          .where((r) => (r['status'] ?? '') == _selectedStatus)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        final userName = (r['userName'] ?? '').toLowerCase();
        final chefName = (r['chefName'] ?? '').toLowerCase();
        final comment = (r['comment'] ?? '').toLowerCase();
        return userName.contains(query) ||
            chefName.contains(query) ||
            comment.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReviews;
    final pendingCount = _reviews.where((r) => r['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        color: AppColors.royalBlue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Stats Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Total Reviews',
                      '${_reviews.length}',
                      Icons.star_rounded,
                      Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Average Rating',
                      _averageRating.toStringAsFixed(1),
                      Icons.star_half_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            // Pending Alert
            if (pendingCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$pendingCount review${pendingCount > 1 ? 's' : ''} pending approval',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Status Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Pending', 'pending'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Approved', 'approved'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Rejected', 'rejected'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Field
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by user, chef, or comment...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.blueGray,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppColors.blueGray,
                                ),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.royalBlue,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Reviews List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: _buildReviewsList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.blueGray,
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

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      backgroundColor: AppColors.white,
      selectedColor: AppColors.royalBlue.withOpacity(0.2),
      checkmarkColor: AppColors.royalBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.royalBlue : AppColors.blueGray,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildReviewsList(List<dynamic> reviews) {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.blueGray),
              ),
              const SizedBox(height: 16),
              _TapScaleWidget(
                onTap: _loadReviews,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.royalBlue, AppColors.mediumBlue],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (reviews.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.babyBlueLight,
                      AppColors.babyBlue.withOpacity(0.5),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_outline,
                  size: 52,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No matching reviews'
                    : 'No reviews yet',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final startTime = (index * 0.08).clamp(0.0, 0.7);
        final endTime = (startTime + 0.4).clamp(0.0, 1.0);
        final anim = CurvedAnimation(
          parent: _listController,
          curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
        );

        final review = reviews[index];
        final isPending = review['status'] == 'pending';

        // ✅ جلب اسم الشيف من البيانات (الـ API الآن ترسله مباشرة)
        final chefName = review['chefName'] ?? 'Unknown Chef';

        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(anim),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isPending
                    ? Border.all(color: Colors.orange.withOpacity(0.5))
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Chef Name - اسم الشيف (يظهر الآن بشكل صحيح)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.royalBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant,
                            size: 14,
                            color: AppColors.royalBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            chefName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.royalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // User Info Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.babyBlueLight,
                          child: Text(
                            (review['userName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.royalBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      review['userName'] ?? 'Anonymous',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepBlue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        review['status'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _getStatusText(review['status']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(
                                          review['status'],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(review['createdAt']),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.blueGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rating Stars
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < (review['rating'] ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    // Comment
                    Text(
                      review['comment'] ?? 'No comment',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.blueGray,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons
                    if (isPending)
                      Row(
                        children: [
                          _TapScaleWidget(
                            onTap: () => _approveReview(review['_id']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Approve',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _TapScaleWidget(
                            onTap: () => _rejectReview(review['_id']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reject',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          _TapScaleWidget(
                            onTap: () => _deleteReview(review['_id']),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.red,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _TapScaleWidget(
                            onTap: () => _deleteReview(review['_id']),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.red,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }, childCount: reviews.length),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────
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

class _AnimatedDialog extends StatefulWidget {
  final Widget child;

  const _AnimatedDialog({required this.child});

  @override
  State<_AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<_AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    )..forward();
    _scale = Tween(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
