import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/glass_text_field.dart';
import '../../../shared/app_background.dart';
import '../../../shared/back_button_widget.dart';
import 'package:frontend/features/auth/signup_flow_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

class SignUpAccountScreen extends StatefulWidget {
  const SignUpAccountScreen({super.key});

  @override
  State<SignUpAccountScreen> createState() => _SignUpAccountScreenState();
}

class _SignUpAccountScreenState extends State<SignUpAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
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
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _loading = false;
    });
    _shakeController.forward(from: 0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email");
      return;
    }

    // Proper email validation using regex
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

    if (confirm.isEmpty) {
      _showError("Please confirm your password");
      return;
    }

    if (confirm != pass) {
      _showError("Passwords do not match");
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await context.read<AuthProvider>().register(
        email: email,
        password: pass,
      );

      if (!mounted) return;

      if (result['userId'] == null) {
        _showError(result['message'] ?? 'Registration failed');
        return;
      }

      setState(() => _loading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignUpFlowScreen(userId: result['userId']),
        ),
      );
    } catch (e) {
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
                  "Create Your Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sign up to start tracking your meals",
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFD93025),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD93025),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
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
                          validator: (v) {
                            final value = (v ?? "").trim();
                            if (value.isEmpty) return "";
                            if (!value.contains("@")) return "";
                            return null;
                          },
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
                          validator: (v) {
                            final value = (v ?? "").trim();
                            if (value.isEmpty) return "";
                            if (value.length < 6) return "";
                            return null;
                          },
                        ),
                        GlassTextField(
                          label: "",
                          hint: "Confirm password",
                          controller: _confirmCtrl,
                          keyboardType: TextInputType.visiblePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? "").trim();
                            if (value.isEmpty) return "";
                            if (value != _passCtrl.text.trim()) return "";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor: AppColors.navy,
                              disabledForegroundColor: Colors.white,
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
                                    "Create Account",
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
                      "Already have an account? ",
                      style: TextStyle(
                        color: AppColors.dark.withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Log In",
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
