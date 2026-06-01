import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/glass_text_field.dart';
import '../../../shared/app_background.dart';
import '../../../shared/back_button_widget.dart';
import 'package:frontend/features/auth/sign_up_account_screen.dart';
import 'package:frontend/features/auth/forgot_password_screen.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/screen/page_admin_screen/admin_dashboard_screen.dart';
import 'package:frontend/features/screen/page_chef_screen/chef_main_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;

  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    _loadRememberMePreference();
  }

  Future<void> _loadRememberMePreference() async {
    final savedValue = context.read<AuthProvider>().rememberMe;

    if (!mounted) return;

    setState(() {
      _rememberMe = savedValue;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    debugPrint("SHOW ERROR => $message");

    if (!mounted) return;

    setState(() {
      _errorMessage = message;
      _loading = false;
    });

    _shakeController.forward(from: 0);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email");
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      _showError("Please enter a valid email address");
      return;
    }

    if (pass.isEmpty) {
      _showError("Please enter your password");
      return;
    }

    if (pass.length < 8) {
      _showError("Password must be at least 8 characters");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      final result = await authProvider.login(
        email: email,
        password: pass,
        rememberMe: _rememberMe,
      );

      debugPrint("FULL LOGIN RESULT => $result");

      if (!mounted) return;

      final bool success = result['success'] == true;

      if (!success) {
        _showError(result['message']?.toString() ?? 'Login failed');
        return;
      }

      final resultData = result['data'];
      final resultUser = result['user'] ?? resultData?['user'];

      final resultUserId =
          result['userId'] ??
          resultData?['userId'] ??
          resultUser?['id'] ??
          resultUser?['_id'];

      if (resultUserId == null || resultUserId.toString().trim().isEmpty) {
        _showError(result['message']?.toString() ?? 'Login failed');
        return;
      }

      await userProvider.fetchUser();

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();

      final prefRole = prefs.getString('userRole');

      final role =
          (resultUser?['role'] ??
                  result['role'] ??
                  resultData?['role'] ??
                  userProvider.user?['role'] ??
                  prefRole ??
                  'user')
              .toString()
              .toLowerCase();

      await prefs.setString('userRole', role);

      final chefId =
          (resultUser?['chefId'] ??
                  result['chefId'] ??
                  resultData?['chefId'] ??
                  userProvider.user?['chefId'] ??
                  prefs.getString('chefId'))
              ?.toString();

      if (chefId != null && chefId.trim().isNotEmpty) {
        await prefs.setString('chefId', chefId);
      }

      debugPrint("LOGIN ROLE => $role");
      debugPrint("FETCHED USER => ${userProvider.user}");

      Widget destination;

      switch (role) {
        case 'admin':
          destination = const AdminDashboardScreen();
          break;

        case 'chef':
          destination = const ChefMainScreen();
          break;

        default:
          destination = const HomeScreen();
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      debugPrint("LOGIN ERROR => $e");
      _showError("Something went wrong");
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: h * 0.03),

                const Row(children: [AppBackButton()]),

                const SizedBox(height: 20),

                const Text(
                  "Welcome Back to Yummy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Track your meals. Stay healthy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark.withOpacity(0.60),
                  ),
                ),

                const SizedBox(height: 22),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB3B3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFD93025),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD93025),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GlassTextField(
                          label: "",
                          hint: "example@mail.com",
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          validator: (v) => null,
                        ),

                        GlassTextField(
                          label: "",
                          hint: "••••••••",
                          controller: _passCtrl,
                          keyboardType: TextInputType.visiblePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscure = !_obscure;
                              });
                            },
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          validator: (v) => null,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.navy,
                              onChanged: (v) {
                                setState(() {
                                  _rememberMe = v ?? true;
                                });
                              },
                            ),

                            Text(
                              "Remember me",
                              style: TextStyle(
                                color: AppColors.darkBlue.withOpacity(0.85),
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const Spacer(),

                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot password?",
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor: AppColors.navy,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Log In",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(
                        color: AppColors.dark.withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpAccountScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
