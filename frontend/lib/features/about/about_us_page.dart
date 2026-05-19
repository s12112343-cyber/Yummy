import 'dart:ui';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: AppColors.background,
            foregroundColor: AppColors.deepBlue,
            elevation: 0,
            pinned: true,
            centerTitle: false,
            titleSpacing: 0,
            leadingWidth: 56,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'Yummy',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.deepBlue,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 340,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/image.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.deepBlue,
                                  AppColors.royalBlue,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.deepBlue.withOpacity(0.28),
                              AppColors.deepBlue.withOpacity(0.66),
                              AppColors.royalBlue.withOpacity(0.76),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 62,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 4),
                            const Text(
                              'About Yummy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A simple, polished space for tracking meals, discovering recipes, and staying on top of your health goals.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OUR MISSION',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Nourish Your Life',
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Yummy helps you build better food habits with a clean experience for logging meals, following recipes, and tracking progress in one place.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 0,
                    child: SizedBox(
                      height: 128,
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final feature = _AboutFeature.items[index];
                          return _AboutFeatureCard(feature: feature);
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 1,
                    child: _FeatureImageCard(
                      imagePath: 'assets/images/image1.png',
                      title: 'Smart Meal Tracking',
                      subtitle:
                          'Log your meals effortlessly with AI-powered recognition, instant breakdowns, and tailored suggestions.',
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 2,
                    child: _FeatureImageCard(
                      imagePath: 'assets/images/image2.png',
                      title: 'Healthy Recipes',
                      subtitle:
                          'Discover healthy recipes, cooking steps, and useful details to help you choose meals that fit your lifestyle.',
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 3,
                    child: _FeatureImageCard(
                      imagePath: 'assets/images/about_community.png',
                      title: 'Recipe Community',
                      subtitle:
                          'Share your favorite recipes, discover meals from other users, and connect with people who enjoy cooking and healthy food.',
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 4,
                    child: _FeatureImageCard(
                      imagePath: 'assets/images/chef.png',
                      title: 'Shop from Chefs',
                      subtitle:
                          'Explore chefs, browse their available recipes and products, and order what you need directly from the app.',
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _ScrollReveal(
                    scrollController: _scrollController,
                    index: 5,
                    child: const _FeedbackCard(),
                  ),
                ),

                const SizedBox(height: 12),

                // Footer: divider + app email
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Divider(
                        color: AppColors.deepBlue.withOpacity(0.12),
                        thickness: 1,
                        height: 1,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'support@yummy.app',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutFeature {
  final String title;
  final String subtitle;
  final String imagePath;

  const _AboutFeature({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });

  static const items = <_AboutFeature>[
    _AboutFeature(
      title: 'AI Calories',
      subtitle: 'Scan your plate',
      imagePath: 'assets/images/ai cam.png',
    ),
    _AboutFeature(
      title: 'Chef Market',
      subtitle: 'Order from chefs',
      imagePath: 'assets/images/market.png',
    ),
    _AboutFeature(
      title: 'Food Community',
      subtitle: 'Posts & comments',
      imagePath: 'assets/images/comunity.png',
    ),
    _AboutFeature(
      title: 'Ready Recipes',
      subtitle: 'Steps & ingredients',
      imagePath: 'assets/images/recipes.png',
    ),
  ];
}

class _AboutFeatureCard extends StatelessWidget {
  final _AboutFeature feature;

  const _AboutFeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      height: 118,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.deepBlue.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.deepBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Image.asset(
                feature.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_rounded,
                    size: 30,
                    color: AppColors.deepBlue,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.2,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            feature.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.2,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollReveal extends StatelessWidget {
  final ScrollController scrollController;
  final int index;
  final Widget child;

  const _ScrollReveal({
    required this.scrollController,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      child: child,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.offset
            : 0.0;
        final start = index * 160.0;
        final progress = ((offset - start) / 120.0).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(progress);
        final translateY = 24.0 * (1.0 - eased);
        final scale = 0.94 + (0.06 * eased);
        final tilt = 0.012 * (1.0 - eased);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.45,
      size.width * 0.5,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.75,
      size.width,
      size.height * 0.6,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({super.key});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final TextEditingController _controller = TextEditingController();
  String? _statusMessage;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Please write your feedback first.'),
          content: const Text('الرجاء كتابة الملاحظة أولاً.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // send to backend
    _sendToServer(text);
  }

  Future<void> _sendToServer(String text) async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      final token = await AuthService().getToken();

      // try to get user info from provider
      final user = context.read<UserProvider>().user;
      final name =
          user?['name'] as String? ?? await AuthService().getUserName();

      final profile = user?['profile'] as Map<String, dynamic>?;
      final rawAvatar =
          profile?['image_url'] ??
          profile?['image'] ??
          profile?['imageUrl'] ??
          user?['image_url'] ??
          user?['image'] ??
          user?['imageUrl'] ??
          '';

      // Normalize avatar to a relative uploads path so we don't persist host-specific origin
      String avatarPath = (rawAvatar ?? '').toString().trim();
      try {
        final parsed = Uri.parse(avatarPath);
        if (parsed.hasScheme) {
          // Use only the path portion (e.g. /uploads/xyz.jpg)
          avatarPath = parsed.path;
        }
      } catch (_) {}

      if (avatarPath.isNotEmpty && !avatarPath.startsWith('/')) {
        // if it contains uploads but missing leading slash, add it
        if (avatarPath.contains('uploads')) {
          avatarPath = '/$avatarPath';
        }
      }

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // robustly build feedback URI whether baseUrl contains /api or not
      final base = AppConfig.baseUrl;
      final feedbackPath = base.endsWith('/api')
          ? '$base/feedback'
          : '$base/api/feedback';
      final uri = Uri.parse(feedbackPath);

      final body = jsonEncode({
        'message': text,
        'name': name,
        'avatar': avatarPath,
      });

      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(AppConfig.requestTimeout);

      if (resp.statusCode == 201) {
        setState(() {
          _statusMessage = 'Thank you for your feedback!';
        });
        _controller.clear();
      } else {
        // try to show server message if exists
        String serverMsg = '';
        try {
          final parsed = jsonDecode(resp.body) as Map<String, dynamic>?;
          serverMsg = parsed?['message']?.toString() ?? '';
        } catch (_) {}

        setState(() {
          _statusMessage =
              'Failed to send feedback (${resp.statusCode})${serverMsg.isNotEmpty ? ': $serverMsg' : ''}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending feedback: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.royalBlue, AppColors.deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "We'd love your feedback",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us what you think about Yummy and how we can improve your experience.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Frosted glass TextField
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white.withOpacity(0.06),
                child: TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Write your feedback...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // status message inside the card
          if (_statusMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.deepBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSending ? null : _send,
              child: _isSending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(AppColors.deepBlue),
                      ),
                    )
                  : const Text('Send Feedback'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureImageCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const _FeatureImageCard({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.deepBlue, AppColors.royalBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
