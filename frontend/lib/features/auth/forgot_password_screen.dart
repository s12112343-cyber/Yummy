import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/app_background.dart';
import '../../../shared/glass_text_field.dart';
import '../../../shared/back_button_widget.dart';
import '../../../core/services/auth_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final List<TextEditingController> _codeCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _errorMessage;

  int _step = 0;
  // 0 = email
  // 1 = verify code
  // 2 = reset password

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _resendTimer?.cancel();
    for (final c in _codeCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _codeCtrls.map((e) => e.text).join();

  void _showError(String message) {
    setState(() {
      _loading = false;
      _errorMessage = message;
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return _SuccessDialog();
      },
    );
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();

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

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.sendResetCode(email: email);

      if (!mounted) return;

      final statusCode = result['statusCode'] as int?;

      if (statusCode == 404) {
        _showError("Email not found");
        return;
      }

      if (statusCode != 200) {
        _showError(result['message'] ?? "Failed to send code");
        return;
      }

      setState(() {
        _loading = false;
        _step = 1;
      });

      _startResendTimer();
    } catch (e) {
      _showError("Something went wrong");
    }
  }

  Future<void> _verifyCode() async {
    if (_enteredCode.length != 4 || _enteredCode.contains(RegExp(r'[^0-9]'))) {
      _showError("Please enter the 4-digit code");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.verifyResetCode(
        email: _emailCtrl.text.trim(),
        code: _enteredCode,
      );

      if (!mounted) return;

      final statusCode = result['statusCode'] as int?;

      if (statusCode != 200) {
        _showError(result['message'] ?? "Invalid verification code");
        return;
      }

      setState(() {
        _loading = false;
        _step = 2;
      });
    } catch (e) {
      _showError("Something went wrong");
    }
  }

  Future<void> _resetPassword() async {
    final pass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (pass.isEmpty) {
      _showError("Please enter your new password");
      return;
    }

    if (pass.length < 8) {
      _showError("Password must be at least 8 characters");
      return;
    }

    if (confirm.isEmpty) {
      _showError("Please confirm your new password");
      return;
    }

    if (pass != confirm) {
      _showError("Passwords do not match");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.resetPassword(
        email: _emailCtrl.text.trim(),
        newPassword: pass,
      );

      if (!mounted) return;

      final statusCode = result['statusCode'] as int?;

      if (statusCode != 200) {
        _showError(result['message'] ?? "Failed to reset password");
        return;
      }

      setState(() => _loading = false);

      _showSuccessDialog();
    } catch (e) {
      _showError("Something went wrong");
    }
  }

  Future<void> _resendCode() async {
    try {
      final result = await _authService.sendResetCode(
        email: _emailCtrl.text.trim(),
      );

      if (!mounted) return;

      final statusCode = result['statusCode'] as int?;

      if (statusCode == 404) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email not found")));
        return;
      }

      if (statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Failed to resend code")),
        );
        return;
      }

      _startResendTimer();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  String _title() {
    if (_step == 0) return "Forgot Password";
    if (_step == 1) return "Verify Code";
    return "Create New Password";
  }

  String _subtitle() {
    if (_step == 0) {
      return "Enter your email and we’ll send you a verification code.";
    }
    if (_step == 1) {
      return "Enter the 4-digit code sent to\n${_emailCtrl.text.trim()}";
    }
    return "Create a new password for\nyour account.";
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
                Row(
                  children: [
                    AppBackButton(
                      onTap: () {
                        if (_step == 0) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            _errorMessage = null;
                            _loading = false;
                            _step--;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _title(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle(),
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
                          Icons.error_outline_rounded,
                          color: Color(0xFFD93025),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD93025),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _step == 0
                      ? _EmailStep(
                          key: const ValueKey("email"),
                          emailCtrl: _emailCtrl,
                        )
                      : _step == 1
                      ? _CodeStep(
                          key: const ValueKey("code"),
                          codeCtrls: _codeCtrls,
                          onCodeCompleted: _verifyCode,
                        )
                      : _ResetStep(
                          key: const ValueKey("reset"),
                          newPassCtrl: _newPassCtrl,
                          confirmPassCtrl: _confirmPassCtrl,
                          obscureNew: _obscureNew,
                          obscureConfirm: _obscureConfirm,
                          onToggleNew: () {
                            setState(() => _obscureNew = !_obscureNew);
                          },
                          onToggleConfirm: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : _step == 0
                        ? _sendCode
                        : _step == 1
                        ? _verifyCode
                        : _resetPassword,
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
                        : Text(
                            _step == 0
                                ? "Send Code"
                                : _step == 1
                                ? "Verify"
                                : "Reset Password",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_step == 1)
                  _resendCountdown > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            "Resend code in $_resendCountdown seconds",
                            style: TextStyle(
                              color: AppColors.navy.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _resendCode,
                          child: Text(
                            "Resend Code",
                            style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                if (_step == 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Back to login",
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _EmailStep extends StatelessWidget {
  final TextEditingController emailCtrl;

  const _EmailStep({super.key, required this.emailCtrl});

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      label: "",
      hint: "example@mail.com",
      controller: emailCtrl,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.mail_outline_rounded,
      validator: (_) => null,
    );
  }
}

class _CodeStep extends StatefulWidget {
  final List<TextEditingController> codeCtrls;
  final Future<void> Function() onCodeCompleted;

  const _CodeStep({
    super.key,
    required this.codeCtrls,
    required this.onCodeCompleted,
  });

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  late final List<FocusNode> _focusNodes;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 3) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }

    final isCodeComplete = widget.codeCtrls.every(
      (controller) => controller.text.trim().length == 1,
    );

    if (!isCodeComplete) {
      _hasTriggeredCompletion = false;
      return;
    }

    if (_hasTriggeredCompletion) return;

    _hasTriggeredCompletion = true;
    widget.onCodeCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 65,
              height: 80,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      widget.codeCtrls[index].text.isEmpty &&
                      index > 0) {
                    widget.codeCtrls[index - 1].clear();
                    _hasTriggeredCompletion = false;
                    FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: widget.codeCtrls[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: index == 3
                      ? TextInputAction.done
                      : TextInputAction.next,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                  onChanged: (value) => _onChanged(value, index),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: AppColors.white.withOpacity(0.95),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: AppColors.mediumBlue.withOpacity(0.2),
                        width: 2,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: AppColors.mediumBlue.withOpacity(0.25),
                        width: 2,
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: AppColors.mediumBlue,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetStep extends StatelessWidget {
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final bool obscureNew;
  final bool obscureConfirm;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;

  const _ResetStep({
    super.key,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.onToggleNew,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassTextField(
          label: "",
          hint: "New password",
          controller: newPassCtrl,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscureNew,
          suffix: IconButton(
            onPressed: onToggleNew,
            icon: Icon(
              obscureNew
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          validator: (_) => null,
        ),
        GlassTextField(
          label: "",
          hint: "Confirm new password",
          controller: confirmPassCtrl,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscureConfirm,
          suffix: IconButton(
            onPressed: onToggleConfirm,
            icon: Icon(
              obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          validator: (_) => null,
        ),
      ],
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog();

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.5, end: 0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
        );

    Future.microtask(() {
      _scaleController.forward();
      _rotateController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.successPrimary.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _rotateAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: Lottie.asset(
                        'assets/lottie/true.json',
                        fit: BoxFit.contain,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.successPrimary,
                            size: 70,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                const Text(
                  "Password Updated",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                const Text(
                  "Your password has been changed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      shadowColor: AppColors.navy.withOpacity(0.35),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      "Back to Login",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
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
}
