import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/user_provider.dart';
import '../../core/services/gemini_chat_service.dart';
import '../../core/theme/app_colors.dart';

class GeminiChatScreen extends StatefulWidget {
  const GeminiChatScreen({super.key});

  @override
  State<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  static const String _chatHistoryKey = 'gemini_chat_history';

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_chatHistoryKey);

    if (!mounted) return;

    if (rawHistory == null || rawHistory.trim().isEmpty) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text':
              'Hello! I\'m Yummy AI. Ask me about recipes, ingredients, or nutrition.',
        });
      });
      return;
    }

    try {
      final decoded = jsonDecode(rawHistory);
      if (decoded is List) {
        final restoredMessages = decoded
            .whereType<Map>()
            .map(
              (item) => {
                'role': item['role']?.toString() ?? 'assistant',
                'text': item['text']?.toString() ?? '',
              },
            )
            .where((item) => item['text']!.trim().isNotEmpty)
            .toList();

        setState(() {
          _messages
            ..clear()
            ..addAll(restoredMessages);
        });
      }
    } catch (e) {
      debugPrint('Failed to load Gemini chat history: $e');
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..add({
            'role': 'assistant',
            'text':
                'Hello! I\'m Yummy AI. Ask me about recipes, ingredients, or nutrition.',
          });
      });
      await _saveChatHistory();
    }

    _scrollToBottom();
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatHistoryKey, jsonEncode(_messages));
  }

  Future<void> _clearChatHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear chat?'),
          content: const Text(
            'This will delete the whole conversation on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);

    if (!mounted) return;

    setState(() {
      _messages.clear();
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isSending = true;
    });
    await _saveChatHistory();

    _controller.clear();
    _scrollToBottom();

    try {
      final userProfileContext = _buildUserProfileContext(
        context.read<UserProvider>().user,
      );

      final reply = await GeminiChatService.sendMessage(
        userMessage: text,
        history: _messages,
        userProfileContext: userProfileContext,
      );

      if (!mounted) return;

      setState(() {
        _messages.add({'role': 'assistant', 'text': reply});
      });
      await _saveChatHistory();
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      debugPrint('Gemini chat error: $errorText');

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': errorText.contains('Gemini request failed')
              ? 'Gemini API error. Check the key, model access, or quota.\n\n$errorText'
              : 'Sorry, I could not answer right now. Please try again.',
        });
      });
      await _saveChatHistory();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  String _buildUserProfileContext(Map<String, dynamic>? user) {
    if (user == null) return '';

    final name = (user['name'] ?? '').toString().trim();
    final profile = user['profile'] as Map<String, dynamic>? ?? {};
    final height = profile['height'] as Map<String, dynamic>? ?? {};
    final weight = profile['weight'] as Map<String, dynamic>? ?? {};

    final allergies = (profile['allergies'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    final medicalConditions =
        (profile['medical_conditions'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();

    final birthDate = _safeParseDate(profile['date_of_birth']);
    final age = birthDate == null ? null : _calculateAge(birthDate);
    final heightCm = _extractHeightCm(height);
    final weightKg = _extractWeightKg(weight);

    final bmi = (heightCm != null && weightKg != null && heightCm > 0)
        ? (weightKg / ((heightCm / 100) * (heightCm / 100)))
        : null;

    final estimatedCalories =
        (weightKg != null && heightCm != null && age != null)
        ? _estimateDailyCalories(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: (profile['gender'] ?? '').toString(),
            activityLevel: (profile['activity_level'] ?? '').toString(),
            goal: (profile['goal'] ?? '').toString(),
          )
        : null;

    final lines = <String>[];

    if (name.isNotEmpty) lines.add('Name: $name');

    if ((profile['goal'] ?? '').toString().trim().isNotEmpty) {
      lines.add('Goal: ${profile['goal']}');
    }

    if ((profile['gender'] ?? '').toString().trim().isNotEmpty) {
      lines.add('Gender: ${profile['gender']}');
    }

    if ((profile['date_of_birth'] ?? '').toString().trim().isNotEmpty) {
      lines.add('Date of birth: ${profile['date_of_birth']}');
    }

    if (age != null) {
      lines.add('Age: $age years');
    }

    if ((height['value'] ?? '').toString().trim().isNotEmpty ||
        (height['unit'] ?? '').toString().trim().isNotEmpty) {
      lines.add(
        'Height: ${(height['value'] ?? '').toString()} ${(height['unit'] ?? '').toString()}'
            .trim(),
      );
    }

    if (heightCm != null) {
      lines.add('Height (cm): ${heightCm.toStringAsFixed(1)}');
    }

    if ((weight['value'] ?? '').toString().trim().isNotEmpty ||
        (weight['unit'] ?? '').toString().trim().isNotEmpty) {
      lines.add(
        'Weight: ${(weight['value'] ?? '').toString()} ${(weight['unit'] ?? '').toString()}'
            .trim(),
      );
    }

    if (weightKg != null) {
      lines.add('Weight (kg): ${weightKg.toStringAsFixed(1)}');
    }

    if (bmi != null) {
      lines.add('BMI: ${bmi.toStringAsFixed(1)}');
    }

    if (estimatedCalories != null) {
      lines.add(
        'Estimated daily calorie target: ${estimatedCalories.toStringAsFixed(0)} kcal/day',
      );
    }

    if ((profile['activity_level'] ?? '').toString().trim().isNotEmpty) {
      lines.add('Activity level: ${profile['activity_level']}');
    }

    if (allergies.isNotEmpty) {
      lines.add('Allergies: ${allergies.join(', ')}');
    }

    if (medicalConditions.isNotEmpty) {
      lines.add('Medical conditions: ${medicalConditions.join(', ')}');
    }

    if (lines.isEmpty) return '';

    return lines.join('\n');
  }

  DateTime? _safeParseDate(dynamic value) {
    if (value == null) return null;

    try {
      final parsed = DateTime.parse(value.toString());
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age < 0 ? 0 : age;
  }

  double? _extractHeightCm(Map<String, dynamic> height) {
    final rawValue = height['value'];
    final unit = (height['unit'] ?? 'cm').toString().toLowerCase();
    final value = double.tryParse(rawValue?.toString() ?? '');

    if (value == null) return null;

    if (unit.contains('in')) {
      return value * 2.54;
    }

    return value;
  }

  double? _extractWeightKg(Map<String, dynamic> weight) {
    final rawValue = weight['value'];
    final unit = (weight['unit'] ?? 'kg').toString().toLowerCase();
    final value = double.tryParse(rawValue?.toString() ?? '');

    if (value == null) return null;

    if (unit.contains('lb')) {
      return value * 0.45359237;
    }

    return value;
  }

  double _activityFactor(String activityLevel) {
    switch (activityLevel.trim().toLowerCase()) {
      case 'sedentary':
        return 1.2;
      case 'lightly_active':
        return 1.375;
      case 'moderately_active':
        return 1.55;
      case 'very_active':
        return 1.725;
      default:
        return 1.2;
    }
  }

  double _goalAdjustment(String goal) {
    switch (goal.trim().toLowerCase()) {
      case 'lose_weight':
        return -300;
      case 'gain_weight':
        return 300;
      case 'stay_healthy':
      default:
        return 0;
    }
  }

  double? _estimateDailyCalories({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) {
    final isFemale = gender.trim().toLowerCase() == 'female';

    final bmr = isFemale
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;

    final tdee = bmr * _activityFactor(activityLevel);
    final target = tdee + _goalAdjustment(goal);

    return target.isFinite && target > 0 ? target : null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildMessageBubble({
    required Map<String, String> message,
    required int index,
  }) {
    final isUser = message['role'] == 'user';

    return TweenAnimationBuilder<double>(
      key: ValueKey('${index}_${message['role']}_${message['text']}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.deepBlue.withOpacity(0.95),
                      AppColors.deepBlue.withOpacity(0.72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepBlue.withOpacity(0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [
                            AppColors.deepBlue,
                            AppColors.deepBlue.withOpacity(0.86),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUser ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isUser ? 22 : 7),
                    bottomRight: Radius.circular(isUser ? 7 : 22),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: const Color(0xFFEAF0F8), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? AppColors.deepBlue.withOpacity(0.17)
                          : Colors.black.withOpacity(0.045),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _buildFormattedMessageText(
                  message['text'] ?? '',
                  isUser: isUser,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedMessageText(String text, {required bool isUser}) {
    final baseStyle = TextStyle(
      color: isUser ? Colors.white : const Color(0xFF1F2A44),
      fontSize: 14.2,
      height: 1.42,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      TextSpan(style: baseStyle, children: _buildTextSpans(text, baseStyle)),
      softWrap: true,
    );
  }

  List<TextSpan> _buildTextSpans(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
    var currentIndex = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }

      final boldText = match.group(1) ?? match.group(2) ?? '';
      spans.add(
        TextSpan(
          text: boldText,
          style: baseStyle.copyWith(fontWeight: FontWeight.w900),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.deepBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomRight: Radius.circular(22),
                bottomLeft: Radius.circular(7),
              ),
              border: Border.all(color: const Color(0xFFEAF0F8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6EDF7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2A44),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about meals, calories, recipes...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: _isSending ? 0.92 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isSending ? null : _sendMessage,
                  child: Ink(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.deepBlue,
                          AppColors.deepBlue.withOpacity(0.80),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepBlue.withOpacity(0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _isSending
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                key: ValueKey('send'),
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 23,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _messages.length + (_isSending ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.deepBlue,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Yummy AI',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: 0.1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearChatHistory,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFEFF5FC), Color(0xFFF9FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  itemCount: totalItems,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) {
                    if (_isSending && index == totalItems - 1) {
                      return _buildTypingBubble();
                    }

                    final message = _messages[index];

                    return _buildMessageBubble(message: message, index: index);
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value + (index * 0.22)) % 1;
        final scale = value < 0.5 ? 0.7 + value : 1.2 - value;

        return Transform.scale(scale: scale.clamp(0.7, 1.0), child: child);
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.deepBlue.withOpacity(0.72),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_dot(0), _dot(1), _dot(2)],
      ),
    );
  }
}
