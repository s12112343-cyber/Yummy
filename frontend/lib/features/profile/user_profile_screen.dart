import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/providers/like_provider.dart';
import '../../core/providers/follow_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import 'personal_details_screen.dart';
import 'followers_following_screen.dart';
import 'chat_screen.dart';
import 'user_conversations_screen.dart';
import '../../shared/app_sidebar.dart';
import '../../shared/bell_with_badge.dart';

class UserProfileScreen extends StatefulWidget {
  final String? viewedUserId;
  final String? viewedUserName;
  final String? viewedUserImageUrl;

  const UserProfileScreen({
    super.key,
    this.viewedUserId,
    this.viewedUserName,
    this.viewedUserImageUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();

  int _followers = 0;
  int _following = 0;
  bool _isLoadingMyPosts = false;
  bool _isUploadingImage = false;
  File? _selectedImageFile;
  String? _lastLoadedForUser;
  final ImagePicker _picker = ImagePicker();

  final List<_ProfileMediaItem> _posts = [];
  bool _showGrid = false;
  bool _isFollowingViewedUser = false;
  String? _sessionUserId;
  List<Map<String, dynamic>> _hiddenUsers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionUserId = await _authService.getUserId();
    });
  }

  String _currentUserId() {
    final user = context.read<UserProvider>().user;
    return (user?['_id']?.toString() ??
            user?['id']?.toString() ??
            user?['userId']?.toString() ??
            _sessionUserId ??
            '')
        .trim();
  }

  String _currentUserName() {
    final user = context.read<UserProvider>().user;
    return (user?['name']?.toString() ?? '').trim();
  }

  bool get _isViewingOtherUser {
    final currentUserId = _currentUserId();
    final currentUserName = _currentUserName().toLowerCase();
    final userId = widget.viewedUserId?.trim() ?? '';
    final name = widget.viewedUserName?.trim() ?? '';

    if (userId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        userId == currentUserId) {
      return false;
    }

    if (name.isNotEmpty &&
        currentUserName.isNotEmpty &&
        name.toLowerCase() == currentUserName) {
      return false;
    }

    return userId.isNotEmpty || name.isNotEmpty;
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year;
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = context.read<UserProvider>().user;
    final viewedUserId = (widget.viewedUserId ?? '').trim();
    final viewedName = (widget.viewedUserName ?? '').trim();

    if (viewedUserId.isNotEmpty || viewedName.isNotEmpty) {
      final identityKey = viewedUserId.isNotEmpty
          ? 'id:$viewedUserId'
          : 'name:$viewedName';

      if (_lastLoadedForUser != identityKey) {
        _lastLoadedForUser = identityKey;
        _loadMyPosts(userId: viewedUserId, fullName: viewedName);
        _loadFollowStats(viewedUserId);
      }
      return;
    }

    final userId = _currentUserId();
    final fullName = (user?['name']?.toString() ?? '').trim();
    final identityKey = userId.isNotEmpty
        ? 'id:$userId'
        : (fullName.isNotEmpty ? 'name:$fullName' : '');

    if (identityKey.isNotEmpty && _lastLoadedForUser != identityKey) {
      _lastLoadedForUser = identityKey;
      _loadMyPosts(userId: userId, fullName: fullName);
      _loadFollowStats(userId);
      _loadHiddenUsers();

      try {
        context.read<LikeProvider>().addListener(_syncLikesFromProvider);
      } catch (_) {}
    }
  }

  Future<void> _loadHiddenUsers() async {
    try {
      final hiddenRaw = await _authService.getHiddenUsers();
      if (!mounted) return;

      setState(() {
        _hiddenUsers = hiddenRaw
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where(
              (m) => ((m['id'] ?? m['_id'] ?? '').toString().trim()).isNotEmpty,
            )
            .toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _unhideUserById(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      await _authService.unhideUser(userId);
    } catch (_) {}

    await _loadHiddenUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User unhidden')));
  }

  @override
  void dispose() {
    try {
      context.read<LikeProvider>().removeListener(_syncLikesFromProvider);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadFollowStats(String userId) async {
    if (userId.isEmpty) return;
    if (!mounted) return;

    final followProvider = context.read<FollowProvider>();

    try {
      await followProvider.fetchUserStats(userId: userId);
    } catch (_) {}

    try {
      await followProvider.checkFollowStatus(targetUserId: userId);
    } catch (_) {}

    if (!mounted) return;

    final followers = followProvider.getFollowerCount(userId);
    final following = followProvider.getFollowingCount(userId);
    final isFollowing = followProvider.isFollowing(userId);

    setState(() {
      _followers = followers;
      _following = following;
      _isFollowingViewedUser = isFollowing;
    });
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();

    if (!_isViewingOtherUser) {
      await userProvider.fetchUser();
    }

    final user = userProvider.user;
    final targetUserId = _isViewingOtherUser
        ? (widget.viewedUserId ?? '').trim()
        : (user?['_id']?.toString() ??
                  user?['id']?.toString() ??
                  user?['userId']?.toString() ??
                  _sessionUserId ??
                  '')
              .trim();

    final targetUserName = _isViewingOtherUser
        ? (widget.viewedUserName ?? '').trim()
        : (user?['name']?.toString() ?? '').trim();

    if (!mounted) return;

    if (targetUserId.isNotEmpty || targetUserName.isNotEmpty) {
      await _loadMyPosts(userId: targetUserId, fullName: targetUserName);
    }

    if (targetUserId.isNotEmpty) {
      await _loadFollowStats(targetUserId);
    }
  }

  Future<void> _loadMyPosts({
    required String userId,
    required String fullName,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingMyPosts = true;
    });

    final response = await _authService.getPosts();
    final postsRaw = response['posts'] as List<dynamic>? ?? [];

    final normalizedName = fullName.toLowerCase();
    final normalizedUserId = userId.toLowerCase();

    final myPosts = postsRaw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((post) {
          final postAuthorId =
              (post['authorId']?.toString().trim().toLowerCase() ?? '');

          if (normalizedUserId.isNotEmpty && postAuthorId.isNotEmpty) {
            return postAuthorId == normalizedUserId;
          }

          return (post['authorName']?.toString().trim().toLowerCase() ?? '') ==
              normalizedName;
        })
        .map((post) {
          final commentsRaw = (post['comments'] as List<dynamic>? ?? []);
          final comments = commentsRaw
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map(
                (c) => _ProfileComment(
                  authorName: c['authorName']?.toString() ?? 'User',
                  authorImageUrl: _resolveImageUrl(c['authorImageUrl']),
                  text: c['text']?.toString() ?? '',
                  createdAt:
                      DateTime.tryParse(c['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              )
              .toList();

          return _ProfileMediaItem(
            id:
                post['_id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            imageUrl: _resolveImageUrl(post['imagePath']) ?? '',
            caption: post['text']?.toString() ?? '',
            likeCount: (post['likedByUsers'] as List<dynamic>?)?.length ?? 0,
            likes:
                (post['likedByUsers'] as List<dynamic>?)
                    ?.map(
                      (item) => _LikeItem(
                        id: item.toString(),
                        name: 'User',
                        imageUrl: null,
                      ),
                    )
                    .toList() ??
                <_LikeItem>[],
            likedByUsers:
                (post['likedByUsers'] as List<dynamic>?)
                    ?.map((item) => item.toString())
                    .toSet() ??
                <String>{},
            likedByDetails: const [],
            comments: comments,
            publishedAt:
                DateTime.tryParse(post['publishedAt']?.toString() ?? '') ??
                DateTime.now(),
            isVideo: false,
            calories: (post['calories'] as num?)?.toDouble(),
            fat: (post['fat'] as num?)?.toDouble(),
            carbs: (post['carbs'] as num?)?.toDouble(),
            protein: (post['protein'] as num?)?.toDouble(),
          );
        })
        .toList();

    if (!mounted) return;

    setState(() {
      _posts
        ..clear()
        ..addAll(myPosts);
      _isLoadingMyPosts = false;
    });
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts.first.characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? '${baseUri.host}:${baseUri.port}'
        : baseUri.host;
    final origin = '${baseUri.scheme}://$authority';

    if (raw.startsWith('/')) {
      return '$origin$raw';
    }

    return '$origin/$raw';
  }

  String? _extractUserImageUrl(Map<String, dynamic>? user) {
    final profile = user?['profile'] as Map<String, dynamic>?;
    final rawImageValue =
        profile?['image_url'] ??
        profile?['image'] ??
        profile?['imageUrl'] ??
        user?['image_url'] ??
        user?['image'] ??
        user?['imageUrl'];

    return _resolveImageUrl(rawImageValue);
  }

  List<String> _listFromDynamic(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).toList();
  }

  int _intFromDynamic(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _doubleFromDynamic(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DEE8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _imageOption(
                        icon: Icons.photo_library_rounded,
                        title: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _imageOption(
                        icon: Icons.camera_alt_rounded,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      final imageFile = File(pickedFile.path);

      setState(() {
        _selectedImageFile = imageFile;
      });

      await _uploadProfileImage(imageFile);
    } catch (_) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not pick image')));
      }
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final profile = user['profile'] as Map<String, dynamic>? ?? {};
    final height = profile['height'] as Map<String, dynamic>? ?? {};
    final weight = profile['weight'] as Map<String, dynamic>? ?? {};

    setState(() {
      _isUploadingImage = true;
    });

    final response = await userProvider.saveProfile(
      name: (user['name']?.toString() ?? '').trim(),
      email: user['email']?.toString(),
      imageFile: imageFile,
      goal: profile['goal']?.toString() ?? 'stay_healthy',
      gender: profile['gender']?.toString() ?? 'male',
      dateOfBirth:
          profile['date_of_birth']?.toString() ??
          DateTime(2000, 1, 1).toIso8601String(),
      heightValue: _intFromDynamic(height['value'], fallback: 170),
      heightUnit: height['unit']?.toString() ?? 'cm',
      weightValue: _doubleFromDynamic(weight['value'], fallback: 70),
      weightUnit: weight['unit']?.toString() ?? 'kg',
      activityLevel: profile['activity_level']?.toString() ?? 'sedentary',
      allergies: _listFromDynamic(profile['allergies']),
      medicalConditions: _listFromDynamic(profile['medical_conditions']),
    );

    if (!mounted) return;

    setState(() {
      _isUploadingImage = false;
    });

    if (response['error'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ?? 'Failed to update image',
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile image updated')));
    }
  }

  Widget _imageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E8F2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 31, color: AppColors.deepBlue),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    final fullName =
        (widget.viewedUserName ?? user?['name']?.toString() ?? 'yummy user')
            .trim();

    final username = _isViewingOtherUser
        ? fullName.replaceAll(' ', '').toLowerCase()
        : (user?['email']?.toString() ?? 'yummy.user')
              .split('@')
              .first
              .replaceAll(' ', '')
              .toLowerCase();

    const defaultBio = '';
    final bio = defaultBio;

    final userImageUrl =
        _resolveImageUrl(widget.viewedUserImageUrl) ??
        _extractUserImageUrl(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: AppSidebar(
          closeAfterSelect: true,
          showProfileSection: false,
          hiddenUsersSection: _buildHiddenUsersSidebarSection(
            closeAfterSelect: true,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = RefreshIndicator(
            color: AppColors.deepBlue,
            onRefresh: _refreshProfile,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  foregroundColor: AppColors.deepBlue,
                  elevation: 0,
                  titleSpacing: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  actions: [
                    if (!_isViewingOtherUser) BellWithBadge(),
                    if (_isViewingOtherUser)
                      PopupMenuButton<String>(
                        tooltip: 'More options',
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.deepBlue,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) async {
                          if (value == 'hide') {
                            final hidden = await _hideViewedUser();
                            if (hidden && mounted) {
                              Navigator.pop(context, true);
                            }
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'hide',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Hide User'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _buildHeader(
                    context: context,
                    fullName: fullName,
                    bio: bio,
                    avatarUrl: userImageUrl,
                  ),
                ),
                SliverToBoxAdapter(child: _buildViewToggle()),
                if (_isLoadingMyPosts)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.deepBlue,
                      ),
                    ),
                  )
                else if (_posts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyPostsView(
                      isViewingOtherUser: _isViewingOtherUser,
                    ),
                  )
                else
                  _showGrid
                      ? SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: 1,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = _posts[index];
                              return _buildPostTile(item);
                            }, childCount: _posts.length),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = _posts[index];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                10,
                              ),
                              child: _buildPostListItem(
                                item,
                                userName: fullName,
                                userImageUrl: userImageUrl,
                              ),
                            );
                          }, childCount: _posts.length),
                        ),
              ],
            ),
          );

          if (constraints.maxWidth >= 700) {
            return Row(
              children: [
                Expanded(child: content),
                const VerticalDivider(width: 1, color: Color(0xFFEDEEF0)),
                Container(
                  width: 260,
                  color: Colors.white,
                  child: AppSidebar(
                    showProfileSection: false,
                    hiddenUsersSection: _buildHiddenUsersSidebarSection(
                      closeAfterSelect: false,
                    ),
                  ),
                ),
              ],
            );
          }

          return content;
        },
      ),
    );
  }

  Future<bool> _hideViewedUser() async {
    final viewedUserId = (widget.viewedUserId ?? '').trim();
    final viewedUserName = (widget.viewedUserName ?? 'User').trim();
    final viewedUserImageUrl = (widget.viewedUserImageUrl ?? '').trim();

    if (viewedUserId.isEmpty) return false;

    await _authService.hideUser(
      userId: viewedUserId,
      name: viewedUserName,
      imageUrl: viewedUserImageUrl,
    );

    return true;
  }

  Widget _buildHiddenUsersSidebarSection({required bool closeAfterSelect}) {
    final hasHidden = _hiddenUsers.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBF7)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hidden users',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.deepBlue,
          ),
        ),
        subtitle: Text(
          hasHidden ? '1 hidden user' : 'No hidden users yet',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.blueGray,
          ),
        ),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7FD),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.block, size: 18, color: Colors.orange),
        ),
        children: [
          if (!hasHidden)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'No users are hidden right now.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.blueGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hiddenUsers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final u = _hiddenUsers[index];
                final imageUrl = _resolveImageUrl(
                  u['imageUrl'] ?? u['image'] ?? u['image_url'],
                );
                final id = (u['id'] ?? u['_id'] ?? '').toString();

                return Material(
                  color: const Color(0xFFF9FBFF),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.babyBlueLight,
                      backgroundImage: (imageUrl != null)
                          ? NetworkImage(imageUrl)
                          : null,
                      child: (imageUrl == null)
                          ? Text(
                              (u['name']?.toString() ?? 'U').toUpperCase()[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepBlue,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      u['name']?.toString() ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B3440),
                      ),
                    ),
                    subtitle: const Text(
                      'Hidden from feed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blueGray,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        if (closeAfterSelect) Navigator.pop(context);
                        await _unhideUserById(id);
                      },
                      child: const Text('Unhide'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required String fullName,
    required String bio,
    required String? avatarUrl,
  }) {
    final avatarProvider = _selectedImageFile != null
        ? FileImage(_selectedImageFile!) as ImageProvider
        : (avatarUrl != null ? NetworkImage(avatarUrl) : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE6ECF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _isViewingOtherUser ? null : _showImageSourceSheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.deepBlue, AppColors.royalBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFEAF2FF),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Text(
                                  _getInitials(fullName),
                                  style: const TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.deepBlue,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (!_isViewingOtherUser)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: GestureDetector(
                            onTap: _showImageSourceSheet,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.deepBlue,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _isUploadingImage
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Posts',
                        value: _formatCount(_posts.length),
                      ),
                      GestureDetector(
                        onTap:
                            !_isViewingOtherUser && _currentUserId().isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: _currentUserId(),
                                      userName: _currentUserName().isNotEmpty
                                          ? _currentUserName()
                                          : 'User',
                                      initialIndex: 0,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: _StatItem(
                          label: 'Followers',
                          value: _formatCount(_followers),
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            !_isViewingOtherUser && _currentUserId().isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: _currentUserId(),
                                      userName: _currentUserName().isNotEmpty
                                          ? _currentUserName()
                                          : 'User',
                                      initialIndex: 1,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: _StatItem(
                          label: 'Following',
                          value: _formatCount(_following),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepBlue,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bio,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActions(BuildContext context) {
    if (_isViewingOtherUser) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () async {
                  if (widget.viewedUserId == null ||
                      widget.viewedUserId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID not found')),
                    );
                    return;
                  }

                  try {
                    final followProvider = context.read<FollowProvider>();
                    final response = await followProvider.toggleFollow(
                      targetUserId: widget.viewedUserId!,
                    );

                    if (response['error'] == true) {
                      throw Exception(
                        response['message'] ?? 'Follow request failed',
                      );
                    }

                    await _refreshProfile();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _isFollowingViewedUser
                      ? const Color(0xFF64748B)
                      : AppColors.deepBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isFollowingViewedUser ? 'Unfollow' : 'Follow',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerId: widget.viewedUserId ?? '',
                        peerName: widget.viewedUserName ?? 'User',
                        peerAvatar: widget.viewedUserImageUrl,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepBlue,
                  side: BorderSide(color: AppColors.deepBlue.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalDetailsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                side: BorderSide(color: AppColors.deepBlue.withOpacity(0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserConversationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.forum_rounded, size: 17),
              label: const Text('Chats'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostTile(_ProfileMediaItem item) {
    return InkWell(
      onTap: () => _showPostDetailsSheet(item),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imageUrl.isNotEmpty)
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    return Container(
                      color: const Color(0xFFEAF2FF),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.deepBlue,
                        size: 28,
                      ),
                    );
                  },
                )
              else
                Image.asset('assets/icons/noimage.png', fit: BoxFit.cover),
              if (item.isVideo)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6ECF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _ToggleButton(
                selected: _showGrid,
                icon: Icons.grid_view_rounded,
                onTap: () => setState(() => _showGrid = true),
              ),
            ),
            Expanded(
              child: _ToggleButton(
                selected: !_showGrid,
                icon: Icons.view_agenda_rounded,
                onTap: () => setState(() => _showGrid = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postMetricChip({required String label, required double? value}) {
    if (value == null) return const SizedBox.shrink();

    Color bg = const Color(0xFFEAF2FF);
    Color fg = AppColors.deepBlue;

    final key = label.toLowerCase();

    if (key.startsWith('cal')) {
      bg = AppColors.caloriesBg;
      fg = AppColors.caloriesPurple;
    } else if (key.startsWith('prot') || key == 'protein') {
      bg = AppColors.proteinBg;
      fg = AppColors.proteinBlue;
    } else if (key.startsWith('fat')) {
      bg = AppColors.fatBg;
      fg = AppColors.fatOrange;
    } else if (key.startsWith('carb')) {
      bg = AppColors.carbsBg;
      fg = AppColors.carbsGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPostListItem(
    _ProfileMediaItem item, {
    required String userName,
    required String? userImageUrl,
  }) {
    final likesCount = item.likeCount;
    final currentUserId = _getCurrentUserId();
    final userInitial = _getInitials(userName).substring(0, 1);
    final userAvatarProvider = userImageUrl != null && userImageUrl.isNotEmpty
        ? NetworkImage(userImageUrl) as ImageProvider
        : null;
    final hasLiked = item.likedByUsers.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6ECF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEAF2FF),
                  backgroundImage: userAvatarProvider,
                  child: userAvatarProvider == null
                      ? Text(
                          userInitial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.deepBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(item.publishedAt),
                        style: const TextStyle(
                          fontSize: 11.2,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isViewingOtherUser)
                  IconButton(
                    onPressed: () => _showPostMenu(context, item),
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
          if (item.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                item.caption,
                style: const TextStyle(
                  fontSize: 14.2,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2C3B),
                ),
              ),
            ),
          if (item.imageUrl.isNotEmpty)
            Image.network(
              item.imageUrl,
              width: double.infinity,
              height: 235,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  height: 235,
                  color: const Color(0xFFEAF2FF),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.deepBlue,
                      size: 34,
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _postMetricChip(label: 'Cal', value: item.calories),
                _postMetricChip(label: 'Fat', value: item.fat),
                _postMetricChip(label: 'Carb', value: item.carbs),
                _postMetricChip(label: 'Protein', value: item.protein),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Row(
              children: [
                Text(
                  '$likesCount likes',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _showCommentsSheet(item),
                  child: Text(
                    '${item.comments.length} comments',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE6ECF5)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _togglePostLike(item),
                  icon: Icon(
                    hasLiked ? Icons.favorite : Icons.favorite_border_rounded,
                    size: 19,
                    color: hasLiked ? Colors.red : AppColors.deepBlue,
                  ),
                  label: Text(
                    'Like',
                    style: TextStyle(
                      color: hasLiked ? Colors.red : AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE6ECF5)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showCommentsSheet(item),
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: AppColors.deepBlue,
                  ),
                  label: const Text(
                    'Comment',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserActionsSheet(String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DEE8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.orange),
                  title: const Text('Hide User'),
                  onTap: () async {
                    Navigator.pop(context);
                    final viewedUserId = (widget.viewedUserId ?? '').trim();
                    final viewedUserName = (widget.viewedUserName ?? 'User')
                        .trim();
                    final viewedUserImageUrl = (widget.viewedUserImageUrl ?? '')
                        .trim();

                    if (viewedUserId.isEmpty) return;

                    await _authService.hideUser(
                      userId: viewedUserId,
                      name: viewedUserName,
                      imageUrl: viewedUserImageUrl,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCommentsSheet(_ProfileMediaItem post) {
    final controller = TextEditingController();

    Future<void> submitComment(
      BuildContext sheetContext,
      StateSetter refreshSheet,
    ) async {
      final commentText = controller.text.trim();
      if (commentText.isEmpty) return;

      final authorName = _getCurrentUserName();
      final authorImageUrl = _extractUserImageUrl(
        context.read<UserProvider>().user,
      );

      final resp = await _authService.addPostComment(
        postId: post.id,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        text: commentText,
      );

      if (resp['error'] == true) {
        if (!mounted) return;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add comment: ${resp['message']}'),
            ),
          );
        }
        return;
      }

      setState(() {
        post.comments.add(
          _ProfileComment(
            authorName: authorName,
            authorImageUrl: authorImageUrl,
            text: commentText,
            createdAt: DateTime.now(),
          ),
        );
      });

      refreshSheet(() {});
      controller.clear();
      FocusScope.of(sheetContext).unfocus();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7DEE8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: post.comments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: post.comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) {
                                  final comment = post.comments[index];

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F9FB),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(
                                            0xFFEAF2FF,
                                          ),
                                          backgroundImage:
                                              comment.authorImageUrl != null &&
                                                  comment
                                                      .authorImageUrl!
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                  comment.authorImageUrl!,
                                                )
                                              : null,
                                          child:
                                              (comment.authorImageUrl == null ||
                                                  comment
                                                      .authorImageUrl!
                                                      .isEmpty)
                                              ? Text(
                                                  _getInitials(
                                                    comment.authorName,
                                                  ).substring(0, 1),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.deepBlue,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      comment.authorName,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color:
                                                            AppColors.deepBlue,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${comment.createdAt.hour.toString().padLeft(2, '0')}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                comment.text,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.35,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) =>
                            submitComment(sheetContext, setSheetState),
                        decoration: InputDecoration(
                          hintText: 'Write a comment',
                          filled: true,
                          fillColor: const Color(0xFFF7F9FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6ECF5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6ECF5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.deepBlue,
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                submitComment(sheetContext, setSheetState),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: AppColors.deepBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostMenu(BuildContext context, _ProfileMediaItem post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DEE8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                if (!_isViewingOtherUser) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.deepBlue,
                    ),
                    title: const Text('Edit Post'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditPostSheet(post);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePost(post);
                    },
                  ),
                ] else ...[
                  const ListTile(
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF64748B),
                    ),
                    title: Text('This post belongs to another profile'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPostSheet(_ProfileMediaItem post) {
    final captionController = TextEditingController(text: post.caption);
    final caloriesController = TextEditingController(
      text: post.calories != null ? post.calories.toString() : '',
    );
    final fatController = TextEditingController(
      text: post.fat != null ? post.fat.toString() : '',
    );
    final carbsController = TextEditingController(
      text: post.carbs != null ? post.carbs.toString() : '',
    );
    final proteinController = TextEditingController(
      text: post.protein != null ? post.protein.toString() : '',
    );

    File? selectedImageFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7DEE8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Post Image',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 90,
                          );

                          if (pickedFile != null) {
                            setSheetState(() {
                              selectedImageFile = File(pickedFile.path);
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 185,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE6ECF5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (selectedImageFile != null)
                                Image.file(
                                  selectedImageFile!,
                                  fit: BoxFit.cover,
                                )
                              else if (post.imageUrl.isNotEmpty)
                                Image.network(post.imageUrl, fit: BoxFit.cover)
                              else
                                Container(
                                  color: const Color(0xFFF7F9FB),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 34,
                                        color: AppColors.deepBlue,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to change image',
                                        style: TextStyle(
                                          color: AppColors.deepBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedImageFile != null)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        selectedImageFile = null;
                                      });
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: captionController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Edit caption',
                          filled: true,
                          fillColor: const Color(0xFFF7F9FB),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nutrition Info',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Calories',
                              caloriesController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _nutritionFieldEdit('Fat', fatController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Carbs',
                              carbsController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Protein',
                              proteinController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.deepBlue,
                                side: const BorderSide(
                                  color: AppColors.deepBlue,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _savePostChanges(
                                sheetContext,
                                post,
                                captionController.text,
                                caloriesController.text,
                                fatController.text,
                                carbsController.text,
                                proteinController.text,
                                selectedImageFile,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.deepBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _nutritionFieldEdit(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
        hintStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF7F9FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _savePostChanges(
    BuildContext sheetContext,
    _ProfileMediaItem post,
    String caption,
    String calories,
    String fat,
    String carbs,
    String protein,
    File? newImageFile,
  ) async {
    final caloriesValue = double.tryParse(calories);
    final fatValue = double.tryParse(fat);
    final carbsValue = double.tryParse(carbs);
    final proteinValue = double.tryParse(protein);

    if (caption.isEmpty) return;

    String updatedImageUrl = post.imageUrl;

    if (newImageFile != null) {
      updatedImageUrl = newImageFile.path;
    }

    final updatedPost = _ProfileMediaItem(
      id: post.id,
      imageUrl: updatedImageUrl,
      caption: caption,
      likes: post.likes,
      likedByUsers: post.likedByUsers,
      comments: post.comments,
      publishedAt: post.publishedAt,
      isVideo: post.isVideo,
      calories: caloriesValue,
      fat: fatValue,
      carbs: carbsValue,
      protein: proteinValue,
    );

    if (!mounted) return;

    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index] = updatedPost;
      }
    });

    Navigator.pop(sheetContext);
  }

  Future<void> _deletePost(_ProfileMediaItem post) async {
    final response = await _authService.deletePost(postId: post.id);
    if (!mounted) return;

    if (response['error'] == true) return;

    setState(() {
      _posts.removeWhere((item) => item.id == post.id);
    });
  }

  String _getCurrentUserId() {
    final user = context.read<UserProvider>().user;
    return (user?['_id']?.toString() ??
            user?['userId']?.toString() ??
            _sessionUserId ??
            '')
        .trim();
  }

  String _getCurrentUserName() {
    final user = context.read<UserProvider>().user;
    return (user?['name']?.toString() ?? 'User').trim();
  }

  Future<void> _togglePostLike(_ProfileMediaItem post) async {
    final userId = _getCurrentUserId();
    final userName = _getCurrentUserName();

    if (userId.isEmpty || userName.isEmpty) return;

    final prevLiked = Set<String>.from(post.likedByUsers);
    final prevLikesList = List<_LikeItem>.from(post.likes);
    final prevCount = post.likeCount;

    final hadLiked = post.likedByUsers.contains(userId);

    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        if (hadLiked) {
          _posts[index].likedByUsers.remove(userId);
          _posts[index].likes.removeWhere((l) => l.id == userId);
          _posts[index].likeCount = (_posts[index].likeCount - 1).clamp(
            0,
            1 << 30,
          );
        } else {
          _posts[index].likedByUsers.add(userId);
          _posts[index].likes.add(
            _LikeItem(id: userId, name: userName, imageUrl: null),
          );
          _posts[index].likeCount = _posts[index].likeCount + 1;
        }
      }
    });

    final success = await context.read<LikeProvider>().toggleLike(
      postId: post.id,
      userId: userId,
    );

    if (!success) {
      if (!mounted) return;

      setState(() {
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index != -1) {
          _posts[index].likedByUsers
            ..clear()
            ..addAll(prevLiked);
          _posts[index].likes
            ..clear()
            ..addAll(prevLikesList);
          _posts[index].likeCount = prevCount;
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
      }
      return;
    }

    final lp = context.read<LikeProvider>();
    final liked = lp.likedByUsersFor(post.id);
    final count = lp.likeCountFor(post.id);

    if (!mounted) return;

    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index].likedByUsers
          ..clear()
          ..addAll(liked);
        _posts[index].likes
          ..clear()
          ..addAll(
            liked
                .map((id) => _LikeItem(id: id, name: 'User', imageUrl: null))
                .toList(),
          );
        _posts[index].likeCount = count;
      }
    });
  }

  void _syncLikesFromProvider() {
    final lp = context.read<LikeProvider>();
    bool changed = false;

    for (var i = 0; i < _posts.length; i++) {
      final p = _posts[i];

      if (!lp.hasDataFor(p.id)) continue;

      final liked = lp.likedByUsersFor(p.id);
      final count = lp.likeCountFor(p.id);

      if (!setEquals(p.likedByUsers, liked) || p.likeCount != count) {
        p.likedByUsers
          ..clear()
          ..addAll(liked);
        p.likes
          ..clear()
          ..addAll(
            liked
                .map((id) => _LikeItem(id: id, name: 'User', imageUrl: null))
                .toList(),
          );
        p.likeCount = count;
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
  }

  void _showAddCommentSheet(_ProfileMediaItem post) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Comment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your comment...',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FB),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepBlue,
                            side: const BorderSide(color: AppColors.deepBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _addPostComment(
                            sheetContext,
                            post,
                            commentController.text,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.deepBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPostComment(
    BuildContext sheetContext,
    _ProfileMediaItem post,
    String commentText,
  ) async {
    final text = commentText.trim();
    if (text.isEmpty) return;

    final userName = _getCurrentUserName();
    final userImageUrl = _extractUserImageUrl(
      context.read<UserProvider>().user,
    );

    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index].comments.add(
          _ProfileComment(
            authorName: userName,
            authorImageUrl: userImageUrl,
            text: text,
            createdAt: DateTime.now(),
          ),
        );
      }
    });

    Navigator.pop(sheetContext);

    final resp = await _authService.addPostComment(
      postId: post.id,
      authorName: userName,
      authorImageUrl: userImageUrl,
      text: text,
    );

    if (resp['error'] == true) {
      if (!mounted) return;

      setState(() {
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index != -1) {
          final comments = _posts[index].comments;
          if (comments.isNotEmpty && comments.last.text == text) {
            comments.removeLast();
          }
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${resp['message'] ?? ''}'),
          ),
        );
      }
    }
  }

  void _showPostDetailsSheet(_ProfileMediaItem post) {
    final currentUser = context.read<UserProvider>().user;
    final userName = _getCurrentUserName();
    final userImageUrl = _extractUserImageUrl(currentUser);
    final userInitial = _getInitials(userName).substring(0, 1);
    final userAvatarProvider = userImageUrl != null && userImageUrl.isNotEmpty
        ? NetworkImage(userImageUrl) as ImageProvider
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DEE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Post Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const Spacer(),
                      if (!_isViewingOtherUser)
                        IconButton(
                          onPressed: () => _deletePost(post),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEAF2FF),
                        backgroundImage: userAvatarProvider,
                        child: userAvatarProvider == null
                            ? Text(
                                userInitial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: AppColors.deepBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDate(post.publishedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (post.caption.trim().isNotEmpty) ...[
                    Text(
                      post.caption,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (post.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(post.imageUrl, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _showCommentsSheet(post),
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: Text('${post.comments.length} comments'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppColors.deepBlue;
    final unselectedColor = const Color(0xFF94A3B8);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: 34,
                decoration: BoxDecoration(
                  color: selected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPostsView extends StatelessWidget {
  final bool isViewingOtherUser;

  const _EmptyPostsView({required this.isViewingOtherUser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.deepBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No posts yet',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isViewingOtherUser
                  ? 'This user has not shared any food posts yet.'
                  : 'Share your first meal or recipe with the community.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileMediaItem {
  final String id;
  final String imageUrl;
  final String caption;
  final List<_LikeItem> likes;
  final Set<String> likedByUsers;
  final List<_LikeItem> likedByDetails;
  int likeCount;
  final List<_ProfileComment> comments;
  final DateTime publishedAt;
  final bool isVideo;
  final double? calories;
  final double? fat;
  final double? carbs;
  final double? protein;

  _ProfileMediaItem({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    Set<String>? likedByUsers,
    List<_LikeItem>? likedByDetails,
    this.likeCount = 0,
    required this.comments,
    required this.publishedAt,
    required this.isVideo,
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
  }) : likedByUsers = likedByUsers ?? <String>{},
       likedByDetails = likedByDetails ?? <_LikeItem>[];
}

class _ProfileComment {
  final String authorName;
  final String? authorImageUrl;
  final String text;
  final DateTime createdAt;

  const _ProfileComment({
    required this.authorName,
    required this.text,
    this.authorImageUrl,
    required this.createdAt,
  });
}

class _LikeItem {
  final String id;
  final String name;
  final String? imageUrl;

  _LikeItem({required this.id, required this.name, this.imageUrl});
}
