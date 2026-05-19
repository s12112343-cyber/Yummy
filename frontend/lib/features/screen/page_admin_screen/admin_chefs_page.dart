import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';

class AdminChefsPage extends StatefulWidget {
  const AdminChefsPage({super.key});

  @override
  State<AdminChefsPage> createState() => _AdminChefsPageState();
}

class _AdminChefsPageState extends State<AdminChefsPage>
    with TickerProviderStateMixin {
  List<dynamic> _chefs = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = 'rating';
  String _filterSpecialty = 'all';
  String _error = '';

  List<String> _specialties = [];
  final int _placeholderCount = 5;

  late AnimationController _listController;
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _loadChefs();
  }

  @override
  void dispose() {
    _listController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadChefs() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No authentication token found');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chefs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _chefs = data['data'] ?? [];
          _specialties = [
            'all',
            ...(_chefs
                .expand((c) {
                  final specialty = c['specialty'];

                  if (specialty is List) {
                    return specialty;
                  }

                  return [specialty ?? ''];
                })
                .toSet()
                .where((s) => s.isNotEmpty)),
          ];
          _loading = false;
        });
        _listController.forward(from: 0);
      } else {
        throw Exception('Failed to load chefs');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteChef(String chefId) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Chef',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this chef?\nThis action cannot be undone.',
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
        Uri.parse('${AppConfig.baseUrl}/chefs/$chefId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _showToast('Chef deleted successfully');
        await _loadChefs();
      } else {
        _showToast('Failed to delete chef', isError: true);
      }
    } catch (_) {
      _showToast('Error deleting chef', isError: true);
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

  void _showChefDetails(Map<String, dynamic> chef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChefDetailsSheet(chef: chef),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _buildChefAvatar(Map chef, {double radius = 28}) {
    final imageUrl = chef['profileImage'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.babyBlueLight,
      child: Text(
        (chef['name'] ?? 'C')[0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: AppColors.royalBlue,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> get _sortedAndFilteredChefs {
    var filtered = _chefs;

    if (_search.isNotEmpty) {
      filtered = filtered.where((c) {
        final name = (c['name'] ?? '').toLowerCase();
        final specialty = c['specialty'] is List
            ? (c['specialty'] as List).join(' ').toLowerCase()
            : (c['specialty'] ?? '').toString().toLowerCase();
        final query = _search.toLowerCase();
        return name.contains(query) || specialty.contains(query);
      }).toList();
    }

    if (_filterSpecialty != 'all') {
      filtered = filtered.where((c) {
        final specialty = c['specialty'];

        if (specialty is List) {
          return specialty.contains(_filterSpecialty);
        }

        return specialty == _filterSpecialty;
      }).toList();
    }

    filtered.sort((a, b) {
      if (_sortBy == 'rating') {
        return (b['rating'] ?? 0).compareTo(a['rating'] ?? 0);
      }
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _sortedAndFilteredChefs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadChefs,
        color: AppColors.royalBlue,
        displacement: 30,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated Header
              FadeTransition(
                opacity: _headerController,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _headerController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: Row(
                    children: [
                      const Text(
                        'Chefs Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_chefs.length),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.babyBlueLight,
                                AppColors.babyBlue,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_chefs.length} chefs',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.royalBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Search Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or specialty...',
                        hintStyle: TextStyle(
                          color: AppColors.blueGray.withOpacity(0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.blueGray,
                        ),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppColors.blueGray,
                                ),
                                onPressed: () => setState(() => _search = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.white,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.royalBlue,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.sort_rounded,
                        color: AppColors.royalBlue,
                      ),
                      onSelected: (value) => setState(() => _sortBy = value),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rating',
                          child: Text('Sort by Rating'),
                        ),
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Sort by Name'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Specialty Filter
              if (_specialties.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _specialties.map((s) {
                      final isSelected = _filterSpecialty == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TapScaleWidget(
                          onTap: () => setState(() => _filterSpecialty = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
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
                              color: isSelected ? null : AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.royalBlue.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              s == 'all' ? 'All' : s,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.blueGray,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),

              // Chefs List
              Expanded(
                child: _loading
                    ? ListView.builder(
                        itemCount: _placeholderCount,
                        itemBuilder: (_, i) => _buildShimmerCard(i),
                      )
                    : _error.isNotEmpty
                    ? _buildError()
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : _buildChefsList(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChefsList(List filtered) {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final startTime = (i * 0.08).clamp(0.0, 0.7);
            final endTime = (startTime + 0.4).clamp(0.0, 1.0);
            final anim = CurvedAnimation(
              parent: _listController,
              curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
            );

            final chef = filtered[i];

            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: _buildChefCard(chef),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChefCard(Map<String, dynamic> chef) {
    return GestureDetector(
      onTap: () => _showChefDetails(chef),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
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
        ),
        child: Row(
          children: [
            // Avatar with ring
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.lightSky, AppColors.mediumBlue],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: _buildChefAvatar(chef, radius: 28),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chef['name'] ?? 'Unknown Chef',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chef['specialty'] is List
                        ? (chef['specialty'] as List).join(', ')
                        : (chef['specialty'] ?? 'No specialty').toString(),

                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.blueGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildStatChip(
                        Icons.star_rounded,
                        '${chef['rating']?.toStringAsFixed(1) ?? '0.0'}',
                        Colors.amber,
                      ),
                      _buildStatChip(
                        Icons.restaurant_rounded,
                        '${chef['dishes'] ?? 0} dishes',
                        AppColors.royalBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard(int i) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: Duration(milliseconds: 700 + i * 150),
      curve: Curves.easeInOut,
      builder: (_, value, _) => Container(
        height: 90,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(value),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
        ),
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
              onTap: _loadChefs,
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

  Widget _buildEmpty() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        ),
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
                Icons.restaurant_rounded,
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _search.isNotEmpty || _filterSpecialty != 'all'
                  ? 'No matching chefs'
                  : 'No chefs yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chefs can be added from Users page',
              style: TextStyle(fontSize: 12, color: AppColors.blueGray),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chef Details Bottom Sheet ────────────────────────────────────────────────
class _ChefDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> chef;

  const _ChefDetailsSheet({required this.chef});

  @override
  State<_ChefDetailsSheet> createState() => _ChefDetailsSheetState();
}

class _ChefDetailsSheetState extends State<_ChefDetailsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    final chef = widget.chef;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.labelGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar + Name
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.lightSky, AppColors.mediumBlue],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.babyBlueLight,
                  backgroundImage:
                      chef['profileImage'] != null &&
                          chef['profileImage'].isNotEmpty
                      ? NetworkImage(chef['profileImage'])
                      : null,
                  child: chef['profileImage'] == null
                      ? Text(
                          (chef['name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.royalBlue,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chef['name'] ?? 'Unknown Chef',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chef['specialty'] is List
                ? (chef['specialty'] as List).join(', ')
                : (chef['specialty'] ?? 'No specialty').toString(),

            style: const TextStyle(fontSize: 14, color: AppColors.blueGray),
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statPill(
                Icons.star_rounded,
                '${chef['rating']?.toStringAsFixed(1) ?? '0.0'}',
                'Rating',
                Colors.amber,
              ),
              _statPill(
                Icons.restaurant_rounded,
                '${chef['dishes'] ?? 0}',
                'Dishes',
                AppColors.royalBlue,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details
          ...([
            _detail(Icons.email_rounded, 'Email', chef['email']),
            _detail(
              Icons.description_rounded,
              'Bio',
              chef['bio'] is List
                  ? (chef['bio'] as List).join(', ')
                  : chef['bio']?.toString(),
            ),
            _detail(
              Icons.calendar_today_rounded,
              'Joined',
              _fmtDate(chef['createdAt']),
            ),
          ].asMap().entries.map(
            (e) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + e.key * 80),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              ),
              child: e.value,
            ),
          )),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.deepBlue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.blueGray),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.royalBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.blueGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.deepBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? ds) {
    if (ds == null) return 'N/A';
    try {
      final d = DateTime.parse(ds);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'N/A';
    }
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
