import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/screen/page_chef_screen/chef_main_screen.dart'
    as chef_main;
import 'package:frontend/features/screen/page_admin_screen/admin_dashboard_screen.dart'
    as admin_dash;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/welcome_screen.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    /// Animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    /// Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    /// Scale animation
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    Timer(const Duration(seconds: 5), () async {
      final authProvider = context.read<AuthProvider>();

      // Wait a bit for AuthProvider.initialize() to finish.
      // Without this, a cold restart can navigate before the saved token is read.
      const maxWait = Duration(seconds: 3);
      final start = DateTime.now();
      while (authProvider.status == AuthStatus.unknown &&
          DateTime.now().difference(start) < maxWait) {
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final prefs = await SharedPreferences.getInstance();
      String? role = prefs.getString('userRole');

      final hasToken =
          (prefs.getString('token'))?.trim().isNotEmpty ?? false;

      if (authProvider.isAuthenticated &&
          (role == null || role.trim().isEmpty)) {
        await context.read<UserProvider>().fetchUser();
        role = context
            .read<UserProvider>()
            .user?['role']
            ?.toString()
            .toLowerCase();
      }

      // If provider hasn't flipped yet but the token exists, trust the stored role.
      final isLoggedIn = authProvider.isAuthenticated || hasToken;

      if (!mounted) return;

      Widget destination;

      if (!isLoggedIn) {
        destination = const WelcomeScreen();
      } else if (role == 'chef') {
        destination = const chef_main.ChefMainScreen();
      } else if (role == 'admin') {
        destination = const admin_dash.AdminDashboardScreen();
      } else {
        destination = const HomeScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// الخلفية navy
      backgroundColor: AppColors.navy,

      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/images/logo_white.png", width: 300),

                SizedBox(
                  width: 310,
                  height: 110,
                  child: Lottie.asset("assets/lottie/Loading Dots Blue.json"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
