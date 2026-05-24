import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/app_branding_service.dart';
import '../../core/theme/app_colors.dart';

import '../home/home_screen.dart';
import '../screen/page_chef_screen/chef_main_screen.dart' as chef_main;
import '../screen/page_admin_screen/admin_dashboard_screen.dart' as admin_dash;
import 'welcome_screen.dart';

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

    _initializeBranding();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    _startNavigationTimer();
  }

  Future<void> _initializeBranding() async {
    await AppBrandingService.loadBranding();

    if (!mounted) return;

    setState(() {});
  }

  void _startNavigationTimer() {
    Timer(const Duration(seconds: 5), () async {
      final authProvider = context.read<AuthProvider>();

      // Wait for AuthProvider.initialize() to finish
      const maxWait = Duration(seconds: 3);
      final start = DateTime.now();

      while (authProvider.status == AuthStatus.unknown &&
          DateTime.now().difference(start) < maxWait) {
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final prefs = await SharedPreferences.getInstance();

      String? role = prefs.getString('userRole');

      final hasToken =
          prefs.getString('token')?.trim().isNotEmpty ?? false;

      if (authProvider.isAuthenticated &&
          (role == null || role.trim().isEmpty)) {
        await context.read<UserProvider>().fetchUser();

        role = context
            .read<UserProvider>()
            .user?['role']
            ?.toString()
            .toLowerCase();
      }

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
        MaterialPageRoute(
          builder: (_) => destination,
        ),
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
      backgroundColor: AppColors.navy,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppBrandingService.currentLogo,
                  width: 300,
                ),
                SizedBox(
                  width: 310,
                  height: 110,
                  child: Lottie.asset(
                    "assets/lottie/Loading Dots Blue.json",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}