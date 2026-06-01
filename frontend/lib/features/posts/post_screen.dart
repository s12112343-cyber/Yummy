import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'dart:async';

import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/home_provider.dart';
import '../../core/providers/like_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../notifications/notifications_screen.dart';
import '../profile/user_profile_screen.dart';
import '../profile/user_conversations_screen.dart';
import '../../shared/custom_bottom_nav.dart';
import '../../shared/app_sidebar.dart';

class _UserStreakItem {
  final String id;
  final String name;
  final String imageUrl;
  final String? email;
  final String gender;
  final int streak;

  const _UserStreakItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.email,
    required this.gender,
    required this.streak,
  });

  factory _UserStreakItem.fromJson(Map<String, dynamic> json) {
    return _UserStreakItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      email: (json['email'] ?? '').toString().trim().isEmpty
          ? null
          : (json['email'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      streak: (json['streak_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class _PostComment {
  final String authorName;
  final String? authorImageUrl;
  final String text;
  final DateTime createdAt;

  const _PostComment({
    required this.authorName,
    required this.authorImageUrl,
    required this.text,
    required this.createdAt,
  });
}

class _LikedUserItem {
  final String id;
  final String name;
  final String? imageUrl;

  const _LikedUserItem({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory _LikedUserItem.fromJson(Map<String, dynamic> json) {
    return _LikedUserItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
    );
  }
}

enum _PostAudience { everyone, followersOnly }

enum _PostSortOrder { newestFirst, oldestFirst }

enum _PostFeedFilter {
  all,
  myPosts,
  highestProtein,
  lowestCalories,
  todayPosts,
  mostLiked,
  publicOnly,
  followersOnlyVisibility,
  withImage,
}

String _normalizePostVisibility(dynamic v) {
  final s = (v?.toString() ?? '').trim().toLowerCase();
  return s == 'followers_only' ? 'followers_only' : 'public';
}

class _FeedPost {
  final String id;
  final String? authorId;
  final String authorName;
  final String? authorImageUrl;
  final String text;
  final File? imageFile;
  final String? imageUrl;
  final DateTime publishedAt;

  /// Backend: `public` | `followers_only`
  final String visibility;
  final double? calories;
  final double? fat;
  final double? carbs;
  final double? protein;

  bool likedByMe = false;
  int likeCount;
  final Set<String> likedByUsers;
  final List<_LikedUserItem> likedByDetails;
  final List<_PostComment> comments;

  _FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorImageUrl,
    required this.text,
    required this.imageFile,
    required this.imageUrl,
    required this.publishedAt,
    this.visibility = 'public',
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
    this.likeCount = 0,
    Set<String>? likedByUsers,
    List<_LikedUserItem>? likedByDetails,
    List<_PostComment>? comments,
  }) : likedByUsers = likedByUsers ?? <String>{},
       likedByDetails = likedByDetails ?? <_LikedUserItem>[],
       comments = comments ?? <_PostComment>[];
}

final List<_FeedPost> _cachedPosts = [];
String? _cachedPostsOwnerId;

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _userSearchController = TextEditingController();
  final FocusNode _userSearchFocusNode = FocusNode();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();

  _PostAudience _composerAudience = _PostAudience.everyone;
  _PostFeedFilter _feedFilter = _PostFeedFilter.all;
  _PostSortOrder _postSortOrder = _PostSortOrder.newestFirst;

  List<_FeedPost> get _posts => _cachedPosts;

  List<_FeedPost> get _visiblePosts {
    List<_FeedPost> list;
    switch (_feedFilter) {
      case _PostFeedFilter.all:
        list = List<_FeedPost>.from(_posts);
        break;
      case _PostFeedFilter.myPosts:
        list = _posts.where(_isMyPost).toList();
        break;
      case _PostFeedFilter.highestProtein:
        final list = List<_FeedPost>.from(_posts);
        list.retainWhere((p) => (p.protein ?? 0) >= 15);
        return _applyPostSortOrder(list);
      case _PostFeedFilter.lowestCalories:
        final list = List<_FeedPost>.from(_posts);
        list.retainWhere((p) => (p.calories ?? double.infinity) <= 600);
        return _applyPostSortOrder(list);
      case _PostFeedFilter.todayPosts:
        final now = DateTime.now();
        list = _posts.where((p) {
          final d = p.publishedAt;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        break;
      case _PostFeedFilter.mostLiked:
        final list = List<_FeedPost>.from(_posts);
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        return _applyPostSortOrder(list);
      case _PostFeedFilter.publicOnly:
        list = _posts
            .where((p) => _normalizePostVisibility(p.visibility) == 'public')
            .toList();
        break;
      case _PostFeedFilter.followersOnlyVisibility:
        list = _posts
            .where(
              (p) => _normalizePostVisibility(p.visibility) == 'followers_only',
            )
            .toList();
        break;
      case _PostFeedFilter.withImage:
        list = _posts
            .where(
              (p) =>
                  (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty) ||
                  p.imageFile != null,
            )
            .toList();
        break;
    }

    list = list.where((post) => !_isHiddenUserId(post.authorId)).toList();
    return _applyPostSortOrder(list);
  }

  List<_FeedPost> _applyPostSortOrder(List<_FeedPost> list) {
    final sorted = List<_FeedPost>.from(list);
    sorted.sort((a, b) {
      final comparison = b.publishedAt.compareTo(a.publishedAt);
      return _postSortOrder == _PostSortOrder.newestFirst
          ? comparison
          : -comparison;
    });
    return sorted;
  }

  bool _isMyPost(_FeedPost p) {
    final idSet = <String>{
      ...[
            _me?['_id']?.toString(),
            _me?['id']?.toString(),
            _me?['userId']?.toString(),
            _sessionUserId,
          ]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => e.toString().trim().toLowerCase()),
    };
    final aid = p.authorId?.trim().toLowerCase();
    if (aid != null && aid.isNotEmpty && idSet.contains(aid)) return true;

    final myName = (_me?['name']?.toString() ?? '').trim().toLowerCase();
    final postName = p.authorName.trim().toLowerCase();
    return myName.isNotEmpty && postName == myName;
  }

  List<_UserStreakItem> _users = [];
  List<_UserStreakItem> _allUsersForSearch = [];
  List<_UserStreakItem> _hiddenUsers = [];
  bool _isLoadingUsers = true;
  bool _isLoadingPosts = true;
  bool _isPublishing = false;
  bool _isSearchExpanded = false;
  Timer? _userSearchDebounce;
  String _lastRemoteQuery = '';
  List<_UserStreakItem> _remoteUserSearchResults = [];
  bool _isSearchingRemoteUsers = false;
  File? _selectedPostImage;
  Map<String, dynamic>? _me;
  String? _sessionUserId;

  /// Rebuild the open composer bottom sheet (`StatefulBuilder`). Parent `setState` alone does not refresh it.
  StateSetter? _composerModalSetState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userSearchFocusNode.addListener(() {
      if (!mounted) return;
      final hasQuery = _userSearchController.text.trim().isNotEmpty;
      setState(() {
        _isSearchExpanded = _userSearchFocusNode.hasFocus || hasQuery;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionUserId = await _authService.getUserId();
      await _loadHiddenUsers();
      _loadUsers();
      _loadMe();
      await _loadPosts();
      try {
        final lp = context.read<LikeProvider>();
        lp.addListener(_syncLikesFromProvider);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      context.read<LikeProvider>().removeListener(_syncLikesFromProvider);
    } catch (_) {}
    _userSearchFocusNode.dispose();
    _userSearchController.dispose();
    _postController.dispose();
    _caloriesController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  void _syncLikesFromProvider() {
    final lp = context.read<LikeProvider>();
    final userId = _currentUserId();
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
        p.likeCount = count;
        p.likedByMe = userId != null && liked.contains(userId);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _loadMe() async {
    final response = await _authService.getMe();
    if (!mounted) return;

    final userData = response['user'];
    if (response['error'] == true || userData is! Map) {
      return;
    }

    setState(() {
      _me = Map<String, dynamic>.from(userData);
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    final response = await _authService.getUsersStreaks();
    final usersRaw = response['users'] as List<dynamic>? ?? [];

    if (!mounted) return;
    setState(() {
      _allUsersForSearch = usersRaw
          .map(
            (item) => _UserStreakItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((user) => !_isHiddenUserId(user.id))
          .toList();

      _users = usersRaw
          .map(
            (item) => _UserStreakItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((user) => user.streak > 0)
          .where((user) => !_isHiddenUserId(user.id))
          .toList();
      _isLoadingUsers = false;
    });
  }

  List<_UserStreakItem> get _visibleStreakUsers =>
      _users.where((user) => !_isHiddenUserId(user.id)).toList();

  bool _isHiddenUserId(String? userId) {
    final normalized = (userId ?? '').trim();
    if (normalized.isEmpty) return false;
    return _hiddenUsers.any((user) => user.id.trim() == normalized);
  }

  Future<void> _loadHiddenUsers() async {
    final hiddenRaw = await _authService.getHiddenUsers();
    if (!mounted) return;
    setState(() {
      _hiddenUsers = hiddenRaw
          .map(_UserStreakItem.fromJson)
          .where((user) => user.id.trim().isNotEmpty)
          .toList();
    });
  }

  Future<void> _hideUser(_UserStreakItem user) async {
    final userId = user.id.trim();
    if (userId.isEmpty) return;

    await _authService.hideUser(
      userId: userId,
      name: user.name,
      imageUrl: user.imageUrl,
    );
    await _loadHiddenUsers();
    if (!mounted) return;
    await _loadUsers();
  }

  Future<void> _unhideUser(_UserStreakItem user) async {
    final userId = user.id.trim();
    if (userId.isEmpty) return;

    await _authService.unhideUser(userId);
    await _loadHiddenUsers();
    if (!mounted) return;
    await _loadUsers();
  }

  List<_UserStreakItem> get _matchedUsers {
    final query = _userSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return const <_UserStreakItem>[];

    final myId = _currentUserId();
    final matches = _allUsersForSearch.where((user) {
      final id = user.id.trim();
      if (myId != null && myId.isNotEmpty && id == myId) return false;
      if (_isHiddenUserId(id)) return false;
      final name = user.name.trim().toLowerCase();
      final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (name.contains(query)) return true;
      return words.any((word) => word.startsWith(query));
    }).toList();

    matches.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(query);
      final bStarts = b.name.toLowerCase().startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (matches.length > 6) {
      return matches.sublist(0, 6);
    }
    if (matches.isNotEmpty) return matches;

    // Fallback: try to match among post authors (useful if users-streaks
    // endpoint doesn't include all users). Build a unique list of authors.
    final Map<String, _UserStreakItem> authors = {};
    for (final p in _posts) {
      final aid = p.authorId?.toString() ?? '';
      if (aid.isEmpty) continue;
      if (myId != null &&
          myId.isNotEmpty &&
          aid.trim().toLowerCase() == myId.trim().toLowerCase()) {
        continue;
      }
      if (!authors.containsKey(aid)) {
        authors[aid] = _UserStreakItem(
          id: aid,
          name: p.authorName,
          imageUrl: p.authorImageUrl ?? '',
          email: null,
          gender: 'male',
          streak: 0,
        );
      }
    }

    final authorMatches = authors.values.where((user) {
      final name = user.name.trim().toLowerCase();
      if (_isHiddenUserId(user.id)) return false;
      final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (name.contains(query)) return true;
      return words.any((word) => word.startsWith(query));
    }).toList();

    authorMatches.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    if (authorMatches.length > 6) return authorMatches.sublist(0, 6);
    if (authorMatches.isNotEmpty) return authorMatches;

    // If still empty, return remote search results if they match current query.
    if (_lastRemoteQuery == query && _remoteUserSearchResults.isNotEmpty) {
      return _remoteUserSearchResults;
    }

    return const <_UserStreakItem>[];
  }

  Widget _buildUserSearchSection() {
    final query = _userSearchController.text.trim();
    final matchedUsers = _matchedUsers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const buttonWidth = 44.0;
              const gap = 10.0;

              final maxSearchWidth = (constraints.maxWidth - buttonWidth - gap)
                  .clamp(120.0, double.infinity);

              final collapsedWidth = maxSearchWidth < 170
                  ? maxSearchWidth
                  : 170.0;

              final expanded = _isSearchExpanded || query.isNotEmpty;

              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: expanded ? maxSearchWidth : collapsedWidth,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: expanded
                                ? const Color(0xFFC9DCF4)
                                : const Color(0xFFDDE9F6),
                          ),
                          boxShadow: [
                            if (expanded)
                              BoxShadow(
                                color: const Color(
                                  0xFF93B4DF,
                                ).withOpacity(0.14),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: TextField(
                          controller: _userSearchController,
                          focusNode: _userSearchFocusNode,
                          onTap: () {
                            if (!_isSearchExpanded) {
                              setState(() => _isSearchExpanded = true);
                            }
                          },
                          onChanged: (val) {
                            setState(() {});
                            _userSearchDebounce?.cancel();
                            final q = val.trim();
                            if (q.length >= 2) {
                              _userSearchDebounce = Timer(
                                const Duration(milliseconds: 350),
                                () {
                                  _performRemoteUserSearch(q);
                                },
                              );
                            }
                          },
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: expanded
                                ? 'Search users by name'
                                : 'Search',
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.blueGray,
                              size: 20,
                            ),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _userSearchController.clear();
                                      final keepExpanded =
                                          _userSearchFocusNode.hasFocus;
                                      setState(() {
                                        _isSearchExpanded = keepExpanded;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.blueGray,
                                      size: 18,
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF7FAFE),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Settings button stays fixed on the right
                  _buildFilterFloatingButton(),
                ],
              );
            },
          ),

          if (query.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (matchedUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueGray,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1EBF7)),
                ),
                child: ListView.separated(
                  itemCount: matchedUsers.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 54),
                  itemBuilder: (_, index) {
                    final user = matchedUsers[index];
                    final userImageUrl = _resolveImageUrl(user.imageUrl);

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.babyBlueLight,
                        backgroundImage:
                            (userImageUrl != null && userImageUrl.isNotEmpty)
                            ? NetworkImage(userImageUrl)
                            : null,
                        child: (userImageUrl == null || userImageUrl.isEmpty)
                            ? Text(
                                _firstName(user.name)[0].toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepBlue,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.blueGray,
                      ),
                      onTap: () {
                        _userSearchController.clear();
                        setState(() {
                          _isSearchExpanded = false;
                        });
                        _openProfileAndRefresh(
                          viewedUserId: user.id,
                          viewedUserName: user.name,
                          viewedUserImageUrl: userImageUrl,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _performRemoteUserSearch(String q) async {
    if (q.isEmpty) return;
    _lastRemoteQuery = q;
    _isSearchingRemoteUsers = true;
    setState(() {});

    final resp = await _authService.searchUsers(q);
    _isSearchingRemoteUsers = false;

    if (resp['error'] == true) {
      _remoteUserSearchResults = [];
      if (mounted) setState(() {});
      return;
    }

    final usersRaw = resp['users'] as List<dynamic>? ?? [];
    _remoteUserSearchResults = usersRaw.map((item) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        return _UserStreakItem.fromJson(map);
      } catch (_) {
        return _UserStreakItem(
          id: (item['id'] ?? '').toString(),
          name: (item['name'] ?? 'User').toString(),
          imageUrl: '',
          email: (item['email'] ?? '').toString(),
          gender: '',
          streak: 0,
        );
      }
    }).toList();

    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed, reloading posts');
      _loadPosts();
    }
  }

  Future<void> _refreshPosts() async {
    print('🔄 Pull-to-refresh triggered');
    await _loadPosts();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return null;
    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    final origin = (baseUri != null)
        ? (baseUri.hasPort
              ? '${baseUri.scheme}://${baseUri.host}:${baseUri.port}'
              : '${baseUri.scheme}://${baseUri.host}')
        : '';

    // If the incoming value is already an absolute URL, keep it
    // unless it's a server-upload URL (contains /uploads) —
    // in that case replace its origin with the one from AppConfig.
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final rawUri = Uri.tryParse(raw);
      if (rawUri != null &&
          rawUri.path.startsWith('/uploads') &&
          origin.isNotEmpty) {
        return '$origin${rawUri.path}${rawUri.hasQuery ? '?${rawUri.query}' : ''}';
      }
      return raw;
    }

    if (origin.isEmpty) return raw.startsWith('/') ? raw : '/$raw';

    if (raw.startsWith('/')) return '$origin$raw';
    return '$origin/$raw';
  }

  String? _extractUserImageUrl(Map<String, dynamic>? user) {
    final profile = user?['profile'] as Map<String, dynamic>?;
    final rawImageValue =
        profile?['image_url'] ??
        profile?['image'] ??
        profile?['imageUrl'] ??
        user?['profile_image_url'] ??
        user?['profileImageUrl'] ??
        user?['image_url'] ??
        user?['image'] ??
        user?['imageUrl'];

    return _resolveImageUrl(rawImageValue);
  }

  Widget _buildAvatarWithFallback({
    required String name,
    required String? imageUrl,
    required double radius,
    Color backgroundColor = AppColors.babyBlueLight,
    Color textColor = AppColors.deepBlue,
  }) {
    final initial = _firstName(name)[0].toUpperCase();
    final size = radius * 2;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(
                color: backgroundColor,
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: radius * 0.9,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: textColor,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'User';
    return trimmed.split(' ').first;
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year;
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  String _commentTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  void _openAuthorProfile(_FeedPost post) {
    _openProfileAndRefresh(
      viewedUserId: post.authorId,
      viewedUserName: post.authorName,
      viewedUserImageUrl: post.authorImageUrl,
    );
  }

  Future<void> _openProfileAndRefresh({
    String? viewedUserId,
    String? viewedUserName,
    String? viewedUserImageUrl,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          viewedUserId: viewedUserId,
          viewedUserName: viewedUserName,
          viewedUserImageUrl: viewedUserImageUrl,
        ),
      ),
    );

    // Profile screen returns true when a hide action is performed.
    if (result == true && mounted) {
      await _loadHiddenUsers();
      await _loadUsers();
      await _loadPosts();
    }
  }

  Future<void> _showPostImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Add Post Image',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _imageSourceTile(
                        icon: Icons.photo_library_rounded,
                        title: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickPostImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _imageSourceTile(
                        icon: Icons.camera_alt_rounded,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickPostImage(ImageSource.camera);
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

  Widget _imageSourceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9E6F5)),
          color: const Color(0xFFF5F9FF),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.deepBlue, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPostImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (pickedFile == null || !mounted) return;

    setState(() {
      _selectedPostImage = File(pickedFile.path);
    });
    _composerModalSetState?.call(() {});
  }

  Future<void> _loadPosts() async {
    print('📋 Loading posts...');
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
    });

    final activeUserId = await _authService.getUserId();
    if (_cachedPostsOwnerId != activeUserId) {
      _cachedPosts.clear();
      _cachedPostsOwnerId = activeUserId;
    }

    final response = await _authService.getPosts();
    if (response['error'] == true) {
      print('❌ Failed to load posts: ${response['message']}');
      if (!mounted) return;
      setState(() {
        _isLoadingPosts = false;
      });
      return;
    }

    final postsRaw = response['posts'] as List<dynamic>? ?? [];
    print('✅ Loaded ${postsRaw.length} posts from backend');
    if (!mounted) return;
    setState(() {
      _posts.clear();
      for (final item in postsRaw) {
        final p = Map<String, dynamic>.from(item as Map);
        final commentsRaw = (p['comments'] as List<dynamic>?) ?? [];
        final comments = commentsRaw.map((c) {
          final cm = Map<String, dynamic>.from(c as Map);
          return _PostComment(
            authorName: cm['authorName']?.toString() ?? 'User',
            authorImageUrl: _resolveImageUrl(cm['authorImageUrl']),
            text: cm['text']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(cm['createdAt']?.toString() ?? '') ??
                DateTime.now(),
          );
        }).toList();

        final feedPost = _FeedPost(
          id:
              p['_id']?.toString() ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          authorId: p['authorId']?.toString(),
          authorName: p['authorName']?.toString() ?? 'User',
          authorImageUrl: _resolveImageUrl(p['authorImageUrl']),
          text: p['text']?.toString() ?? '',
          imageFile: null,
          imageUrl: _resolveImageUrl(p['imagePath']),
          publishedAt:
              DateTime.tryParse(p['publishedAt']?.toString() ?? '') ??
              DateTime.now(),
          visibility: _normalizePostVisibility(p['visibility']),
          calories: (p['calories'] as num?)?.toDouble(),
          fat: (p['fat'] as num?)?.toDouble(),
          carbs: (p['carbs'] as num?)?.toDouble(),
          protein: (p['protein'] as num?)?.toDouble(),
          likeCount: (p['likedByUsers'] as List<dynamic>?)?.length ?? 0,
          likedByUsers:
              (p['likedByUsers'] as List<dynamic>?)
                  ?.map((item) => item.toString())
                  .toSet() ??
              <String>{},
          likedByDetails: const <_LikedUserItem>[],
          comments: comments,
        );

        final currentUserId = _sessionUserId ?? _currentUserId();
        feedPost.likedByMe =
            currentUserId != null &&
            feedPost.likedByUsers.contains(currentUserId);

        _posts.add(feedPost);
      }
      _posts.removeWhere((post) => _isHiddenUserId(post.authorId));
      _isLoadingPosts = false;
    });
  }

  String? _currentUserId() {
    return _me?['_id']?.toString() ??
        _me?['id']?.toString() ??
        _me?['userId']?.toString() ??
        _sessionUserId;
  }

  Future<void> _showFeedFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter posts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSectionLabel('Sort order'),
                const SizedBox(height: 8),
                ...[
                  _PostSortOrder.newestFirst,
                  _PostSortOrder.oldestFirst,
                ].map((order) {
                  final selected = _postSortOrder == order;
                  final title = order == _PostSortOrder.newestFirst
                      ? 'Newest first'
                      : 'Oldest first';
                  final subtitle = order == _PostSortOrder.newestFirst
                      ? 'Show the latest posts on top'
                      : 'Show the oldest posts on top';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? AppColors.deepBlue : AppColors.blueGray,
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.blueGray,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _postSortOrder = order);
                    },
                  );
                }),
                const SizedBox(height: 8),
                _buildSectionLabel('Filters'),
                const SizedBox(height: 8),
                ..._PostFeedFilter.values.map((f) {
                  final selected = _feedFilter == f;
                  String title;
                  String? subtitle;
                  switch (f) {
                    case _PostFeedFilter.all:
                      title = 'All posts';
                      subtitle = 'Show everything in the feed';
                      break;
                    case _PostFeedFilter.myPosts:
                      title = 'My posts';
                      subtitle = 'Only posts you created';
                      break;
                    case _PostFeedFilter.highestProtein:
                      title = 'Highest protein';
                      subtitle = 'Filter: protein >= 15g';
                      break;
                    case _PostFeedFilter.lowestCalories:
                      title = 'Lowest calories';
                      subtitle = 'Filter: calories <= 600';
                      break;
                    case _PostFeedFilter.todayPosts:
                      title = 'Today posts';
                      subtitle = 'Only posts published today';
                      break;
                    case _PostFeedFilter.mostLiked:
                      title = 'Most liked';
                      subtitle = 'Sort by like count (high → low)';
                      break;
                    case _PostFeedFilter.publicOnly:
                      title = 'Public';
                      subtitle = 'Visible to everyone';
                      break;
                    case _PostFeedFilter.followersOnlyVisibility:
                      title = 'Followers only';
                      subtitle = 'Posts shared only with followers';
                      break;
                    case _PostFeedFilter.withImage:
                      title = 'With photo';
                      subtitle = 'Posts that include an image';
                      break;
                  }
                  return ListTile(
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.deepBlue : AppColors.blueGray,
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.blueGray,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _feedFilter = f);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.blueGray,
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('My Profile'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('Filter'),
                  subtitle: Text(_sortOrderLabel()),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFeedFilterSheet();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications coming soon'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.orange),
                  title: const Text('Hide User'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Hide User is available from user cards for now',
                        ),
                      ),
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

  String _sortOrderLabel() {
    return _postSortOrder == _PostSortOrder.newestFirst
        ? 'Newest first'
        : 'Oldest first';
  }

  double? _optionalDouble(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _clearComposer() {
    _postController.clear();
    _caloriesController.clear();
    _fatController.clear();
    _carbsController.clear();
    _proteinController.clear();
    _selectedPostImage = null;
    _composerAudience = _PostAudience.everyone;
  }

  Future<void> _publishPost([BuildContext? sheetContext]) async {
    final text = _postController.text.trim();
    final calories = _optionalDouble(_caloriesController);
    final fat = _optionalDouble(_fatController);
    final carbs = _optionalDouble(_carbsController);
    final protein = _optionalDouble(_proteinController);

    if (text.isEmpty && _selectedPostImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write text or add an image before posting'),
        ),
      );
      return;
    }

    final hasInvalidNutrition = [calories, fat, carbs, protein].any(
      (value) =>
          value == null &&
          [
            _caloriesController,
            _fatController,
            _carbsController,
            _proteinController,
          ].any((controller) => controller.text.trim().isNotEmpty),
    );

    if (hasInvalidNutrition) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition fields must be valid numbers')),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    final authorName = (_me?['name']?.toString() ?? 'You').trim();
    final authorImageUrl = _extractUserImageUrl(_me);

    // Try to persist to backend
    print('📤 Publishing post with image: ${_selectedPostImage != null}');
    final visibilityApi = _composerAudience == _PostAudience.followersOnly
        ? 'followers_only'
        : 'public';

    final resp = await _authService.createPost(
      authorName: authorName,
      authorImageUrl: authorImageUrl,
      text: text.isNotEmpty ? text : null,
      imageFile: _selectedPostImage,
      calories: calories,
      fat: fat,
      carbs: carbs,
      protein: protein,
      visibility: visibilityApi,
    );

    print('📥 Create post response: $resp');

    _FeedPost post;
    if (resp['error'] == true || resp['post'] == null) {
      // Fallback to local-only post when network fails
      print(
        '⚠️ Fallback to local post (error: ${resp["error"]}, msg: ${resp["message"]})',
      );
      post = _FeedPost(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        authorId: _currentUserId(),
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        text: text,
        imageFile: _selectedPostImage,
        imageUrl: null,
        publishedAt: DateTime.now(),
        visibility: visibilityApi,
        calories: calories,
        fat: fat,
        carbs: carbs,
        protein: protein,
      );
    } else {
      final created = resp['post'] as Map<String, dynamic>? ?? {};
      post = _FeedPost(
        id:
            created['_id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        authorId: created['authorId']?.toString() ?? _currentUserId(),
        authorName: created['authorName']?.toString() ?? authorName,
        authorImageUrl: _resolveImageUrl(created['authorImageUrl']),
        text: created['text']?.toString() ?? text,
        imageFile: null,
        imageUrl: _resolveImageUrl(created['imagePath']),
        publishedAt:
            DateTime.tryParse(created['publishedAt']?.toString() ?? '') ??
            DateTime.now(),
        visibility: _normalizePostVisibility(
          created['visibility'] ?? visibilityApi,
        ),
        calories: (created['calories'] as num?)?.toDouble(),
        fat: (created['fat'] as num?)?.toDouble(),
        carbs: (created['carbs'] as num?)?.toDouble(),
        protein: (created['protein'] as num?)?.toDouble(),
        likedByUsers: (created['likedByUsers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet(),
        likedByDetails: (created['likedByDetails'] as List<dynamic>?)
            ?.map(
              (item) => _LikedUserItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        comments: [],
      );
    }

    setState(() {
      _posts.insert(0, post);
      _isPublishing = false;
      _clearComposer();
    });

    if (sheetContext != null && Navigator.of(sheetContext).canPop()) {
      Navigator.of(sheetContext).pop();
    }
  }

  Future<void> _toggleLike(_FeedPost post) async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) return;
    final success = await context.read<LikeProvider>().toggleLike(
      postId: post.id,
      userId: userId,
    );

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
      return;
    }

    // Update local cached post from provider
    final lp = context.read<LikeProvider>();
    final liked = lp.likedByUsersFor(post.id);
    final count = lp.likeCountFor(post.id);
    if (!mounted) return;
    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index == -1) return;
      _posts[index].likedByUsers
        ..clear()
        ..addAll(liked);
      _posts[index].likedByMe = liked.contains(userId);
      _posts[index].likeCount = count;
    });
  }

  // Detailed post sheet is provided only from the profile screen.

  Future<void> _showCommentsSheet(_FeedPost post) async {
    final controller = TextEditingController();

    Future<void> submitComment(
      BuildContext sheetContext,
      StateSetter refreshSheet,
    ) async {
      final commentText = controller.text.trim();
      if (commentText.isEmpty) return;

      final authorName = (_me?['name']?.toString() ?? 'You').trim();
      final authorImageUrl = _extractUserImageUrl(_me);

      print('💬 Submitting comment to post ${post.id}');

      // Save to backend
      final resp = await _authService.addPostComment(
        postId: post.id,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        text: commentText,
      );

      if (resp['error'] == true) {
        print('❌ Failed to add comment: ${resp['message']}');
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

      // Update local state
      setState(() {
        post.comments.add(
          _PostComment(
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: post.comments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    color: AppColors.blueGray,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: post.comments.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 14),
                                itemBuilder: (_, index) {
                                  final comment = post.comments[index];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            AppColors.babyBlueLight,
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
                                                comment.authorImageUrl!.isEmpty)
                                            ? Text(
                                                _firstName(
                                                  comment.authorName,
                                                )[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepBlue,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
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
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _commentTime(
                                                    comment.createdAt,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.blueGray,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(comment.text),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) =>
                            submitComment(sheetContext, setSheetState),
                        decoration: InputDecoration(
                          hintText: 'Write a comment',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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

  ImageProvider _buildAvatarProvider(_UserStreakItem user) {
    if (user.imageUrl.isNotEmpty) {
      return NetworkImage(user.imageUrl);
    }

    final gender = user.gender.toLowerCase();
    if (gender == 'female') {
      return const AssetImage('assets/icons/female.png');
    }

    return const AssetImage('assets/icons/male.png');
  }

  ImageProvider? _buildMyAvatarProvider() {
    final userImageUrl = _extractUserImageUrl(_me);
    if (userImageUrl != null && userImageUrl.isNotEmpty) {
      return NetworkImage(userImageUrl);
    }
    return null;
  }

  Widget _buildStreakTile(_UserStreakItem user) {
    return GestureDetector(
      onTap: () => _showUserActionsSheet(user),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.lightSky, AppColors.babyBlueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                backgroundColor: AppColors.white,
                backgroundImage: _buildAvatarProvider(user),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.babyBlueLight, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 11,
                      color: AppColors.fatOrange,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${user.streak}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.blueGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserActionsSheet(_UserStreakItem user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.deepBlue,
                  ),
                  title: Text('View Profile (${user.name})'),
                  onTap: () {
                    Navigator.pop(context);
                    _openProfileAndRefresh(
                      viewedUserId: user.id,
                      viewedUserName: user.name,
                      viewedUserImageUrl: _resolveImageUrl(user.imageUrl),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.orange),
                  title: const Text('Hide User'),
                  onTap: () {
                    Navigator.pop(context);
                    _hideUser(user);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposerCard(
    BuildContext sheetContext, {
    required StateSetter modalSetState,
  }) {
    final initial = (_me?['name']?.toString() ?? 'U').trim();
    final displayInitial = initial.isNotEmpty ? initial[0].toUpperCase() : 'U';
    final myAvatarImage = _buildMyAvatarProvider();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9F6)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: myAvatarImage,
                backgroundColor: AppColors.babyBlueLight,
                child: myAvatarImage == null
                    ? Text(
                        displayInitial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _postController,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Share your post... text and image',
                    filled: true,
                    fillColor: const Color(0xFFF7FAFE),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _nutritionField('Calories', _caloriesController)),
              const SizedBox(width: 8),
              Expanded(child: _nutritionField('Fat', _fatController)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _nutritionField('Carbs', _carbsController)),
              const SizedBox(width: 8),
              Expanded(child: _nutritionField('Protein', _proteinController)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'Who can see this post?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Public'),
                selected: _composerAudience == _PostAudience.everyone,
                onSelected: (_) {
                  setState(() => _composerAudience = _PostAudience.everyone);
                  modalSetState(() {});
                },
              ),
              ChoiceChip(
                label: const Text('Followers only'),
                selected: _composerAudience == _PostAudience.followersOnly,
                onSelected: (_) {
                  setState(
                    () => _composerAudience = _PostAudience.followersOnly,
                  );
                  modalSetState(() {});
                },
              ),
            ],
          ),
          if (_selectedPostImage != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedPostImage!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPostImage = null;
                      });
                      modalSetState(() {});
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _showPostImageSourceSheet,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Add image'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isPublishing
                    ? null
                    : () => _publishPost(sheetContext),
                icon: _isPublishing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Post'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showComposerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            _composerModalSetState = modalSetState;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: _buildComposerCard(
                    sheetContext,
                    modalSetState: modalSetState,
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _composerModalSetState = null;
    });
  }

  Widget _buildComposerPlaceholder() {
    final initial = (_me?['name']?.toString() ?? 'U').trim();
    final displayInitial = initial.isNotEmpty ? initial[0].toUpperCase() : 'U';
    final myAvatarImage = _buildMyAvatarProvider();

    return GestureDetector(
      onTap: _showComposerSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.babyBlueLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.lightBlue),
          boxShadow: [
            BoxShadow(
              color: AppColors.lightBlue.withOpacity(0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
                border: Border.all(color: AppColors.lightBlue),
              ),
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                backgroundColor: AppColors.babyBlueLight,
                backgroundImage: myAvatarImage,
                child: myAvatarImage == null
                    ? Text(
                        displayInitial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Share your post...',
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, color: AppColors.deepBlue),
          ],
        ),
      ),
    );
  }

  Widget _nutritionField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
        hintStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _postMetricChip({required String label, required double? value}) {
    if (value == null) return const SizedBox.shrink();
    Color bg = const Color(0xFFF2F7FE);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildPostCard(_FeedPost post) {
    final isLikedByMe = post.likedByMe;
    final likesCount = post.likeCount;
    return InkWell(
      onTap: null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDEE9F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openAuthorProfile(post),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: _buildAvatarWithFallback(
                        name: post.authorName,
                        imageUrl: post.authorImageUrl,
                        radius: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openAuthorProfile(post),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          Text(
                            _formatDate(post.publishedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.blueGray,
                            ),
                          ),
                          if (post.visibility == 'followers_only') ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 12,
                                  color: AppColors.blueGray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Followers only',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blueGray,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
            if (post.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  post.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Color(0xFF1F2C3B),
                  ),
                ),
              ),
            if (post.imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Image.file(
                  post.imageFile!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _postMetricChip(label: 'Cal', value: post.calories),
                  _postMetricChip(label: 'Fat', value: post.fat),
                  _postMetricChip(label: 'Carb', value: post.carbs),
                  _postMetricChip(label: 'Protein', value: post.protein),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Row(
                children: [
                  Text(
                    '$likesCount likes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _showCommentsSheet(post),
                    child: Text(
                      '${post.comments.length} comments',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _toggleLike(post),
                    icon: Icon(
                      isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      color: isLikedByMe ? Colors.red : AppColors.deepBlue,
                      size: 18,
                    ),
                    label: const Text('Like'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showCommentsSheet(post),
                    icon: const Icon(
                      Icons.mode_comment_outlined,
                      size: 18,
                      color: AppColors.deepBlue,
                    ),
                    label: const Text('Comment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _filterTitle(_PostFeedFilter f) {
    switch (f) {
      case _PostFeedFilter.all:
        return 'All posts';
      case _PostFeedFilter.myPosts:
        return 'My posts';
      case _PostFeedFilter.highestProtein:
        return 'Highest protein';
      case _PostFeedFilter.lowestCalories:
        return 'Lowest calories';
      case _PostFeedFilter.todayPosts:
        return 'Today posts';
      case _PostFeedFilter.mostLiked:
        return 'Most liked';
      case _PostFeedFilter.publicOnly:
        return 'Public';
      case _PostFeedFilter.followersOnlyVisibility:
        return 'Followers only';
      case _PostFeedFilter.withImage:
        return 'With photo';
    }
  }

  IconData _filterIcon(_PostFeedFilter f) {
    switch (f) {
      case _PostFeedFilter.all:
        return Icons.dynamic_feed_rounded;
      case _PostFeedFilter.myPosts:
        return Icons.person_rounded;
      case _PostFeedFilter.highestProtein:
        return Icons.fitness_center_rounded;
      case _PostFeedFilter.lowestCalories:
        return Icons.local_fire_department_rounded;
      case _PostFeedFilter.todayPosts:
        return Icons.today_rounded;
      case _PostFeedFilter.mostLiked:
        return Icons.favorite_rounded;
      case _PostFeedFilter.publicOnly:
        return Icons.public_rounded;
      case _PostFeedFilter.followersOnlyVisibility:
        return Icons.lock_rounded;
      case _PostFeedFilter.withImage:
        return Icons.image_rounded;
    }
  }

  String _filterSubtitle(_PostFeedFilter f) {
    switch (f) {
      case _PostFeedFilter.all:
        return 'Everything in your feed';
      case _PostFeedFilter.myPosts:
        return 'Posts created by you';
      case _PostFeedFilter.highestProtein:
        return 'Filter: protein >= 15g';
      case _PostFeedFilter.lowestCalories:
        return 'Filter: calories <= 600';
      case _PostFeedFilter.todayPosts:
        return 'Published today only';
      case _PostFeedFilter.mostLiked:
        return 'Sort: most reactions first';
      case _PostFeedFilter.publicOnly:
        return 'Visible to everyone';
      case _PostFeedFilter.followersOnlyVisibility:
        return 'Visible to followers only';
      case _PostFeedFilter.withImage:
        return 'Posts that include photos';
    }
  }

  Widget _buildFilterSidebar({bool closeAfterSelect = false}) {
    return AppSidebar(
      closeAfterSelect: closeAfterSelect,
      filterSection: _buildFilterSection(closeAfterSelect: closeAfterSelect),
      hiddenUsersSection: _buildHiddenUsersSection(
        closeAfterSelect: closeAfterSelect,
      ),
    );
  }

  Widget _buildFilterSection({required bool closeAfterSelect}) {
    final isFiltered = _feedFilter != _PostFeedFilter.all;

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
        title: Text(
          'Filter',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.deepBlue,
          ),
        ),
        subtitle: Text(
          isFiltered
              ? 'Active filter: ${_filterTitle(_feedFilter)}'
              : 'Tap to see options',
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
          child: const Icon(
            Icons.tune_rounded,
            size: 18,
            color: AppColors.deepBlue,
          ),
        ),
        children: [
          ListView.separated(
            itemCount: _PostFeedFilter.values.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final f = _PostFeedFilter.values[index];
              final selected = _feedFilter == f;

              return Material(
                color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _feedFilter = f);
                    if (closeAfterSelect) Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFCFE1F8)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : const Color(0xFFF3F7FD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _filterIcon(f),
                            size: 18,
                            color: selected
                                ? AppColors.deepBlue
                                : AppColors.blueGray,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _filterTitle(f),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AppColors.deepBlue
                                      : const Color(0xFF2B3440),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _filterSubtitle(f),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blueGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppColors.deepBlue
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? AppColors.deepBlue
                                  : const Color(0xFFCCD9EA),
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 13,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.blueGray,
        ),
      ),
    );
  }

  Widget _buildDrawerActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.deepBlue,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1EBF7)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B3440),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blueGray,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.blueGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenUsersSection({required bool closeAfterSelect}) {
    final hasHiddenUsers = _hiddenUsers.isNotEmpty;

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
          hasHiddenUsers
              ? '${_hiddenUsers.length} hidden user${_hiddenUsers.length == 1 ? '' : 's'}'
              : 'No hidden users yet',
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
          if (!hasHiddenUsers)
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
              itemCount: _hiddenUsers.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final user = _hiddenUsers[index];
                final imageUrl = _resolveImageUrl(user.imageUrl);
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
                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                          ? NetworkImage(imageUrl)
                          : null,
                      child: (imageUrl == null || imageUrl.isEmpty)
                          ? Text(
                              _firstName(user.name)[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepBlue,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      user.name,
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
                        await _unhideUser(user);
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

  Widget _buildFilterFloatingButton() {
    final hasActiveFilter =
        _feedFilter != _PostFeedFilter.all ||
        _postSortOrder != _PostSortOrder.newestFirst;

    return Builder(
      builder: (ctx) {
        return SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final scaffold = Scaffold.maybeOf(ctx);
                scaffold?.openEndDrawer();
              },
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: AppColors.deepBlue,
                    size: 24,
                  ),
                  if (hasActiveFilter)
                    Positioned(
                      top: 6,
                      right: 7,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
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
  }

  Widget _buildFeedScroll() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: AppColors.deepBlue,
      backgroundColor: AppColors.white,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildUserSearchSection()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 130,
              child: _isLoadingUsers
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.navy,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: _visibleStreakUsers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildStreakTile(_visibleStreakUsers[index]);
                      },
                    ),
            ),
          ),
          SliverToBoxAdapter(child: _buildComposerPlaceholder()),
          if (_isLoadingPosts)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: Text(
                  'No posts yet\nStart by publishing your first post',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blueGray,
                  ),
                ),
              ),
            )
          else if (_visiblePosts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.filter_alt_off_rounded,
                        size: 48,
                        color: AppColors.blueGray,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No posts match this filter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() => _feedFilter = _PostFeedFilter.all);
                        },
                        child: const Text('Show all posts'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPostCard(_visiblePosts[index]),
                childCount: _visiblePosts.length,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: _buildFilterSidebar(closeAfterSelect: true),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) {
                  return Row(
                    children: [
                      Container(
                        width: 260,
                        color: Colors.white,
                        child: _buildFilterSidebar(),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFFEDEEF0)),
                      Expanded(child: _buildFeedScroll()),
                    ],
                  );
                }

                // For narrow screens: show feed only
                return _buildFeedScroll();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 4,
        onAddWaterTap: (amount) {
          try {
            Provider.of<HomeProvider>(
              context,
              listen: false,
            ).addWaterBy(amount);
          } catch (_) {}
        },
      ),
    );
  }
}
