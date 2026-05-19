import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});

  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage>
    with TickerProviderStateMixin {
  List<dynamic> _banners = [];
  bool _loading = true;
  bool _showForm = false;
  String? _editingId;
  int? _hoveredIndex;

  final _imageCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '1');
  final _expiryCtrl = TextEditingController();

  late AnimationController _formController;
  late AnimationController _listController;
  late Animation<double> _formAnimation;

  @override
  void initState() {
    super.initState();

    _formController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _listController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _loadBanners();
  }

  @override
  void dispose() {
    _imageCtrl.dispose();
    _linkCtrl.dispose();
    _orderCtrl.dispose();
    _expiryCtrl.dispose();
    _formController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/banners'));
      final data = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _banners = data['banners'] ?? [];
          _loading = false;
        });
        _listController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBanner() async {
    if (_imageCtrl.text.isEmpty) {
      _showToast('Please enter image URL', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        _showToast('Authentication failed', isError: true);
        return;
      }

      final Map<String, dynamic> bannerData = {
        'image': _imageCtrl.text.trim(),
        'link': _linkCtrl.text.trim(),
        'order': int.tryParse(_orderCtrl.text) ?? 1,
      };
      if (_expiryCtrl.text.isNotEmpty) {
        bannerData['expiryDate'] = _expiryCtrl.text;
      }

      final body = jsonEncode(bannerData);
      late http.Response res;

      if (_editingId == null) {
        res = await http.post(
          Uri.parse('${AppConfig.baseUrl}/banners'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        );
      } else {
        res = await http.put(
          Uri.parse('${AppConfig.baseUrl}/banners/$_editingId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _showToast(
          _editingId == null
              ? 'Banner added successfully'
              : 'Banner updated successfully',
        );
        _clearForm();
        await _loadBanners();
      } else {
        try {
          final errorData = jsonDecode(res.body);
          _showToast(
            'Error: ${errorData['message'] ?? res.statusCode}',
            isError: true,
          );
        } catch (_) {
          _showToast('Error: ${res.statusCode}', isError: true);
        }
      }
    } catch (e) {
      _showToast('Error saving banner: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Banner',
      content: 'Are you sure you want to delete this banner?',
    );
    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/banners/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showToast('Banner deleted successfully');
        await _loadBanners();
      } else {
        _showToast('Error deleting banner', isError: true);
      }
    } catch (_) {
      _showToast('Error deleting banner', isError: true);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(color: AppColors.blueGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.blueGray),
              ),
            ),
            _TapScaleButton(
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
  }

  void _clearForm() {
    _formController.reverse().then((_) {
      setState(() {
        _editingId = null;
        _showForm = false;
        _imageCtrl.clear();
        _linkCtrl.clear();
        _orderCtrl.text = '1';
        _expiryCtrl.clear();
      });
    });
  }

  void _editBanner(Map b) {
    setState(() {
      _editingId = b['_id'];
      _showForm = true;
      _imageCtrl.text = b['image'] ?? '';
      _linkCtrl.text = b['link'] ?? '';
      _orderCtrl.text = (b['order'] ?? 1).toString();
      _expiryCtrl.text = b['expiryDate'] != null
          ? b['expiryDate'].toString().split('T')[0]
          : '';
    });
    _formController.forward(from: 0);
  }

  void _previewBanner(String url) {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _AnimatedDialog(
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.navy, AppColors.royalBlue],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.preview_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Banner Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Hero(
                    tag: 'banner_$url',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: AppColors.babyBlueLight,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.royalBlue,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: AppColors.babyBlue,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppColors.blueGray,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _TapScaleButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.royalBlue, AppColors.mediumBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
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
            Expanded(child: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),

      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // 🔥 إخفاء الكيبورد

          child: SingleChildScrollView(
            // 🔥 الحل الرئيسي
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(
                  context,
                ).viewInsets.bottom, // 🔥 يرفع الفورم
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔵 HEADER
                  _buildHeader(),

                  const SizedBox(height: 16),

                  /// 🟡 FORM
                  SizeTransition(
                    sizeFactor: _formAnimation,
                    axisAlignment: -1,
                    child: FadeTransition(
                      opacity: _formAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildForm(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔴 LIST (بدل Expanded)
                  SizedBox(
                    height: 400, // تقدري تغيري الرقم
                    child: _buildBannersList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: _TapScaleButton(
            onTap: () {
              FocusScope.of(context).unfocus();
              if (_showForm) {
                _formController.reverse().then((_) {
                  setState(() {
                    _showForm = false;
                    _editingId = null;
                    _imageCtrl.clear();
                    _linkCtrl.clear();
                    _orderCtrl.text = '1';
                    _expiryCtrl.clear();
                  });
                });
              } else {
                setState(() => _showForm = true);
                _formController.forward(from: 0);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: _showForm
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.royalBlue, AppColors.mediumBlue],
                      ),
                color: _showForm ? AppColors.babyBlueLight : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _showForm
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _showForm ? Icons.close : Icons.add_rounded,
                      key: ValueKey(_showForm),
                      size: 20,
                      color: _showForm ? AppColors.blueGray : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _showForm ? 'Cancel' : 'Add Banner',
                      key: ValueKey(_showForm),
                      style: TextStyle(
                        color: _showForm ? AppColors.blueGray : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_banners.isNotEmpty) ...[
          const SizedBox(width: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_banners.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.royalBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.royalBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightSky.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.royalBlue.withOpacity(0.15),
                      AppColors.mediumBlue.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _editingId == null
                      ? Icons.add_photo_alternate
                      : Icons.edit_rounded,
                  color: AppColors.royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _editingId == null ? 'Add New Banner' : 'Edit Banner',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _imageCtrl,
            hintText: 'https://example.com/image.jpg',
            labelText: 'Image URL *',
            icon: Icons.image_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _linkCtrl,
            hintText: 'https://example.com',
            labelText: 'Link (optional)',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _orderCtrl,
                  hintText: '1',
                  labelText: 'Order',
                  icon: Icons.format_list_numbered_rounded,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildDateField()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TapScaleButton(
                  onTap: _saveBanner,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.royalBlue, AppColors.mediumBlue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _editingId == null ? 'Save Banner' : 'Update',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_editingId != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _TapScaleButton(
                    onTap: _clearForm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.babyBlueLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.softBlue, width: 1),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.blueGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.url,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.blueGray.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: AppColors.royalBlue, size: 20),
        filled: true,
        fillColor: AppColors.babyBlueLight,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextField(
      controller: _expiryCtrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Expiry Date',
        hintText: 'Select date',
        hintStyle: TextStyle(color: AppColors.blueGray.withOpacity(0.5)),
        prefixIcon: const Icon(
          Icons.calendar_today_rounded,
          color: AppColors.royalBlue,
          size: 18,
        ),
        filled: true,
        fillColor: AppColors.babyBlueLight,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.royalBlue,
                onPrimary: Colors.white,
                surface: AppColors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null && mounted) {
          setState(
            () => _expiryCtrl.text = date.toIso8601String().split('T')[0],
          );
        }
      },
    );
  }

  Widget _buildBannersList() {
    if (_loading) {
      return ListView.builder(
        itemCount: 4,
        itemBuilder: (_, i) => _buildShimmerBannerCard(i),
      );
    }

    if (_banners.isEmpty) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        ),
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
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 52,
                  color: AppColors.royalBlue,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Banners Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click "Add Banner" to get started',
                style: TextStyle(fontSize: 13, color: AppColors.blueGray),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        return ListView.builder(
          itemCount: _banners.length,
          itemBuilder: (_, i) {
            final startTime = (i * 0.1).clamp(0.0, 0.8);
            final endTime = (startTime + 0.35).clamp(0.0, 1.0);
            final anim = CurvedAnimation(
              parent: _listController,
              curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
            );

            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: _buildBannerCard(i),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerBannerCard(int i) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + i * 100),
      builder: (context, value, child) => Opacity(
        opacity: value * 0.5,
        child: Container(
          height: 86,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard(int i) {
    final b = _banners[i];
    final isExpired =
        b['expiryDate'] != null &&
        DateTime.tryParse(b['expiryDate'])?.isBefore(DateTime.now()) == true;
    final isHovered = _hoveredIndex == i;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(isHovered ? 0.12 : 0.05),
            blurRadius: isHovered ? 16 : 8,
            offset: Offset(0, isHovered ? 6 : 2),
          ),
        ],
        border: Border.all(
          color: isHovered
              ? AppColors.lightSky.withOpacity(0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = i),
        onExit: (_) => setState(() => _hoveredIndex = null),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image thumbnail with Hero
              Hero(
                tag: 'banner_${b['image']}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isExpired
                          ? AppColors.red.withOpacity(0.3)
                          : AppColors.softBlue,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withOpacity(0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: Image.network(
                        b['image'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.babyBlueLight,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: AppColors.blueGray,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['image'] ?? 'No URL',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildChip(
                          icon: Icons.format_list_numbered_rounded,
                          label: '${b['order'] ?? 0}',
                        ),
                        if (b['link'] != null && b['link'].isNotEmpty)
                          _buildChip(
                            icon: Icons.link_rounded,
                            label: 'Has Link',
                          ),
                        if (b['expiryDate'] != null)
                          _buildChip(
                            icon: Icons.calendar_today_rounded,
                            label: _formatDate(b['expiryDate']),
                            isExpired: isExpired,
                          ),
                        if (isExpired)
                          _buildChip(
                            icon: Icons.warning_amber_rounded,
                            label: 'Expired',
                            isExpired: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.remove_red_eye_rounded,
                    color: AppColors.royalBlue,
                    onPressed: () => _previewBanner(b['image']),
                    isHovered: isHovered,
                  ),
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: AppColors.mediumBlue,
                    onPressed: () => _editBanner(b),
                    isHovered: isHovered,
                  ),
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.red,
                    onPressed: () => _deleteBanner(b['_id']),
                    isHovered: isHovered,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isHovered,
  }) {
    return _TapScaleButton(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 4),
        padding: EdgeInsets.all(isHovered ? 9 : 7),
        decoration: BoxDecoration(
          color: isHovered ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    bool isExpired = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? AppColors.red.withOpacity(0.1)
            : AppColors.babyBlueLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isExpired ? AppColors.red : AppColors.royalBlue,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isExpired ? AppColors.red : AppColors.royalBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}';
    } catch (_) {
      return dateString.split('T')[0];
    }
  }
}

// ─── Reusable Helpers ─────────────────────────────────────────────────────────

class _TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScaleButton({required this.child, required this.onTap});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton>
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
          end: 0.94,
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
